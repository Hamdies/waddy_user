# Per-flavor Firebase config

`google-services.json` must contain an entry for the exact `applicationId` of
the variant being built. The flavors add suffixes:

| flavor  | applicationId                         |
|---------|---------------------------------------|
| dev     | `com.hamdiesolutions.waddi.dev`       |
| staging | `com.hamdiesolutions.waddi.staging`   |
| prod    | `com.hamdiesolutions.waddi`           |

Gradle resolves this file from `src/<flavor>/` before `src/main/` or `app/`, so
each flavor gets its own.

**`prod/` is populated. `dev/` and `staging/` are not yet** — they need Android
apps registered in a Firebase project first:

1. Firebase console → Project settings → *Add app* → Android.
2. Package name: the suffixed id from the table above.
3. Download `google-services.json` into `android/app/src/dev/` (or `staging/`).

Use a **separate Firebase project** for non-production if you want analytics and
Crashlytics kept out of the production numbers — which you do, otherwise every
developer session pollutes the release dashboards. Registering the dev/staging
ids inside the existing project also works and is quicker, at the cost of mixed
metrics.

Until those exist, only `--flavor prod` builds. See `android/app/build.gradle`.

These files are Firebase *identifiers*, not secrets — they are safe to commit.
The things that must stay out of the repo are `key.properties` and the keystore.
