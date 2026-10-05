# iOS Live Activity — plan (`LA-*`)

Audit 2026-10-04. Scope: the order-tracking Live Activity end to end. That covers starting it in
the app, the native bridge, the APNs push path on the backend, and what the widget can show. The
visual design was rebuilt 09-30/10-01 and is **not** reopened here. See memory `live-activity-design`
for the design decisions that stand: emoji kept, logo left/status right, no `.environment` overrides.

**The complaint:** "it doesn't update at all."

**Short answer:** once the app leaves the success screen, the backend's APNs push is the only thing
that can move the activity. Nothing confirms that path works in production. Even when it does work,
one whole class of builds (Xcode Debug or TestFlight) is always pointed at the wrong APNs host
(`LA-02`). The app never repairs the activity itself: not on resume, not from the order screen, and
not on cold start (`LA-04`). So any APNs failure leaves it frozen on "Order placed".

## Master status

| ID | Finding | Sev | Status | Phase |
|---|---|---|---|---|
| LA-01 | Production APNs path had never worked: the prod `.env` had no `APNS_*` keys. Then key YG57PPHCL4 turned out to be production-only (`403 BadEnvironmentKeyInToken` on sandbox), and `LOG_LEVEL=error` hid the warnings. **Fixed 10-04**: new key R7733FVC8G (Sandbox & Production), `APNS_ENVIRONMENT=sandbox` for Xcode testing, `LOG_LEVEL=warning`. User confirmed the card now updates | P0 | **fixed 10-04** (set env back to production for App Store; LA-02 removes the toggle) | 0 |
| LA-02 | One `APNS_ENVIRONMENT` for every token. Debug builds mint **sandbox** tokens; TestFlight and App Store mint **production** tokens. The wrong pair gets `400 BadDeviceToken`, which is only logged as a warning | P0 | open. **Hit 10-04**: a `flutter run` build (sandbox token) against `APNS_ENVIRONMENT=production` | 1 |
| LA-03 | Remounting the success screen (payment callback, back/forward) calls `Activity.request` again and creates a second activity. The backend keeps one token per order (`unique(order_id)`), so one of the two cards is frozen for good | P0 | open | 1 |
| LA-04 | The app only updates the activity while `OrderSuccessfulScreen` is mounted (10 s poll) or while an FCM push arrives with the app in the foreground. The order details screen, the tracking bar, app resume and cold start never touch it | P0 | open | 1 |
| LA-05 | Push token: only the **first** token is sent (`break`), rotations are dropped, a failed POST is never retried and its status code is never checked. `FlutterResult` never resolves if no token arrives | P1 | open | 1 |
| LA-06 | `live-activity-token` sits behind `auth:api`, so a guest order (if guest checkout is live) gets a 401 that nobody sees and never updates | P1 | open | 1 |
| LA-07 | The token endpoint doesn't check that the order belongs to the caller. Anyone can bind their device's activity to another user's order id and receive that order's store, rider and ETA | P1 | open | 1 |
| LA-08 | The APNs HTTP call runs synchronously **inside** `OrderStatusService`'s DB transaction, while `lockForUpdate` holds the order row. A slow Apple response stalls the store or rider status update | P1 | open | 1 |
| LA-09 | Rider accept (`DeliverymanController::accept_order` → `accepted` + rider assigned) sends its own FCM and bypasses `send_order_notification`, so the activity never hears that step | P1 | open | 1 |
| LA-10 | `sub_status` (`nearby`/`arrived`) is never written on a live path. `OrderTrackingService` is only reached by the web stream route, and `record_location_data` doesn't call it. The widget's "Almost there" and "Here" states can't be reached | P2 | open | 2 |
| LA-11 | ETA is pushed only on a status change. The FCM foreground path rebuilds arrival as `now + eta_minutes`, which is truncated and drifts, instead of using the server's instant | P2 | open | 2 |
| LA-12 | Every update is silent: no `alert` on picked-up, delivered or cancelled. The island never expands and the lock screen never lights up for the moments that matter | P2 | open | 3 |
| LA-13 | No push-to-start (iOS 17.2+). If the local start failed, or the app died before the success screen, no activity ever appears. Scheduled orders also start at placement, hours early, and run into iOS's 8 h cap | P2 | open | 3 |
| LA-14 | `unique(order_id)` means one device per order. The second phone overwrites the first | P2 | open | 2 |
| LA-15 | Nothing cleans up at launch. If the `end` push is lost, a finished order's card lingers for up to 8 h | P3 | open | 2 |
| LA-16 | No one-shot diagnostic. Proving the APNs path needs a real order plus log tailing | P3 | open | 0 |
| LA-17 | Only `410` deletes a token. `400 BadDeviceToken` / `ExpiredToken` / `TopicDisallowed` keep failing on every status change | P3 | open | 2 |
| LA-18 | The `storeLogoUrl` attribute is sent but never rendered. Widgets can't load remote images, and the design shows the Waddy mark | P3 | decision | — |
| LA-19 | Tapping the card opened order details **twice**, the second time with `id=0` (404s). Flutter's built-in deep linking (on by default since 3.27) pushed `/100072` alongside `app_links`. Fixed 10-04: `FlutterDeepLinkingEnabled=false` in Runner/Info.plist | P1 | **fixed**, device check pending | — |
| LA-20 | Lock screen and expanded island rendered BLANK (logo only) for every state that has an arrival time; "Order placed" (no time) and the compact island rendered fine. Cause: the iOS 18 `Countdown` (`Text(.currentDate, format: .offset(…))`), which only appears once a time exists. Fixed 10-04: `Text(timerInterval:)` on all versions. `.dynamicTypeSize` was also removed as a suspect (fonts pinned). Typechecks | P0 | **fixed, verified on device 10-04** | — |

