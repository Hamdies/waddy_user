# Waddy Grocery — Store-First Restructure (COMPLETED)

## Previous Architecture (Item-First — REMOVED)

### What the Grocery Home Screen shows today:
```
┌─────────────────────────────────┐
│ Smart App Bar (address + cart)  │
│ Search Bar + Filter             │
│ Categories Grid (8 tiles)       │  ← item-first: browse items by category
│ Ramadan Stall                   │
│ Flash Sales                     │  ← item-first: items across all stores
│ Banner                          │
│ Special Offers (items)          │  ← item-first: discounted items
│ Best Reviewed Items             │  ← item-first: items by rating
│ Just For You (campaigns)        │  ← item-first: campaign items
│ Visit Again (stores)            │  ← store section (good)
│ Popular Stores                  │  ← store section (good)
│ Best Stores Nearby              │  ← store section (good)
│ ─── All Stores list ───        │  ← from home_screen.dart (paginated)
└─────────────────────────────────┘
```

### Problems with current approach:
1. **Categories lead to items across ALL stores** — user doesn't know which store they're buying from
2. **Item sections (Special Offers, Best Reviewed, Just For You)** show items without store context
3. **Store sections are buried at the bottom** — user scrolls past 5+ item sections before seeing stores
4. **No store selection before browsing** — confusing for multi-store grocery (delivery fees, minimums differ per store)
5. **LiveCartWidget exists but is NOT rendered inside GroceryHomeScreen** — it's only in the dashboard's `_BottomNavWithLiveCart`, which shows it as a floating overlay. The grocery home screen itself has no reference to it.

### What the LiveCartWidget issue is:
The `LiveCartWidget` is rendered in `dashboard_screen.dart` line 955 inside `_BottomNavWithLiveCart`. It replaces the bottom nav bar for grocery/food modules. It IS showing — but only when the dashboard detects a grocery module. If you're not seeing it, the cart may be empty (it returns `SizedBox.shrink()` when `cartList.isEmpty`).

---

## Store-First Model (Talabat Grocery / Carrefour)

### User Flow:
```
Home → Pick a Store → Browse categories/items WITHIN that store → Add to cart → Checkout
```

### New Grocery Home Screen Layout:
```
┌─────────────────────────────────┐
│ Smart App Bar (address + cart)  │  KEEP
│ Search Bar                      │  KEEP (searches stores + items)
│                                 │
│ ══ HERO: Nearby Stores ══      │  NEW — large store cards, horizontal scroll
│ [Carrefour] [Lulu] [Spinneys]  │  with logo, name, delivery time, min order
│                                 │
│ ══ Visit Again ══              │  MOVE UP — stores user ordered from
│                                 │
│ ══ Flash Sales ══              │  KEEP — but show store name on each item
│                                 │
│ ══ Banner ══                   │  KEEP
│                                 │
│ ══ Categories (quick access) ══│  KEEP — but tapping goes to store picker
│                                 │        for that category, not raw item list
│                                 │
│ ══ Popular Stores ══           │  MOVE UP
│                                 │
│ ══ All Stores (paginated) ══   │  KEEP — from home_screen.dart
│                                 │
│ [LiveCartWidget floating]       │  Already works via dashboard
└─────────────────────────────────┘
```

### Key Changes:

#### 1. GroceryHomeScreen — Reorder sections (MAJOR)
**File:** `lib/features/home/screens/modules/grocery_home_screen.dart`

- **REMOVE** item-first sections: `SpecialOfferView`, `BestReviewItemView`, `JustForYouView`
- **ADD** hero store section at top: large horizontal store cards (nearby stores)
- **MOVE UP** `VisitAgainView` to right after search bar
- **MOVE UP** `PopularStoreView` to before categories
- **KEEP** `FlashSaleViewWidget`, `BannerView` (these are promotional)
- **KEEP** categories but change tap behavior: category tap → shows stores that have items in that category (or goes to store picker filtered by category)
- **REMOVE** `BestStoreNearbyView` (merged into hero section)

#### 2. New Hero Store Section Widget
**File:** `lib/features/home/widgets/views/nearby_stores_hero_view.dart` (NEW)

- Large horizontal scrolling store cards
- Each card shows: store logo, name, rating, delivery time estimate, minimum order, discount badge
- Tapping a store → navigates to `StoreScreen`
- Uses `storeController.latestStoreList` or a new "nearby stores" list

#### 3. Category Tap Behavior Change
**Current:** Category tap → `CategoryItemScreen` (shows items across all stores)
**New:** Category tap → `CategoryItemScreen` BUT with store context, OR → filtered store list showing stores that carry items in that category

This is a **frontend-only** change — the existing `CategoryItemScreen` already shows items, and each item has a store. We can add a "store filter" or group items by store within the category screen.

#### 4. LiveCartWidget — Already Working
The `LiveCartWidget` IS rendered via `_BottomNavWithLiveCart` in `dashboard_screen.dart`. It shows when:
- Module is grocery or food
- Cart is not empty
- User is on home tab (not cart tab)

If it's not visible, the cart is likely empty. No code change needed here.

---

## Implementation Plan (Ordered)

### Phase 1: Restructure GroceryHomeScreen (store-first layout)
1. Create `NearbyStoresHeroView` widget — large store cards
2. Reorder `GroceryHomeScreen` sections:
   - App bar → Search → Visit Again → Nearby Stores Hero → Flash Sales → Banner → Categories → Popular Stores → (All Stores from home_screen.dart)
3. Remove item-first sections (`SpecialOfferView`, `BestReviewItemView`, `JustForYouView`, `ItemThatYouLoveView`)

### Phase 2: Enhance Store Cards
4. Update store card design for hero section (larger, more info)
5. Add delivery time estimate, minimum order badge

### Phase 3: Category → Store Context
6. Update category tap to show items grouped by store, or add store filter to `CategoryItemScreen`

### Phase 4: LiveCartWidget Verification
7. Verify LiveCartWidget shows correctly (it should already work — just needs items in cart)

---

## Files to Modify:
- `lib/features/home/screens/modules/grocery_home_screen.dart` — MAJOR rewrite
- `lib/features/home/widgets/views/nearby_stores_hero_view.dart` — NEW
- `lib/features/home/screens/home_screen.dart` — Minor (data loading priority)
- `lib/features/category/screens/category_item_screen.dart` — Minor (add store grouping)

## Files NOT Modified:
- `lib/features/dashboard/widgets/live_cart_widget.dart` — Already works
- `lib/features/dashboard/screens/dashboard_screen.dart` — Already handles grocery module
- `lib/features/store/screens/store_screen.dart` — Already exists and works
- Backend — No changes needed

## Estimated Effort:
- Phase 1: ~1-2 hours (reorder + new widget)
- Phase 2: ~30 min (card design)
- Phase 3: ~1 hour (category context)
- Phase 4: ~15 min (verification)
- **Total: ~3-4 hours**
