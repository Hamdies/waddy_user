# Build flavors: dev, staging, prod

**Shipped:** 2026-09-19 (Dart + Android). **iOS: manual step outstanding — see §4.**

---

## 1. The problem this solves

There was one hardcoded production URL:

```dart
static const String baseUrl = 'https://waddyapp.com';
```

So every developer run, every QA pass and every debug session wrote to live
customer data. Testing anything else meant editing a constant and remembering to
change it back. A developer build also replaced the real app on the device,
because the `applicationId` was identical.

That is the most dangerous single fact in the codebase: nothing but human
attention stood between a debugger and a real customer's order.

## 2. How a build picks its backend

Two independent switches, both required:

| Switch | Selects | Flag |
|---|---|---|
| Dart | API host, feature flags | `--dart-define-from-file=env/<flavor>.json` |
| Gradle/Xcode | applicationId, app name, Firebase config | `--flavor <flavor>` |

```sh
# Day-to-day development (staging data)
flutter run --flavor dev --dart-define-from-file=env/dev.json

# QA
flutter run --flavor staging --dart-define-from-file=env/staging.json

# Release
flutter build appbundle --flavor prod --dart-define-from-file=env/prod.json
```

`release-guard` in CI fails any release build where the two disagree, so a
prod-signed binary cannot carry staging defines.

### The default, and why it is not yet the safe one

The safe default is staging: a build that forgets its flavor should not be able
to write to live orders. **That is not what ships today, because there is no
staging backend** — `staging.waddyapp.com` returns NXDOMAIN.

That version was tried first and caught immediately on a real device: a bare
`flutter run` produced 19 `_ClientSocketException`s and an empty home screen,
because the default pointed at a host that does not exist. A default that breaks
the everyday launch path protects nothing; it just gets worked around.

So the default is production — the same behaviour as before this change — and
the protection comes from being **explicit** instead: `env/` files,
`--dart-define-from-file`, and separate installs per flavor. `dev` and `staging`
point at production for now too, each carrying a `_comment` TODO saying so.

**When a staging backend exists**, three edits flip it:

1. `AppEnvironment.baseUrl` / `webHostedUrl` defaults → the staging host
2. `AppEnvironment.defaultIsProduction` → `false`, and `_rawFlavor` → `'dev'`
3. `env/dev.json` and `env/staging.json` → the staging host, drop `_comment`

`flavor-guard` then asserts the safe default instead of warning about it, and
`app_environment_test.dart` flips on the same constant.

An unrecognised flavor name (`--dart-define WADDI_FLAVOR=typo`) resolves to
`dev` regardless — a typo must never silently mean production.


## 3. What each flavor gets

| | dev | staging | prod |
|---|---|---|---|
| applicationId | `…waddi.dev` | `…waddi.staging` | `…waddi` |
| Launcher name | Waddy Dev | Waddy Staging | Waddy |
| versionName | `1.0-dev` | `1.0-staging` | `1.0` |
| Backend | staging | staging | production |

All three install side by side, so a tester can hold every build at once and
tell them apart on the home screen.

`prod` deliberately has **no** applicationId suffix — it is the id the Play
listing and every existing install already use. Changing it would orphan every
user on the store.

## 4. Outstanding: iOS schemes

Android is done. iOS still builds a single configuration, so
`flutter build ios --flavor dev` will not work until Xcode schemes exist.

This was **not** scripted deliberately: it means editing
`ios/Runner.xcodeproj/project.pbxproj`, and a corrupted project file is a bad
trade against ten minutes in the Xcode UI. It is also complicated here by the
**WaddiLiveActivity** extension, whose bundle id must stay nested under the
parent app's.

### Steps

1. Xcode → *Project* → **Info** → duplicate each of Debug / Release / Profile
   into `Debug-dev`, `Debug-staging`, `Debug-prod`, and so on for Release and
   Profile. Nine configurations total.
2. *Product* → *Scheme* → *Manage Schemes* → create `dev`, `staging`, `prod`,
   each pointing at its matching configurations.
3. For each configuration set `PRODUCT_BUNDLE_IDENTIFIER`:
   - dev → `com.hamdiesolutions.waddi.dev`
   - staging → `com.hamdiesolutions.waddi.staging`
   - prod → `com.hamdiesolutions.waddi`
4. **The Live Activity extension must follow suit**, or the build fails code
   signing: its id must remain `<parent>.WaddiLiveActivity`, so
   `com.hamdiesolutions.waddi.dev.WaddiLiveActivity` and equivalents.
5. Add a per-configuration `GoogleService-Info.plist` (see §5) and a Run Script
   phase that copies the right one, or use separate targets.

Until this is done, build iOS with `--flavor prod` (or no flavor) and select the
backend with `--dart-define-from-file` alone. **The Dart-side protection already
works on iOS** — only the bundle-id separation is missing.

## 5. Firebase per flavor

`google-services.json` / `GoogleService-Info.plist` must contain an entry for the
exact applicationId being built. Gradle resolves `src/<flavor>/` before
`src/main/`.

- `android/app/src/prod/google-services.json` — **populated**
- `android/app/src/dev/` and `src/staging/` — **not yet created**

A dev or staging Android build fails fast with an explanation (see the
`processDev*GoogleServices` guard in `android/app/build.gradle`) rather than the
plugin's cryptic "No matching client found for package name".

To create them: Firebase console → *Add app* → Android → package name
`com.hamdiesolutions.waddi.dev` → download the file into
`android/app/src/dev/`.

**Prefer a separate Firebase project for non-production.** Registering the
suffixed ids inside the existing `waddi-51062` project is quicker, but then every
developer session pollutes the production Crashlytics and Analytics numbers —
and the crash-free-sessions metric is one you will want to trust.

### These files are not secrets

`google-services.json`, `GoogleService-Info.plist` and the Firebase API keys in
`main.dart` are **identifiers**, not credentials. They are designed to ship
inside a public binary; anyone can extract them from any published app. Protect
them by restricting the keys in the Google Cloud console and by writing Firebase
security rules — not by hiding the files.

What genuinely must stay out of the repo: `key.properties`, the upload keystore,
and any service-account JSON.

## 6. What is still hardcoded

`android/app/src/main/res/values/strings.xml` carries the Facebook app id and
client token. These are per-environment in principle; they are left alone here
because splitting them needs a second Facebook app registered first. Track that
with the ads work, not this change.