## Verify on device

Tick each item as its phase lands. Each check needs **both** build kinds: one from Xcode (Debug) and
one from TestFlight.

- [ ] Phase 0: place an order, lock the phone, and have the store app move it to *processing*. The server log shows `APNs: Live Activity update sent for order N`, and the lock screen card changes
- [ ] Phase 0: `php artisan live-activity:test {order}` prints Apple's status and reason for that order's token
- [ ] Remounting the success screen (go to digital payment → back) still leaves **one** card
- [ ] Kill the app after placing, move the order twice from the store app, and the card follows both steps
- [ ] With APNs deliberately off (wrong key), open the app on the order details screen and the card catches up within one poll
- [ ] Rider accepts and the card shows the rider step and name
- [ ] Rider walks within about 300 m and the card shows "Almost there". At the door it shows "Here" (Phase 2)
- [ ] Picked up and delivered each light the screen and expand the island once (Phase 3)
- [ ] Cancel from admin: the card ends as cancelled, not delivered, on both paths
- [ ] Cold start the day after an order: no stale card

---

## How it works today

```
Place order ─► OrderSuccessfulScreen.trackOrder().then(start + 10 s poll)
                 │
                 ├─ MethodChannel "com.hamdiesolutions.waddi/live_activity"  (registered in SceneDelegate)
                 │     LiveActivityManager.startActivity → Activity.request(pushType: .token)
                 │     → waits for the FIRST pushTokenUpdates value → returns it to Dart
                 │
                 └─ Dart POST /api/v1/customer/live-activity-token {order_id, push_token}
                        → live_activity_tokens (unique order_id)

Status change (store app / rider app / admin)
   └─ Helpers::send_order_notification($order)          ← hooked 10-01 (64a48cf, on origin/main)
        └─ OrderNotificationService::sendLiveActivityUpdate
             └─ LiveActivityService::pushUpdate → POST https://api[.sandbox].push.apple.com/3/device/<token>
                  topic com.hamdiesolutions.waddi.push-type.liveactivity, priority 10

App-side updates:  OrderSuccessfulScreen 10 s poll (stops on dispose)
                   FirebaseMessaging.onMessage (foreground only) → _updateLiveActivityFromFCM
```

The success screen goes away within seconds, and the FCM path only runs with the app in the
foreground. **For the order's real life (app backgrounded, phone locked), APNs is the only updater.**

## Findings

### LA-01 · P0 · The production APNs path is unproven

