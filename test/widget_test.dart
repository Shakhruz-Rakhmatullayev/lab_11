import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/main.dart';
import 'package:habitflow/models/note_item.dart';
import 'package:habitflow/models/product.dart';
import 'package:habitflow/services/product_service.dart';
import 'package:habitflow/state/app_state.dart';
import 'package:habitflow/utils/format.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shaped like the real https://fakestoreapi.com/products response.
/// Product 2 has an int price and int rating on purpose.
final fixture = [
  {
    'id': 1,
    'title': 'Foldsack Backpack',
    'price': 109.95,
    'description': 'Your perfect pack for everyday use.',
    'category': "men's clothing",
    'image': 'https://fakestoreapi.com/img/1.png',
    'rating': {'rate': 3.9, 'count': 120},
  },
  {
    'id': 2,
    'title': 'Slim Fit T-Shirt',
    'price': 22,
    'description': 'Slim-fitting style.',
    'category': "men's clothing",
    'image': 'https://fakestoreapi.com/img/2.png',
    'rating': {'rate': 4, 'count': 259},
  },
  {
    'id': 3,
    'title': 'Cotton Jacket',
    'price': 55.99,
    'description': 'Great outerwear jacket.',
    'category': "men's clothing",
    'image': 'https://fakestoreapi.com/img/3.png',
    'rating': {'rate': 4.7, 'count': 500},
  },
];
final titles = [for (final p in fixture) p['title'] as String];

ProductService okService() => ProductService(
  client: MockClient((_) async => http.Response(jsonEncode(fixture), 200)),
);

Widget app({ProductService? service}) =>
    HabitflowApp(state: AppState(), productService: service ?? okService());

