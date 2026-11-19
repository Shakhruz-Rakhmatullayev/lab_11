# HabitFlow

HabitFlow is a Flutter app for tracking habits and fitness. It has a glass-style interface, light and dark themes, and five screens in a floating bottom navigation bar.

## Features

- **Home**: a greeting, a search bar, today's stats (steps, calories burnt and more) with progress indicators, quick-toggle chips for today's habits, and a featured workout card.
- **Habits**: a scrollable date strip, a summary card with a progress ring, and the habit list. You can mark habits done, which updates their streaks, add new habits with a custom icon, color and time of day, or remove them.
- **Statistics**: recent workout charts for calories and duration, plus a habit-consistency heatmap.
- **Catalog**: live products from the [Fake Store API](https://fakestoreapi.com/products), shown as a list feed or a 2-column grid. While loading it shows a spinner; if the request fails (no internet, timeout, 404 or 500) it shows an offline screen with a **Retry Connection** button that reloads without restarting the app. Pull down to refresh, swipe left to delete an item (with Undo), and tap "Add to Cart" to toggle a product in the cart. The cart button in the header shows a live item-count badge.
- **Product details**: tapping a product opens its detail screen with a Hero image transition, a swipeable photo carousel with a page counter (1 / 3) and animated dots, a category badge, the rating and reviews, the full description, and a sticky "Add to Cart" button. The share button opens a sheet with the product's deep link (`narxoz://store/product/{id}`) and a copy button.
- **Cart**: the selected products with −/+ buttons to change how many pieces you want and a remove button on each, the total price, an "Order" button that places the order, and a "Clear All" link. The cart is shared with the Catalog through `provider`, so changes on either screen show up on the other right away.
- **Profile**: personal metrics (age, height, weight) and an editable profile. Settings cover reminder time, sound, notifications, appearance (system, light or dark), experience level, caution areas and units.
- **Notes & Settings Vault** (Profile → Notes & Settings Vault): a dark-mode switch (`app_theme_dark_mode`), a username field with a Save button (`user_display_name`, falls back to "Guest User"), and a notes list you can add to, check off and delete. The notes are stored as one JSON string (`notes_vault_items`) through `NoteItem.toJson()` / `NoteItem.fromJson()`. Everything is loaded in `main()` before `runApp()`, so the app opens in the saved theme without a white flash, and notes are still there after the app is force-quit.
- **Saved settings**: the theme, sound, notification, experience, reminder and caution-area settings are stored with `shared_preferences`, so they stay the same between launches.

## Tech stack

- Flutter (Dart SDK `^3.13.2`)
- State management with `ChangeNotifier` and an `InheritedNotifier` scope (`AppScope`)
- [`provider`](https://pub.dev/packages/provider): `CartProvider` (a `ChangeNotifier`) is supplied by a `ChangeNotifierProvider` that wraps `MaterialApp`
- [`http`](https://pub.dev/packages/http) for the REST API: `ProductService` sends `GET /products` with a 10-second timeout and turns network and HTTP errors into readable messages
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) for storage
- Custom painters for the progress rings, pill bar charts and wave graphics

## Project structure

```
lib/
├── main.dart                # App entry point, theme setup
├── data/sample_data.dart    # Demo stats and workout data
├── models/
│   ├── note_item.dart       # NoteItem with toJson / fromJson (Vault)
│   └── product.dart         # Product model with type-safe fromJson
├── services/
│   └── product_service.dart # HTTP fetch, timeout and error handling
├── state/
│   ├── app_state.dart       # Habit model and AppState (ChangeNotifier)
│   └── cart_provider.dart   # CartProvider (ChangeNotifier) for the cart
├── screens/
│   ├── shell.dart           # App shell + floating nav bar
│   ├── home_screen.dart
│   ├── habits_screen.dart
│   ├── statistic_screen.dart
│   ├── catalog_screen.dart  # Loading / feed / error states
│   ├── product_detail_screen.dart # Hero, photo carousel, Add to Cart
│   ├── cart_screen.dart     # Cart view + cart badge button
│   ├── profile_screen.dart
│   └── vault_screen.dart    # LW11 Notes & Settings Vault
├── theme/app_theme.dart     # Colors, text styles, light/dark themes
├── utils/format.dart        # Formatting helpers
└── widgets/
    ├── charts.dart          # ProgressRing, PillBarChart, WavePainter
    ├── glass.dart           # Glass cards, buttons, background, headers
    ├── product_image.dart   # Network product photo tile
    ├── share_sheet.dart     # Deep-link share sheet
    └── sheet.dart           # Bottom sheets
```

## Getting started

Prerequisites: the [Flutter SDK](https://docs.flutter.dev/get-started/install), plus Xcode for iOS/macOS or Android Studio for Android.

```bash
git clone https://github.com/Shakhruz-Rakhmatullayev/lab_11.git
cd lab_11
flutter pub get
flutter run
```

Run the tests:

```bash
flutter test
```

## Platforms

iOS, Android, macOS and Web.