The 09-30 fix hooked `send_order_notification`, and the 10-01 commit added log lines. No log line has
been confirmed yet. Any one of these would freeze the card with no visible error:

- `APNS_TEAM_ID` / `APNS_KEY_ID` / `APNS_PRIVATE_KEY_PATH` are missing → `APNs not configured — skipping`.
- The key path isn't readable by PHP-FPM's user. `config/services.php` calls `file_get_contents` at config load, which also means a bad path can break `config:cache`.
- The server's curl lacks HTTP/2. APNs is HTTP/2 only, and `withOptions(['version' => 2.0])` can't force it.
- Config is cached from before the `.env` edit, so `php artisan config:clear` was never run.
- The `.p8` key was created without the APNs capability, or under a different team.

**Fix (Phase 0, no app build):** run this on the server.

```bash
curl -V | grep -o HTTP2                         # must print HTTP2
grep ^APNS_ .env                                # 5 keys; BUNDLE_ID=com.hamdiesolutions.waddi
sudo -u www-data test -r "$APNS_PRIVATE_KEY_PATH" && echo readable
php artisan config:clear
tail -f storage/logs/laravel.log | grep -i apns # then move a test order
```

Then add `LA-16`'s command so the next check takes one line.

### LA-02 · P0 · One APNs environment for two kinds of token

`RunnerDebug.entitlements` has `aps-environment = development`, and `Runner.entitlements` has
`production`. A build run from Xcode gets **sandbox** activity tokens. TestFlight and App Store get
**production** tokens. The backend picks one host from `APNS_ENVIRONMENT` for everyone. Whichever
value is set, the other kind of build is rejected with `400 BadDeviceToken`. The memory note says
"sandbox for Xcode builds, production for TestFlight", which means the setting has to be changed by
hand between test runs. That has almost certainly produced at least one "not updating at all" session.

**Fix:**
- App: send `'apns_env': kDebugMode ? 'sandbox' : 'production'` with the token. Profile and Release both sign with `Runner.entitlements`, so `kDebugMode` is the right test.
- Backend: add an `apns_env` column to `live_activity_tokens`. `pushUpdate` picks the host per token, and `APNS_ENVIRONMENT` becomes only the fallback for old rows.
- On `400 BadDeviceToken`, retry once against the other host and store whichever succeeds. This self-heals rows saved before the column existed.

### LA-03 · P0 · Duplicate activities

`startActivity` never looks at `Activity<OrderTrackingAttributes>.activities`. The success screen is
remounted on web payment callbacks, which is why `_loggedPurchases` exists. Each remount requests a
new activity. The user sees two cards. Only the last token survives `updateOrCreate(['order_id'])`, so
the other card never moves.

**Fix (Swift):** if an activity with the same `orderId` already exists, update it with the incoming
state. Return its current `pushToken` instead of requesting a new one.

### LA-04 · P0 · The app never repairs the card

Nothing calls `updateActivity` from these places:
- the order details screen. It polls `trackOrder` every 30 s, or 10 s near the rider, since LT-*.
- `OrderTrackingBar`. It has a lifecycle hook and running orders.
- app resume or cold start.

So when APNs fails, opening the app doesn't help. The card stays wrong even while the user is looking
at the right status in-app. This is what turns an APNs problem into "never updates at all".

**Fix (Dart):** add a single `LiveActivitySync`, owned by `OrderController`.
- `sync(OrderModel)`: update the activity, or end it if the status is terminal. It no-ops when nothing changed, with the same status/subStatus/arrival/rider dedupe as the success screen's `_lastLiveActivityStatus`.
- Call it from every place the app already learns an order's state: `trackOrder` / `refreshTrackedOrder` results, `getRunningOrders`, and the FCM foreground path. The success screen's private 10 s timer goes away.
- On resume and cold start, a new native method `listActivities` returns `[orderId]`. For each one: if the order is in running orders, sync it and **re-POST its token** (`updateOrCreate`, cheap). That recovers from a failed first POST or a backend reset. If it isn't running, fetch it once and end the card (`LA-15`).

### LA-05 · P1 · Token handling

In `LiveActivityManager.startActivity`:
- `for await pushToken in activity.pushTokenUpdates { …; break }` keeps only the first token. Apple can rotate tokens, and a rotated token is never sent.
- `result` is called only from inside that loop. No token means the Dart future never completes.

