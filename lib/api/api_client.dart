import 'dart:convert';
import 'package:waddy_app/util/swallow.dart';
import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get_connect/http/src/request/request.dart';
import 'package:waddy_app/api/api_checker.dart';
import 'package:waddy_app/api/api_stats.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/common/models/error_response.dart';
import 'package:waddy_app/helper/auth_token_store.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiClient extends GetxService {
  final String appBaseUrl;
  final SharedPreferences sharedPreferences;
  static final String noInternetMessage = 'connection_to_api_server_failed'.tr;

  /// One client for the whole app, held for its lifetime.
  ///
  /// Every call used to go through the top-level `http.get` / `http.post`
  /// helpers. Those build a fresh `Client`, issue one request and close it in a
  /// `finally` — so every single call in the app paid a full TCP + TLS
  /// handshake, roughly two round trips before the first byte. On Egyptian
  /// mobile data that is 150–800 ms of pure setup, and home fires ~25 requests
  /// at once. A shared client keeps the socket alive and reuses it, so only the
  /// first request of a session pays for the connection.
  final http.Client _client = http.Client();

  /// 40 s was not a loading state, it was an abandonment: on a bad connection
  /// the user sat on a dead screen for the better part of a minute before
  /// anything was allowed to fail. Reads get one retry (see [getData]), which
  /// covers the transient drop that the long timeout was really guarding
  /// against, and fails visibly instead of silently hanging.
  final int timeoutInSeconds = 12;

  /// Uploads carry a photo over the same mobile link and legitimately take
  /// longer than a read. This path previously had *no* timeout at all, so a
  /// stalled upload hung until the OS gave up on the socket.
  final int uploadTimeoutInSeconds = 60;

  String? token;
  late Map<String, String> _mainHeaders;

  @override
  void onClose() {
    _client.close();
    super.onClose();
  }

  ApiClient({required this.appBaseUrl, required this.sharedPreferences}) {
    token = AuthTokenStore.token.isEmpty ? null : AuthTokenStore.token;
    AddressModel? addressModel;
    try {
      addressModel = AddressModel.fromJson(
        jsonDecode(sharedPreferences.getString(AppConstants.userAddress)!),
      );
    } catch (e, s) {
      // No saved address yet is the normal first-run state, so this is not an
      // error — the headers simply go out without zone or coordinates.
      swallow('no stored address at ApiClient construction', e, s);
    }
    // No module at boot, deliberately: nothing has selected one yet this
    // session, and the app opens on the module picker. SplashController sets
    // it the moment the user enters a module.
    updateHeader(
      token,
      addressModel?.zoneIds,
      addressModel?.areaIds,
      sharedPreferences.getString(AppConstants.languageCode),
      null,
      addressModel?.latitude,
      addressModel?.longitude,
    );
  }

  Map<String, String> updateHeader(
    String? token,
    List<int>? zoneIDs,
    List<int>? operationIds,
    String? languageCode,
    int? moduleID,
    String? latitude,
    String? longitude, {
    bool setHeader = true,
  }) {
    Map<String, String> header = {};

    // The module id is what the CALLER says it is, and nothing else.
    //
    // This used to fall back to the persisted `cacheModuleId` whenever it was
    // passed none — and since that pref is written on every module entry and
    // never cleared, "no module" was unrepresentable. Leaving a module
    // (the home hero back button, the dashboard tabs, sign-out, and every cold
    // start) went on sending `moduleId: <the last module the user opened>`, so
    // the aggregated dashboard asked the server for one module's catalogue and
    // rendered the answer as if it were everything. `/categories` on the
    // dashboard returning the previous module's aisles was this, and so was
    // every rail that had to hand-build its headers to escape it.
    //
    // `cacheModuleId` is still written and still read — it is a legitimate
    // "module of the thing being looked at" for screens opened from the
    // module-less dashboard (item sheets, the cart, store details). The bug
    // was never that it exists; it was that an ambient header helped itself to
    // it. Callers that want it pass it (see StoreRepository.getStoreDetails).
    if (moduleID != null) {
      header.addAll({AppConstants.moduleId: '$moduleID'});
    }
    header.addAll({
      'Content-Type': 'application/json; charset=UTF-8',
      // Always a JSON ARRAY, never an empty string. Most endpoints 403 when
      // the header is absent and then `json_decode()` it straight into
      // whereIn() — an empty string decodes to null, which is a TypeError
      // (500), not an empty result. "[]" is the only safe way to say "out of
      // zone": present for the hasHeader guards, and a valid array downstream.
      // Backends decide what an empty list means; see ModuleController.
      AppConstants.zoneId: zoneIDs != null ? jsonEncode(zoneIDs) : '',

      ///this will add in ride module
      // AppConstants.operationAreaId: operationIds != null ? jsonEncode(operationIds) : '',
      AppConstants.localizationKey:
          languageCode ?? AppConstants.languages[0].languageCode!,
      AppConstants.latitude: latitude != null ? jsonEncode(latitude) : '',
      AppConstants.longitude: longitude != null ? jsonEncode(longitude) : '',
      // Ads attribution context for server-side Meta CAPI events. X-ATT is
      // refreshed via updateAttHeader once the iOS tracking prompt is
      // answered; '0' is the safe default everywhere else.
      'X-Client-Platform': GetPlatform.isIOS ? 'ios' : 'android',
      'X-ATT': _attHeaderValue,
      // Opts this build into the resized/WebP image variants the backend
      // shipped on 2026-08-29. Without it every response is byte-identical to
      // what an old build gets, which is how the server keeps from spending
      // ~150 bytes per card telling clients in the field about URLs they can't
      // request. Entities come back with a `*_variants` sibling next to the
      // unchanged `*_full_url`; see CustomImage for the read side.
      'X-Image-Variants': '1',
      'Authorization': 'Bearer $token',
    });
    if (setHeader) {
      _mainHeaders = header;
    }
    return header;
  }

  static String _attHeaderValue = '0';

  void updateAttHeader(bool authorized) {
    _attHeaderValue = authorized ? '1' : '0';
    _mainHeaders['X-ATT'] = _attHeaderValue;
  }

  Map<String, String> getHeader() => _mainHeaders;

  Future<Response> getData(
    String uri, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool handleError = true,
    bool showError = false,
  }) async {
    if (kDebugMode) {
      debugPrint('====> API Call: $uri');
    }
    // GET is idempotent, so a transient failure can simply be re-issued. This
    // is what makes the shorter timeout safe: the old 40 s was really absorbing
    // the one dropped packet that a retry handles in a fraction of the time.
    // The retry is deliberately not applied to POST/PUT/DELETE — replaying a
    // write that may have reached the server is how you get duplicate orders.
    for (int attempt = 0; attempt < 2; attempt++) {
      final Stopwatch watch = Stopwatch()..start();
      // Only the network call is guarded. handleResponse must sit outside, or a
      // decode failure on a response that already arrived would be treated as a
      // transport failure and re-issue a request the server has already served.
      final http.Response response;
      try {
        response = await _client
            .get(Uri.parse(appBaseUrl + uri), headers: headers ?? _mainHeaders)
            .timeout(Duration(seconds: timeoutInSeconds));
      } catch (e) {
        watch.stop();
        final bool willRetry = attempt == 0;
        if (kDebugMode) {
          debugPrint(
            'API error: ${e.runtimeType} on $uri'
            '${willRetry ? ' — retrying' : ''}',
          );
        }
        if (willRetry) {
          // Short, fixed backoff. Long enough to clear a momentary radio
          // handover, short enough that the user does not feel a second wait
          // stacked on the first.
          await Future.delayed(const Duration(milliseconds: 400));
          continue;
        }
        ApiStats.record(
          uri: uri,
          elapsedMs: watch.elapsedMilliseconds,
          responseBytes: 0,
          ok: false,
        );
        return Response(statusCode: 1, statusText: noInternetMessage);
      }

      watch.stop();
      ApiStats.record(
        uri: uri,
        elapsedMs: watch.elapsedMilliseconds,
        responseBytes: response.bodyBytes.length,
        ok: response.statusCode == 200,
        notModified: response.statusCode == 304,
      );
      return await handleResponse(response, uri, handleError, showError);
    }
    return Response(statusCode: 1, statusText: noInternetMessage);
  }

  Future<Response> postData(
    String uri,
    dynamic body, {
    Map<String, String>? headers,
    int? timeout,
    bool handleError = true,
    bool showError = true,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('====> API Call: $uri');
        // Log auth headers for reorder endpoint
        if (uri.contains('reorder')) {
          debugPrint('📦 [API CLIENT] Reorder Request Headers:');
          final headersToUse = headers ?? _mainHeaders;
          headersToUse.forEach((key, value) {
            if (key.toLowerCase() == 'authorization') {
              debugPrint(
                '📦 [API CLIENT] Authorization: ${value.substring(0, 20)}...',
              );
            } else {
              debugPrint('📦 [API CLIENT] $key: $value');
            }
          });
        }
      }

      Map<dynamic, dynamic> newBody = {};
      if (body != null) {
        body.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            newBody.addAll({key: value});
          }
        });
      }

      final Stopwatch watch = Stopwatch()..start();
      http.Response response = await _client
          .post(
            Uri.parse(appBaseUrl + uri),
            body: jsonEncode(newBody),
            headers: headers ?? _mainHeaders,
          )
          .timeout(Duration(seconds: timeout ?? timeoutInSeconds));
      watch.stop();
      ApiStats.record(
        uri: uri,
        elapsedMs: watch.elapsedMilliseconds,
        responseBytes: response.bodyBytes.length,
        ok: response.statusCode == 200,
      );
      return await handleResponse(response, uri, handleError, showError);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('API error: ${e.runtimeType} on $uri');
      }
      ApiStats.record(uri: uri, elapsedMs: 0, responseBytes: 0, ok: false);
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postMultipartData(
    String uri,
    Map<String, String> body,
    List<MultipartBody> multipartBody, {
    List<MultipartDocument>? multipartDoc,
    Map<String, String>? headers,
    bool handleError = true,
    bool showError = true,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('====> API Call: $uri');
      }
      http.MultipartRequest request = http.MultipartRequest(
        'POST',
        Uri.parse(appBaseUrl + uri),
      );
      request.headers.addAll(headers ?? _mainHeaders);
      for (MultipartBody multipart in multipartBody) {
        if (multipart.file != null) {
          File file = File(multipart.file!.path);
          request.files.add(
            http.MultipartFile(
              multipart.key,
              file.readAsBytes().asStream(),
              file.lengthSync(),
              filename: file.path.split('/').last,
            ),
          );
        }
      }

      if (multipartDoc != null && multipartDoc.isNotEmpty) {
        for (MultipartDocument file in multipartDoc) {
          {
            File other = File(file.file!.files.single.path!);
            Uint8List list0 = await other.readAsBytes();
            var part = http.MultipartFile(
              file.key,
              other.readAsBytes().asStream(),
              list0.length,
              filename: basename(other.path),
            );
            request.files.add(part);
          }
        }
      }

      request.fields.addAll(body);
      http.Response response = await http.Response.fromStream(
        await _client
            .send(request)
            .timeout(Duration(seconds: uploadTimeoutInSeconds)),
      );
      return await handleResponse(response, uri, handleError, showError);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('API error: ${e.runtimeType} on $uri');
      }
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> putData(
    String uri,
    dynamic body, {
    Map<String, String>? headers,
    bool handleError = true,
    bool showError = true,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('====> API Call: $uri');
      }
      http.Response response = await _client
          .put(
            Uri.parse(appBaseUrl + uri),
            body: jsonEncode(body),
            headers: headers ?? _mainHeaders,
          )
          .timeout(Duration(seconds: timeoutInSeconds));
      return await handleResponse(response, uri, handleError, showError);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('API error: ${e.runtimeType} on $uri');
      }
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> deleteData(
    String uri, {
    Map<String, String>? headers,
    bool handleError = true,
    bool showError = true,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('====> API Call: $uri');
      }
      http.Response response = await _client
          .delete(Uri.parse(appBaseUrl + uri), headers: headers ?? _mainHeaders)
          .timeout(Duration(seconds: timeoutInSeconds));
      return await handleResponse(response, uri, handleError, showError);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('API error: ${e.runtimeType} on $uri');
      }
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  /// Above this many bytes, decoding moves to a background isolate.
  ///
  /// Isolate.run is not free — it spawns, copies the string in and copies the
  /// decoded object graph back out — so for the small responses that make up
  /// most of this API it is a net loss and inline decoding wins. The threshold
  /// is where the decode starts to threaten the 16 ms frame budget instead.
  ///
  /// Today almost nothing crosses it: the largest measured home response is
  /// ~10 KB. This matters as the catalogue grows — the store and item list
  /// endpoints return 12–50 fully-serialised records, and at fifty stores those
  /// become hundreds of KB decoded on the thread that owes a frame every 16 ms.
  static const int _isolateDecodeThresholdBytes = 48 * 1024;

  static dynamic _decode(String source) {
    try {
      return jsonDecode(source);
    } catch (_) {
      return null;
    }
  }

  Future<Response> handleResponse(
    http.Response response,
    String uri,
    bool handleError,
    bool showError,
  ) async {
    dynamic body;
    if (response.bodyBytes.length > _isolateDecodeThresholdBytes) {
      final String source = response.body;
      try {
        body = await Isolate.run(() => _decode(source));
      } catch (_) {
        // Isolate spawn can fail under memory pressure; a slow decode beats no
        // decode.
        body = _decode(source);
      }
    } else {
      body = _decode(response.body);
    }
    Response response0 = Response(
      body: body ?? response.body,
      bodyString: response.body.toString(),
      request: Request(
        headers: response.request!.headers,
        method: response.request!.method,
        url: response.request!.url,
      ),
      headers: response.headers,
      statusCode: response.statusCode,
      statusText: response.reasonPhrase,
    );
    if (response0.statusCode != 200 &&
        response0.body != null &&
        response0.body is! String) {
      if (response0.body.toString().startsWith('{errors: [{code:')) {
        ErrorResponse errorResponse = ErrorResponse.fromJson(response0.body);
        response0 = Response(
          statusCode: response0.statusCode,
          body: response0.body,
          statusText: errorResponse.errors![0].message,
        );
      } else if (response0.body.toString().startsWith('{message')) {
        response0 = Response(
          statusCode: response0.statusCode,
          body: response0.body,
          statusText: response0.body['message'],
        );
      }
    } else if (response0.statusCode != 200 && response0.body == null) {
      response0 = Response(statusCode: 0, statusText: noInternetMessage);
    }
    if (kDebugMode) {
      debugPrint('====> API Response: [${response0.statusCode}] $uri');
    }
    // `handleError` controls the RETURN SHAPE (empty Response on failure) and
    // whether the 401 sweep runs at all. `showError` independently controls the
    // failure toast. They are deliberately separate: reads still want the
    // empty-Response contract their callers branch on, but must not shout at the
    // user when a background refresh fails. See docs/snackbar_noise_plan.md.
    if (handleError) {
      if (response0.statusCode == 200) {
        return response0;
      } else {
        ApiChecker.checkApi(response0, showError: showError);
        return const Response();
      }
    } else {
      return response0;
    }
  }
}

class MultipartBody {
  String key;
  XFile? file;

  MultipartBody(this.key, this.file);
}

class MultipartDocument {
  String key;
  FilePickerResult? file;
  MultipartDocument(this.key, this.file);
}
