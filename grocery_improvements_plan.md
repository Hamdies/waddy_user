# Waddy Grocery System — Full Improvement Plan

## Legend
- ✅ **Frontend Only** — We can do this right now, no backend needed
- 🔶 **Backend Needed** — Requires new/modified API endpoint
- 🟢 **Backend Already Exists** — API exists, just needs frontend work

---

## P0 — CRITICAL (Do First)

### 1. Fix Hardcoded Strings & Null-Safety ✅ Frontend Only

**What:** 
- Cart `notAvailableList` has 5 hardcoded English strings → use `.tr` keys
- Store screen product card "ADD" button → use `'add'.tr`
- Multiple `!` null-bang operators on `item.price!`, `item.name!`, `item.avgRating!` across models and services → add null-safe defaults

**Files to change:**
- `lib/features/cart/controllers/cart_controller.dart` (lines 45-51)
- `lib/features/store/screens/store_screen.dart` (line 956)
- `lib/features/search/domain/services/search_service.dart` (lines 40-106)
- `lib/features/item/domain/models/item_model.dart` (fromJson methods)
- `lib/features/store/domain/models/store_model.dart` (fromJson methods)

**Backend needed:** None

---

### 2. Search Overhaul — Pagination, Sorting, Debounce

#### 2a. Search Pagination 🔶 Backend Needed

**Current problem:** Search API call is:
```
/api/v1/items/search?name=$query&offset=1&limit=50
```
It hardcodes `offset=1&limit=50`. No pagination support in the controller.

**Backend needs to:**
- Already supports `offset` and `limit` params ✅
- Return `total_size` in response so frontend knows total pages ✅ (ItemModel already has `totalSize`)

**Frontend work:** 
- Pass dynamic `offset` to search API
- Add scroll-based pagination in search results (like category_item_screen already does)
- Show "Load more" or infinite scroll

#### 2b. Sort by Price/Rating/Distance/Popularity 🔶 Backend Needed

**Current problem:** `sortItemSearchList` and `sortStoreSearchList` only sort by name (A-Z / Z-A). For a grocery app this is useless.

**Backend needs to:**
- Accept `sort_by` param: `price_low_to_high`, `price_high_to_low`, `rating`, `popularity`, `distance`, `newest`
- Accept `lat` and `lng` for distance-based sorting
- Example: `/api/v1/items/search?name=milk&sort_by=price_low_to_high&offset=1&limit=20`

**Frontend work:**
- Add sort options to filter widget
- Pass sort param to API
- Remove client-side sorting (keep as fallback)

#### 2c. Search Debounce ✅ Frontend Only

**Current problem:** No debounce — each keystroke triggers API call.

**Frontend work:**
- Add 400ms debounce timer in search controller before calling API
- Already have `getSearchSuggestions` — add debounce there too

#### 2d. Server-Side Filtering 🔶 Backend Needed

**Current problem:** Price range, rating, veg/nonVeg, available, discounted filters are all client-side on the already-fetched 50 items.

**Backend needs to:**
- Accept filter params: `min_price`, `max_price`, `rating`, `veg`, `non_veg`, `available`, `discounted`
- Example: `/api/v1/items/search?name=milk&min_price=5&max_price=50&rating=4&offset=1&limit=20`

**Frontend work:**
- Pass filter params to API instead of filtering locally
- Keep client-side filtering as fallback for offline/cached results

---

### 3. Delivery Time Slot Picker 🟢 Already Exists — Needs UI Improvement

**Discovery:** Time slot system already exists!
- `lib/features/checkout/widgets/time_slot_bottom_sheet.dart` ✅
- `lib/features/checkout/domain/models/timeslote_model.dart` ✅
- `lib/features/checkout/widgets/time_slot_section.dart` ✅
- `lib/features/checkout/widgets/slot_widget.dart` ✅

**What's needed:** Review and improve the existing time slot UI:
- Make it more prominent in checkout (not hidden)
- Add "Express delivery" option (30-60 min)
- Better visual design matching our grocery theme
- Show estimated delivery time on cart screen too

**Backend needed:** Likely none — already supported

---

## P1 — HIGH PRIORITY

### 4. Buy Again / Reorder Feature 🔶 Backend Needed

**Current state:** Order history exists (`/api/v1/customer/order/list`) and order details exist (`/api/v1/customer/order/details?order_id=`). But there's NO reorder/buy-again endpoint.

**Backend needs to:**
- **New endpoint:** `GET /api/v1/customer/order/frequently-ordered-items`
  - Returns items the user has ordered most frequently
  - Sorted by frequency, limited to 20 items
  - Include current price, stock status, store info
- **New endpoint:** `POST /api/v1/customer/order/reorder?order_id={id}`
  - Takes an old order ID, adds all available items to cart
  - Returns which items were added and which are unavailable