In `_sendPushTokenToBackend`, `ApiClient.postData` returns non-2xx responses without throwing. A 401
(guest), 403 (module-check) or 422 is therefore silent.

**Fix:**
- Swift: return from `start` right away with the activity id. Keep one long-lived `Task` per activity that forwards **every** token to Dart over a channel callback (`onPushToken {orderId, token}`). Also forward `activityStateUpdates` (`dismissed` / `ended`) so Dart can stop syncing a card the user swiped away.
- Dart: POST each token, check `statusCode`, and retry with backoff on failure. Log the status code in debug.

### LA-06 · P1 · Guests

The route is inside `Route::group(['prefix'=>'customer','middleware'=>'auth:api'])`. Guest orders carry
`guest_id` and no bearer token. **Fix:** move the route out of `auth:api` and accept either an
authenticated user or the `guest_id` header that the guest order endpoints already use. Ownership is
checked against that (`LA-07`).

### LA-07 · P1 · No ownership check (security)

`exists:orders,id` is the only check. Any logged-in user can post their own device's token against
someone else's order id. Their lock screen would then show that order's store, rider name and arrival
time. **Fix:** require `order.user_id == auth user` (or `order.is_guest && guest_id matches`). Return
403 otherwise.

### LA-08 · P1 · APNs inside the transaction

`OrderStatusService::updateStatus` runs `send_order_notification` inside `DB::transaction` while
`lockForUpdate` holds the order row. That function now begins with the synchronous APNs call. FCM is
in there too, but FCM was already there. A slow or hanging Apple connection holds the lock and delays
the store app's response.

**Fix:** a queued `PushLiveActivity` job, `dispatch(...)->afterCommit()`, with a 10 s HTTP timeout and
3 tries. If the server runs no queue worker, which needs checking, use `dispatch_sync` after commit
(`DB::afterCommit(fn …)`). That at least releases the lock first.

### LA-09 · P1 · Rider accept is invisible

`accept_order` sets `order_status = 'accepted'` and `delivery_man_id`, then sends a bare FCM by hand.
`send_order_notification` is never called. The widget handles `accepted` (the same stage as
confirmed) and would show the rider's name, but it never gets the push. **Fix:** call
`(new OrderNotificationService)->sendLiveActivityUpdate($order)` after the save, through the `LA-08`
job. Also add `'accepted'` to `STATUS_STEPS`, which currently falls back to `pending` → step 0.

### LA-10 · P2 · "Almost there" and "Here" are dead

`checkProximityNotification` and `updateSubStatus` exist, but the only caller is
`OrderTrackingService::logLocationUpdate`. That method is reached from the web SSE stream route,
which nothing uses. The rider app writes location through `record_location_data`, and that only
upserts `delivery_histories`.

**Fix:** in `record_location_data`, for each of the rider's `picked_up` orders, run the proximity
check at most once per 30 s per order (cache key). Thresholds: `nearby` < 500 m (already coded),
`arrived` < 60 m. Each one pushes once, because `sub_status` guards it.

This shares its inputs with `LT-*`'s light rider-location endpoint. Reuse that cached read, not a
new query.

### LA-11 · P2 · ETA freshness

- Backend: while `picked_up`, re-push only when `estimated_delivery_at` moves by ≥ 3 min. Use priority **5**, so it doesn't count against the alerting budget. `EstimatedDeliveryService::recalculateOnStatusChange` already exists, but the vendor path (`VendorController@update_order_status`) sets the status directly and never recalculates. Route that path through `OrderStatusService` too.
- FCM data: add `arrival_at` (unix seconds, same value as the APNs `arrivalAt`). `_updateLiveActivityFromFCM` uses it and falls back to `now + eta_minutes` only when it's missing.

### LA-12 · P2 · Silent at the moments that matter

Every push is a bare `content-state` update. **Fix:** add `aps.alert` on `picked_up`, `delivered`
and `canceled` only, in the user's language (`customer.current_language_key`). The copy matches the
widget's `TrackingModel` titles. Include `"sound": "default"`. iOS lights the lock screen and expands
the island for those three, and every other update stays silent at priority 5. Apple's budget for
priority-10 pushes is limited, so this also stops ordinary steps from spending it.

