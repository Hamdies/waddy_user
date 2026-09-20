import 'dart:async';
import 'package:waddy_app/util/swallow.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/common/controllers/theme_controller.dart';
import 'package:waddy_app/features/notification/domain/models/notification_body_model.dart';
import 'package:waddy_app/helper/deep_link_helper.dart';
import 'package:waddy_app/helper/notification_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/messages.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'helper/get_di.dart' as di;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    HttpOverrides.global = MyHttpOverrides();
  }

  /// Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  /// Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  if (GetPlatform.isAndroid) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCRcROEiqQ0P8X0kqlTO1RmINlK9derFpA",
        appId: "1:345656646156:android:f17568099ff49a73b72c29",
        messagingSenderId: "345656646156",
        projectId: "waddi-51062",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  Map<String, Map<String, String>> languages = await di.init();

  NotificationBodyModel? body;
  try {
    if (GetPlatform.isMobile) {
      final RemoteMessage? remoteMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (remoteMessage != null) {
        body = NotificationHelper.convertNotification(remoteMessage.data);
      }
      await NotificationHelper.initialize(flutterLocalNotificationsPlugin);
      FirebaseMessaging.onBackgroundMessage(myBackgroundMessageHandler);
    }
  } catch (e, s) {
    swallow('firebase messaging / notification init', e, s, true);
  }

  if (GetPlatform.isMobile) {
    await DeepLinkHelper.init();
  }

  /// `intl` ships no locale data until it is explicitly loaded, so any
  /// locale-aware DateFormat/NumberFormat throws LocaleDataException on a
  /// cold start. Spots formats the round lock label and prize dates this way,
  /// so load the data for every language the app offers before the first
  /// frame rather than lazily per screen.
  await initializeDateFormatting();

  runApp(MyApp(languages: languages, body: body));
}

class MyApp extends StatefulWidget {
  final Map<String, Map<String, String>>? languages;
  final NotificationBodyModel? body;
  const MyApp({super.key, required this.languages, required this.body});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // di.init() loads only the locale being rendered, so the first frame is not
    // held up decoding a bundle nobody is about to read. Pull the rest in once
    // that frame is on screen; Get.appendTranslations makes them available to
    // the language picker without rebuilding GetMaterialApp.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.languages != null) {
        di.loadRemainingLanguages(widget.languages!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return GetBuilder<ThemeController>(
      builder: (themeController) {
        return GetBuilder<LocalizationController>(
          builder: (localizeController) {
            return GetBuilder<SplashController>(
              builder: (splashController) {
                return GetMaterialApp(
                  title: AppConstants.appName,
                  debugShowCheckedModeBanner: false,
                  // Matches what get_di.init() already set. GetMaterialApp
                  // assigns Get.smartManagement on build, so leaving this
                  // at its `full` default would flip the global mode back
                  // after DI ran. See the note in helper/get_di.dart.
                  smartManagement: SmartManagement.keepFactory,
                  navigatorKey: Get.key,
                  // Lets the dashboard know when another route covers it,
                  // so its floating cart bar does not render through
                  // pushed screens that carry their own cart bar.
                  navigatorObservers: [dashboardRouteObserver],
                  scrollBehavior: const MaterialScrollBehavior().copyWith(
                    dragDevices: {
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.touch,
                    },
                  ),
                  // Waddi ships light-only on iOS/Android. The dark
                  // palette is unreachable by design: the module screens
                  // paint fixed light surfaces, so a dark scaffold would
                  // render white cards on near-black.
                  theme: light(),
                  locale: localizeController.locale,
                  translations: Messages(languages: widget.languages),
                  fallbackLocale: Locale(
                    AppConstants.languages[0].languageCode!,
                    AppConstants.languages[0].countryCode,
                  ),
                  initialRoute: RouteHelper.getSplashRoute(widget.body),
                  getPages: RouteHelper.routes,
                  defaultTransition: Transition.topLevel,
                  transitionDuration: const Duration(milliseconds: 500),
                  builder: (BuildContext context, widget) {
                    // No textScaler override here.
                    //
                    // This used to be a MediaQuery pinning
                    // `TextScaler.linear(1)` across every route in the app,
                    // which silently discarded the OS font-size setting —
                    // and, because it wrapped GetMaterialApp's builder,
                    // there was nowhere downstream that could opt back in.
                    // It dated to the initial import with no rationale,
                    // i.e. inherited template boilerplate rather than a
                    // decision.
                    //
                    // Every `MediaQuery.textScalerOf` clamp in the app was
                    // written against a value this pin held at 1.0, so
                    // those clamps were dead code until it came out. The
                    // rails that size fixed text blocks now scale them:
                    // see `_rankTextScale` / `_railHeight` in
                    // top_restaurants_view.dart and `_shelfTextScale` /
                    // `_shelfHeight` in grocery_shelf_view.dart.
                    return MediaQuery(
                      data: MediaQuery.of(context),
                      child: Material(
                        child: SafeArea(
                          top: false,
                          bottom: GetPlatform.isAndroid,
                          child: widget!,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
