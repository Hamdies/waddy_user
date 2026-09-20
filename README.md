# waddy_app

Waddi customer app — multi-vendor food, grocery, eCommerce, pharmacy and parcel.

## Platforms

**Android and iOS only.** There is no web build and no desktop build, and none
is planned. `windows/`, `macos/` and `linux/` were never scaffolded; `web/` came
in with the upstream template and was removed on 2026-08-22.

Before your first build, disable the other targets locally — `flutter config` is
machine-global, not repo state, so this cannot be committed:

```sh
flutter config --no-enable-web \
               --no-enable-linux-desktop \
               --no-enable-macos-desktop \
               --no-enable-windows-desktop
```

Do not add `kIsWeb`, `GetPlatform.isWeb`, `GetPlatform.isDesktop` or
`dart:html` / `package:universal_html` code. See
[docs/mobile_only_plan.md](docs/mobile_only_plan.md) for the removal plan and
its current progress.

## Getting started

Flutter SDK 3.41.4 (Dart 3.11.1) — see `environment.sdk` in `pubspec.yaml`.

```sh
flutter pub get
flutter run                       # attached Android or iOS device
flutter analyze
flutter test
```

iOS additionally needs `cd ios && pod install`.