### LA-13 · P2 · Push-to-start

iOS 17.2+ exposes `Activity<OrderTrackingAttributes>.pushToStartTokenUpdates`, one token per app
install. Send it to the backend with the FCM token on login/launch, in a new nullable
`users.la_start_token` + `la_start_env` column.

The backend can then **start** the card itself:
- when an order is confirmed and no activity token exists after 60 s, which means the local start failed or the app died;
- for scheduled orders: when they move to processing, instead of at placement.

The started activity sends its update token back through `LA-05`'s stream. On iOS < 17.2 the
behaviour stays as it is now. Also skip the local start for `scheduled == 1` orders whose time is
more than 1 h away.

### LA-14 · P2 · One device per order

Change the unique key to `(order_id, push_token)`. `sendLiveActivityUpdate` then pushes to every row
for the order. This lands together with the `LA-02` migration.

### LA-15 · P3 · Lingering cards

This is covered by `LA-04`'s resume/cold-start sweep: an activity whose order isn't running gets
fetched once and ended with its real status. The backend also deletes token rows once the order ends,
because they're useless after the `end` push.

### LA-16 · P3 · Diagnostic command

`php artisan live-activity:test {order} {--env=}` builds the same payload, pushes it, and prints
Apple's HTTP status, `apns-id` and `reason`. It also prints which host and topic it used. Phase 0
needs this to be quick.

### LA-17 · P3 · Bad tokens

Delete the row on `400` with reason `BadDeviceToken` / `DeviceTokenNotForTopic`, after `LA-02`'s
other-host retry has also failed, and on `410`. Log `reason` at warning level with the env and
order id.

### LA-18 · P3 · Decision: `storeLogoUrl`

The widget can't fetch URLs. Showing the store logo would mean the app downloading it into an App
Group container before `start`. The current design deliberately leads with the Waddy mark, so the
recommendation is to **stop sending the field** and keep the design. If the store logo is wanted
later, it needs the App Group entitlement on both targets.

## Phases

1. **Phase 0, diagnose (server only, today):** `LA-01` checklist plus the `LA-16` command. If this
   alone makes cards move on a TestFlight build, `LA-02` has been confirmed as the cause.
2. **Phase 1, make it update:** `LA-02`, `LA-03`, `LA-04`, `LA-05` (app); `LA-02`, `LA-06`, `LA-07`,
   `LA-08`, `LA-09` (backend, one migration). The app and backend can ship separately. The app side
   alone fixes "frozen while I'm looking at the app".
3. **Phase 2, make it accurate:** `LA-10`, `LA-11`, `LA-14`, `LA-15`, `LA-17`.
4. **Phase 3, make it better:** `LA-12` alerts, `LA-13` push-to-start.

Later, not planned: an iOS 17 App Intent "Call rider" button on the expanded card, and iOS 18
`supplementalActivityFamilies([.small])` for the Watch Smart Stack. Both are cheap once the data is
reliable.

## Files

| Side | File |
|---|---|
| Native | `ios/Runner/LiveActivityManager.swift`, `ios/Runner/SceneDelegate.swift` (channel), `ios/WaddiLiveActivity/*` |
| Dart | `lib/services/live_activity_service.dart`, `lib/helper/live_activity_helper.dart`, `lib/features/checkout/screens/order_successful_screen.dart`, `lib/helper/notification_helper.dart` (`_updateLiveActivityFromFCM`), `lib/features/order/controllers/order_controller.dart` (new sync hook) |
| Backend | `app/Services/LiveActivityService.php`, `app/Services/OrderNotificationService.php`, `app/Http/Controllers/Api/V1/LiveActivityController.php`, `app/CentralLogics/helpers.php` (`send_order_notification`), `app/Services/OrderStatusService.php`, `app/Http/Controllers/Api/V1/DeliverymanController.php` (`accept_order`, `record_location_data`), `app/Http/Controllers/Api/V1/Vendor/VendorController.php`, `config/services.php`, `routes/api/v1/api.php` |