Future<void> openCatalog(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.storefront_outlined));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1179, 2556); // iPhone 15 Pro
    view.devicePixelRatio = 3;
  });

  group('Product.fromJson', () {
    test('parses an API object', () {
      final p = Product.fromJson(fixture.first);
      expect(p.id, 1);
      expect(p.price, 109.95);
      expect(p.imageUrl, 'https://fakestoreapi.com/img/1.png');
      expect(p.rating, 3.9);
      expect(p.reviewCount, 120);
      expect(p.deepLink, 'narxoz://store/product/1');
      expect(p.gallery, hasLength(3));
    });

    test('int price and int rating are converted to double', () {
      final p = Product.fromJson(fixture[1]);
      expect(p.price, 22.0);
      expect(p.rating, 4.0);
    });

    test('missing fields fall back to safe defaults', () {
      final p = Product.fromJson({});
      expect(p.id, 0);
      expect(p.title, 'Untitled product');
      expect(p.price, 0.0);
      expect(p.imageUrl, '');
      expect(p.rating, 0.0);
      expect(p.reviewCount, 0);
    });
  });

  group('ProductService', () {
    Future<String> errorFor(http.Client client) async {
      try {
        await ProductService(client: client).fetchProducts();
        return 'no error';
      } on ApiException catch (e) {
        return e.message;
      }
    }

    test('200 returns the products', () async {
      final products = await okService().fetchProducts();
      expect(products.map((p) => p.title), titles);
    });

    test('404, 500 and offline become readable errors', () async {
      expect(
        await errorFor(MockClient((_) async => http.Response('', 404))),
        contains('404'),
      );
      expect(
        await errorFor(MockClient((_) async => http.Response('', 500))),
        contains('500'),
      );
      expect(
        await errorFor(
          MockClient((_) async => throw const SocketException('offline')),
        ),
        contains('No internet'),
      );
    });

    // testWidgets runs on a fake clock, so waiting 10 s takes no real time.
    testWidgets('gives up after 10 seconds', (tester) async {
      String? message;
      ProductService(
        client: MockClient((_) => Completer<http.Response>().future),
      ).fetchProducts().catchError((Object e) {
        message = e.toString();
        return <Product>[];
      });
      await tester.pump(const Duration(seconds: 9));
      expect(message, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(message, contains('timed out'));
    });
  });

  testWidgets('every tab renders without layout errors', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('Welcome'), findsOneWidget);

    for (final (icon, title) in [
      (Icons.assignment_outlined, 'Habits'),
      (Icons.leaderboard_outlined, 'Statistic'),
      (Icons.storefront_outlined, 'Catalog'),
      (Icons.person_outline_rounded, 'Profile'),
    ]) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
      expect(find.text(title), findsWidgets);
    }
  });

  testWidgets('toggling a habit updates the done count', (tester) async {
    final state = AppState();
    await tester.pumpWidget(HabitflowApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.assignment_outlined));
    await tester.pumpAndSettle();

    final before = state.doneCount;
    await tester.tap(find.text('Read 20 pages'));
    await tester.pumpAndSettle();
    expect(state.doneCount, before + 1);
  });

  testWidgets('catalog shows a spinner, then the products', (tester) async {
    final response = Completer<http.Response>();
    await tester.pumpWidget(
      app(service: ProductService(client: MockClient((_) => response.future))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.storefront_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    response.complete(http.Response(jsonEncode(fixture), 200));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('3 items'), findsOneWidget);
    for (final t in titles) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.text('(120)'), findsOneWidget);
  });

  testWidgets('offline error recovers with Retry Connection', (tester) async {
    var online = false;
    final service = ProductService(
      client: MockClient((_) async {
        if (!online) throw const SocketException('Airplane mode');
        return http.Response(jsonEncode(fixture), 200);
      }),
    );
    await tester.pumpWidget(app(service: service));
    await tester.pumpAndSettle();
    await openCatalog(tester);
    expect(find.text('You are offline'), findsOneWidget);
    expect(find.textContaining('No internet'), findsOneWidget);

    online = true;
    await tester.tap(find.text('Retry Connection'));
    await tester.pumpAndSettle();
    expect(find.text('You are offline'), findsNothing);
    expect(find.text(titles.first), findsOneWidget);
  });

  testWidgets('pull-to-refresh reloads from the API', (tester) async {
    var calls = 0;
    final service = ProductService(
      client: MockClient((_) async {
        calls++;
        return http.Response(jsonEncode(fixture), 200);
      }),
    );
    await tester.pumpWidget(app(service: service));
    await tester.pumpAndSettle();
    await openCatalog(tester);
    expect(calls, 1);

    await tester.drag(find.text(titles.first), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 items'), findsOneWidget);

    await tester.fling(find.text(titles[1]), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('3 items'), findsOneWidget);
  });

  testWidgets('catalog toggles views and deletes with undo', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await openCatalog(tester);
    expect(find.text('List feed'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsNothing);

    await tester.drag(find.text(titles.first), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text(titles.first), findsNothing);
    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();
    expect(find.text(titles.first), findsOneWidget);

    for (final t in titles) {
      await tester.drag(find.text(t), const Offset(-500, 0));
      await tester.pumpAndSettle();
    }
    expect(find.text('Catalog is Empty'), findsOneWidget);
    await tester.tap(find.text('Reload catalog'));
    await tester.pumpAndSettle();
    expect(find.text('3 items'), findsOneWidget);
  });

  testWidgets('detail screen: hero, carousel, share link, add to cart', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await openCatalog(tester);

    await tester.tap(find.text(titles.first));
    await tester.pump();
    expect(find.byType(Hero), findsWidgets);
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.text("MEN'S CLOTHING"), findsOneWidget);
    expect(find.text('Your perfect pack for everyday use.'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('(120 reviews)'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    await tester.pumpAndSettle();
    expect(find.text('narxoz://store/product/1'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy link'));
    await tester.pumpAndSettle();
    expect(copied, 'narxoz://store/product/1');
    expect(find.text('Link copied to clipboard'), findsOneWidget);

    await tester.tap(find.text('Add to Cart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Total (1 items)'), findsOneWidget);
  });

  testWidgets('cart syncs between catalog and cart screen', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await openCatalog(tester);
    expect(find.text('Add to Cart'), findsNWidgets(3));

    final a = Product.fromJson(fixture[0]);
    final b = Product.fromJson(fixture[1]);
    await tester.tap(find.text('Add to Cart').at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Cart').at(0));
    await tester.pumpAndSettle();
    expect(find.text('In cart'), findsNWidgets(2));
    expect(find.text('2'), findsOneWidget); // badge

    await tester.tap(find.byIcon(Icons.shopping_bag_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Total (2 items)'), findsOneWidget);
    expect(find.text(formatPrice(a.price + b.price)), findsOneWidget);

    for (final step in ['Increase', 'Increase', 'Decrease']) {
      await tester.tap(find.byTooltip('$step ${b.title}'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Total (3 items)'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove ${a.title}'));
    await tester.pumpAndSettle();
    expect(find.text('Total (2 items)'), findsOneWidget);
    expect(find.text(formatPrice(b.price * 2)), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('In cart'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.shopping_bag_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Order'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Order placed'), findsOneWidget);
    expect(find.text('Your cart is empty'), findsOneWidget);
  });

  testWidgets('Clear All link empties the cart', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await openCatalog(tester);
    await tester.tap(find.text('Add to Cart').first);
    await tester.tap(find.byIcon(Icons.shopping_bag_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart is empty'), findsOneWidget);
  });

  test('settings survive an app restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    AppState(prefs: prefs)
      ..setThemeMode(ThemeMode.dark)
      ..setSound(false)
      ..setReminder(const TimeOfDay(hour: 21, minute: 30))
      ..toggleCaution('Knees');

    final restarted = AppState(prefs: prefs);
    expect(restarted.themeMode, ThemeMode.dark);
    expect(restarted.sound, isFalse);
    expect(restarted.reminder, const TimeOfDay(hour: 21, minute: 30));
    expect(restarted.cautionAreas, containsAll(['Lower back', 'Knees']));
  });

  group('LW11 Notes & Settings Vault', () {
    test('NoteItem survives a JSON round-trip', () {
      final notes = [
        NoteItem(id: '1', title: 'Buy milk', dateText: 'today'),
        NoteItem(id: '2', title: 'Lab 11', dateText: 'now', isCompleted: true),
      ];
      final raw = NoteItem.encodeList(notes);
      expect(raw, contains('"isCompleted":true'));

      final back = NoteItem.decodeList(raw);
      expect(back.map((n) => n.toJson()), notes.map((n) => n.toJson()));
      expect(NoteItem.decodeList(null), isEmpty);
      expect(NoteItem.decodeList('not json'), isEmpty);
    });

    test('everything survives a cold restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final first = AppState(prefs: prefs);
      expect(first.displayName, kGuestName);
      first
        ..setDarkMode(true)
        ..setDisplayName('  Zhasmina  ')
        ..addNote('First')
        ..addNote('Second');
      first.toggleNote(first.notes.last);
      expect(prefs.getBool(kDarkModeKey), isTrue);
      expect(prefs.getString(kDisplayNameKey), 'Zhasmina');

      final restarted = AppState(prefs: prefs);
      expect(restarted.themeMode, ThemeMode.dark);
      expect(restarted.displayName, 'Zhasmina');
      expect(restarted.notes.map((n) => n.title), ['Second', 'First']);
      expect(restarted.notes.last.isCompleted, isTrue);

      restarted.deleteNote(restarted.notes.first);
      expect(AppState(prefs: prefs).notes.map((n) => n.title), ['First']);
    });

    testWidgets('vault screen adds, toggles and deletes notes', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = AppState(prefs: prefs);
      await tester.pumpWidget(
        HabitflowApp(state: state, productService: okService()),
      );
      await tester.tap(find.byIcon(Icons.person_outline_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notes & Settings Vault'));
      await tester.pumpAndSettle();
      expect(find.text('Hello, Guest User'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('nameField')), 'Aru');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Hello, Aru'), findsOneWidget);

      await tester.tap(find.byKey(const Key('darkModeSwitch')));
      await tester.pumpAndSettle();
      expect(prefs.getBool(kDarkModeKey), isTrue);

      await tester.enterText(find.byKey(const Key('noteField')), 'Note A');
      await tester.tap(find.byKey(const Key('addNote')));
      await tester.pumpAndSettle();
      expect(find.text('Note A'), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(
        NoteItem.decodeList(prefs.getString(kNotesKey)).single.isCompleted,
        isTrue,
      );

      await tester.tap(find.byTooltip('Delete note'));
      await tester.pumpAndSettle();
      expect(find.text('Note A'), findsNothing);
      expect(NoteItem.decodeList(prefs.getString(kNotesKey)), isEmpty);
    });
  });
}
