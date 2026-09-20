import 'dart:convert';
import 'package:waddy_app/helper/auth_token_store.dart';

import 'package:get/get_connect.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/cart/domain/models/online_cart_model.dart';
import 'package:waddy_app/features/cart/domain/repositories/cart_repository_interface.dart';
import 'package:waddy_app/features/checkout/domain/models/place_order_body_model.dart';
import 'package:waddy_app/helper/module_helper.dart';
import 'package:waddy_app/util/app_constants.dart';

class CartRepository implements CartRepositoryInterface<OnlineCart> {
  final ApiClient apiClient;
  final SharedPreferences sharedPreferences;
  CartRepository({required this.apiClient, required this.sharedPreferences});

  /// The guest_id to send on cart requests when there is no logged-in user.
  /// The backend (waddy_back CartController) requires guest_id for every cart
  /// op when unauthenticated and scopes the cart by is_guest — so a guest's
  /// server cart works exactly like a user's. Empty when logged in (the user's
  /// Bearer token identifies them) or when no guest session exists.
  String get _guestId {
    final bool loggedIn =
        AuthTokenStore.hasToken;
    if (loggedIn) return '';
    return sharedPreferences.getString(AppConstants.guestId) ?? '';
  }

  @override
  Future<void> addSharedPrefCartList(List<CartModel> cartProductList) async {
    List<String> carts = [];
    if (sharedPreferences.containsKey(AppConstants.cartList)) {
      carts = sharedPreferences.getStringList(AppConstants.cartList) ?? [];
    }
    List<String> cartStringList = [];
    for (String cartString in carts) {
      CartModel cartModel = CartModel.fromJson(jsonDecode(cartString));
      if (cartModel.item!.moduleId != _getModuleId()) {
        cartStringList.add(cartString);
      }
    }
    for (CartModel cartModel in cartProductList) {
      cartStringList.add(jsonEncode(cartModel.toJson()));
    }
    await sharedPreferences.setStringList(
      AppConstants.cartList,
      cartStringList,
    );
  }

  int _getModuleId() {
    return ModuleHelper.getModule()?.id ??
        ModuleHelper.getCacheModule()?.id ??
        0;
  }

  @override
  Future add(OnlineCart cart) async {
    return await _addToCartOnline(cart);
  }

  Future<List<OnlineCartModel>?> _addToCartOnline(OnlineCart cart) async {
    List<OnlineCartModel>? onlineCartList;
    final Map<String, dynamic> body = cart.toJson();
    if (_guestId.isNotEmpty) body['guest_id'] = _guestId;
    Response response = await apiClient.postData(AppConstants.addCartUri, body);
    if (response.statusCode == 200) {
      onlineCartList = [];
      response.body.forEach(
        (cart) => onlineCartList!.add(OnlineCartModel.fromJson(cart)),
      );
    }
    return onlineCartList;
  }

  @override
  Future<bool> delete(int? id, {bool isRemoveAll = false}) async {
    if (isRemoveAll) {
      return await _clearCartOnline();
    } else {
      return await _removeCartItemOnline(id!);
    }
  }

  Future<bool> _removeCartItemOnline(int cartId) async {
    String uri =
        '${AppConstants.removeItemCartUri}?cart_id=${Uri.encodeComponent(cartId.toString())}';
    if (_guestId.isNotEmpty)
      uri += '&guest_id=${Uri.encodeComponent(_guestId)}';
    Response response = await apiClient.deleteData(uri);
    return (response.statusCode == 200);
  }

  Future<bool> _clearCartOnline() async {
    String uri = AppConstants.removeAllCartUri;
    if (_guestId.isNotEmpty)
      uri += '?guest_id=${Uri.encodeComponent(_guestId)}';
    Response response = await apiClient.deleteData(uri);
    return (response.statusCode == 200);
  }

  @override
  Future get(String? id) {
    throw UnimplementedError();
  }

  @override
  Future getList({int? offset}) async {
    return await _getCartDataOnline();
  }

  Future<List<OnlineCartModel>?> _getCartDataOnline() async {
    List<OnlineCartModel>? onlineCartList;

    // `currentModuleId`, not `getModule()`: the backend filters the cart with
    // `where('module_id', $request->header('moduleId'))`, and a missing header
    // makes that `where('module_id', null)`, which matches **nothing**.
    //
    // From the module-less dashboard `getModule()` is null, so the header was
    // omitted and the cart came back empty — until the user entered a module,
    // at which point it reappeared. That is the "cart not showing until I
    // select the food module" report. `currentModuleId` falls back to
    // `cacheModule`: the last module in play, which is the one the cart
    // belongs to.
    final int? moduleId = ModuleHelper.currentModuleId();
    final Map<String, String> header = {
      'Content-Type': 'application/json; charset=UTF-8',
      AppConstants.localizationKey: AppConstants.languages[0].languageCode!,
      if (moduleId != null) AppConstants.moduleId: '$moduleId',
      'Authorization': 'Bearer ${AuthTokenStore.token}',
    };

    String listUri = AppConstants.getCartListUri;
    if (_guestId.isNotEmpty) {
      listUri += '?guest_id=${Uri.encodeComponent(_guestId)}';
    }
    Response response = await apiClient.getData(listUri, headers: header);

    if (response.statusCode == 200) {
      onlineCartList = [];
      response.body.forEach(
        (cart) => onlineCartList!.add(OnlineCartModel.fromJson(cart)),
      );
    }
    return onlineCartList;
  }

  @override
  Future update(
    Map<String, dynamic> body,
    int? id, {
    double? price,
    int? quantity,
    bool isUpdateQty = false,
  }) async {
    if (isUpdateQty) {
      return await _updateCartQuantityOnline(id!, price!, quantity!);
    } else {
      return await _updateCartOnline(body);
    }
  }

  Future<List<OnlineCartModel>?> _updateCartOnline(
    Map<String, dynamic> body,
  ) async {
    List<OnlineCartModel>? onlineCartList;
    if (_guestId.isNotEmpty) body['guest_id'] = _guestId;
    Response response = await apiClient.postData(
      AppConstants.updateCartUri,
      body,
    );
    if (response.statusCode == 200) {
      onlineCartList = [];
      response.body.forEach(
        (cart) => onlineCartList!.add(OnlineCartModel.fromJson(cart)),
      );
    }
    return onlineCartList;
  }

  Future<bool> _updateCartQuantityOnline(
    int cartId,
    double price,
    int quantity,
  ) async {
    Map<String, dynamic> data = {
      "cart_id": cartId,
      "price": price,
      "quantity": quantity,
    };
    if (_guestId.isNotEmpty) data['guest_id'] = _guestId;
    Response response = await apiClient.postData(
      AppConstants.updateCartUri,
      data,
    );
    return (response.statusCode == 200);
  }
}