**Frontend work:**
- New "Buy Again" section on grocery home screen (horizontal scroll)
- "Reorder" button on order history cards
- Handle unavailable items gracefully (show which items couldn't be added)

---

### 5. Nearby Stores on Home Screen 🟢 Already Exists — Needs Integration

**Discovery:** These endpoints already exist:
- `/api/v1/stores/get-stores` — gets stores (supports location)
- `/api/v1/stores/popular` — popular stores
- `/api/v1/stores/latest` — latest stores
- `/api/v1/stores/recommended` — recommended stores
- `/api/v1/customer/visit-again` — visit again stores

And these **unused widgets** exist:
- `lib/features/home/widgets/views/top_grocery_stores_view.dart`
- `lib/features/home/widgets/views/popular_store_view.dart`
- `lib/features/home/widgets/views/recommended_store_view.dart`
- `lib/features/home/widgets/views/visit_again_view.dart`
- `lib/features/home/widgets/views/best_store_nearby_view.dart`

**Backend needed:** None — already exists!

**Frontend work:**
- Add `VisitAgainView`, `PopularStoreView`, or `BestStoreNearbyView` to `GroceryHomeScreen`
- These widgets already exist but aren't included in the grocery home screen layout

---

### 6. Store Item Pagination (Lazy Load by Category) 🔶 Backend Needed

**Current problem:** `store_screen.dart` calls `getStoreItemList(storeId, 1, 'all', false)` which loads ALL items at once, then groups by category client-side.

**Backend needs to:**
- **Modify endpoint:** `/api/v1/items/latest?store_id={id}&category_id={cat_id}&offset={n}&limit=20`
  - Support filtering by `category_id` within a store
  - Support pagination per category
- OR: **New endpoint:** `/api/v1/stores/{id}/items-by-category?offset=1&limit=20`
  - Returns items grouped by category with pagination

**Frontend work:**
- Load only first 10 items per category initially
- Add "View All" per category that loads paginated list
- Lazy load more items as user scrolls

---

### 7. Minimum Order Progress Bar in Cart ✅ Frontend Only

**Current state:** Store model already has `minimumOrder` field. Cart already calculates `subTotal`. But there's no visual indicator.

**Frontend work:**
- Add a progress bar widget at top of cart screen
- Show: "Add {X} more to reach minimum order of {Y}"
- Green when minimum is met
- Use existing `store.minimumOrder` and `cartController.subTotal`

**Backend needed:** None

---

### 8. Break Checkout Into Smaller Widgets ✅ Frontend Only

**Current problem:** `checkout_screen.dart` is 2288 lines with 4 nested GetBuilders.

**Frontend work:**
- Extract address section → `CheckoutAddressSection`
- Extract payment section → `CheckoutPaymentSection`  
- Extract order summary → `CheckoutOrderSummary`
- Extract coupon section → `CheckoutCouponSection`
- Extract tip section → `CheckoutTipSection`
- Move price calculations out of `build()` into controller
- Pure refactor — no behavior change

**Backend needed:** None

---

## P2 — MEDIUM PRIORITY

### 9. Shopping List Feature 🔶 Backend Needed

**What:** Users create named lists ("Weekly Groceries", "Party Supplies") and add items over time, then add all to cart.

**Backend needs to:**
- **New endpoints:**
  - `GET /api/v1/customer/shopping-lists` — get all lists
  - `POST /api/v1/customer/shopping-lists` — create list (name)
  - `PUT /api/v1/customer/shopping-lists/{id}` — update list name
  - `DELETE /api/v1/customer/shopping-lists/{id}` — delete list
  - `POST /api/v1/customer/shopping-lists/{id}/items` — add item to list
  - `DELETE /api/v1/customer/shopping-lists/{id}/items/{item_id}` — remove item
  - `GET /api/v1/customer/shopping-lists/{id}/items` — get items in list

**Frontend work:**
- New `shopping_list` feature module
- Shopping list screen with CRUD
- "Add to list" option on item cards/details
- "Add all to cart" button on list screen

---

### 10. Item Substitution Preferences 🔶 Backend Needed

**What:** When placing an order, user can set per-item preferences: "If unavailable: substitute with similar / remove from order / cancel order"

**Backend needs to:**
- **Modify order placement:** Accept `substitution_preference` per cart item
  - Values: `substitute_similar`, `remove_item`, `contact_me`, `cancel_order`
- **Modify cart model:** Add `substitution_preference` field
- Store should see these preferences when fulfilling

**Frontend work:**
- Add substitution picker per item in cart
- Replace hardcoded `notAvailableList` with proper localized options
- Show substitution preference on order details

---

### 11. Barcode Scanner 🔶 Backend Needed

**What:** User scans a product barcode → app finds the item.

**Backend needs to:**
- **New endpoint:** `GET /api/v1/items/barcode?code={barcode}`
  - Returns item matching the barcode
  - Items need a `barcode` field in the database

**Frontend work:**
- Add `mobile_scanner` or `flutter_barcode_scanner` package
- Barcode scan button on search bar
- Navigate to item details on match
- Show "Item not found" if no match

---

### 12. Weight/Unit Picker for Produce 🔶 Backend Needed

**What:** Items like fruits, vegetables, meat should let users pick quantity by weight (500g, 1kg) or by piece.

**Backend needs to:**
- **Modify Item model:** Add `unit_options` array
  - Example: `[{"unit": "500g", "price": 5.0}, {"unit": "1kg", "price": 9.5}, {"unit": "piece", "price": 2.0}]`
- OR use existing `variations` system but with weight-specific labels

**Frontend work:**
- Weight/unit selector on item detail screen
- Show unit in cart (e.g., "Bananas × 1kg")
- Update price based on selected unit

**Note:** The existing `unitType` field on Item model is a single string. It needs to become a list of options with prices.

---

### 13. Real-Time Stock Updates 🔶 Backend Needed

**What:** When user is browsing a store, stock should update in real-time (or near real-time) so they don't add out-of-stock items.

**Backend needs to:**
- **WebSocket/Pusher channel:** `store.{store_id}.stock`
  - Emits events when stock changes: `{item_id: 123, stock: 0}`
- OR: **Polling endpoint:** `GET /api/v1/items/stock-check?item_ids=1,2,3,4`
  - Returns current stock for multiple items at once

**Frontend work:**
- Listen to stock updates when on store screen
- Grey out / disable "ADD" button when stock = 0
- Show "Out of Stock" badge
- Remove from cart if stock drops to 0 while browsing

---

## P3 — NICE TO HAVE

### 14. Cache Strategy for Categories/Stores ✅ Frontend Only

**Frontend work:**
- Cache category list in SharedPreferences with timestamp
- Show cached data immediately, refresh in background
- Cache store list per zone
- Use `DataSourceEnum` (already exists in codebase) to switch between cache/network

**Backend needed:** None

---

### 15. Extract Shared Category Screen Logic ✅ Frontend Only

**Frontend work:**
- `category_item_screen.dart` has `_buildMobileBody` and `_buildDesktopBody` with ~80% duplicate code
- Extract shared widgets: `CategorySubCategoryBar`, `CategoryTabView`, `CategoryItemsList`
- Pure refactor

**Backend needed:** None

---

### 16. Home Screen — Add Missing Store Sections 🟢 Already Exists

**Frontend work:**
- Add to `GroceryHomeScreen.build()`:
  - `VisitAgainView()` — stores user ordered from before
  - `BestStoreNearbyView()` or `PopularStoreView()` — nearby stores
  - `RecommendedStoreView()` — recommended stores
- These widgets already exist in `lib/features/home/widgets/views/`
- Just need to import and add to the Column

**Backend needed:** None — endpoints already exist

---

## SUMMARY: What Backend Team Needs To Do

### New Endpoints Needed:
| # | Endpoint | For Feature |
|---|----------|-------------|
| 1 | `GET /api/v1/customer/order/frequently-ordered-items` | Buy Again |
| 2 | `POST /api/v1/customer/order/reorder?order_id={id}` | Reorder |
| 3 | `GET /api/v1/customer/shopping-lists` (CRUD) | Shopping Lists |
| 4 | `GET /api/v1/items/barcode?code={code}` | Barcode Scanner |
| 5 | WebSocket `store.{id}.stock` OR `GET /api/v1/items/stock-check?item_ids=` | Real-time Stock |

### Existing Endpoints That Need Modification:
| # | Endpoint | Change Needed | For Feature |
|---|----------|---------------|-------------|
| 1 | `/api/v1/items/search` | Add `sort_by`, `min_price`, `max_price`, `rating`, `veg`, `available`, `discounted` params | Search Overhaul |
| 2 | `/api/v1/items/latest` | Add `category_id` filter for within-store pagination | Store Pagination |
| 3 | Item model in DB | Add `barcode` field | Barcode Scanner |
| 4 | Item model in DB | Add `unit_options` array (weight/unit with prices) | Weight Picker |
| 5 | Cart/Order model | Add `substitution_preference` per item | Substitution |

### What We Can Do RIGHT NOW (No Backend):
1. ✅ Fix hardcoded strings & null-safety
2. ✅ Search debounce
3. ✅ Minimum order progress bar in cart
4. ✅ Add nearby stores to home screen (widgets exist!)
5. ✅ Add visit-again stores to home screen (widget exists!)
6. ✅ Break checkout into smaller widgets
7. ✅ Cache strategy for categories
8. ✅ Extract shared category screen logic
9. ✅ Improve time slot picker UI (already exists!)

---

## Recommended Execution Order

**Phase 1 — Frontend Only (start now):**
1. Fix hardcoded strings & null-safety
2. Add store sections to home screen
3. Search debounce
4. Minimum order progress bar
5. Checkout refactor
6. Cache strategy
7. Time slot UI improvement

**Phase 2 — After Backend Delivers Search Improvements:**
8. Search pagination
9. Server-side filtering
10. Sort by price/rating/distance
11. Store item pagination

**Phase 3 — After Backend Delivers New Endpoints:**
12. Buy Again / Reorder
13. Shopping Lists
14. Item Substitution
15. Barcode Scanner
16. Weight/Unit Picker
17. Real-time Stock
