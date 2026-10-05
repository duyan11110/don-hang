import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:donhang_app/api_client.dart';
import 'package:donhang_app/auth/auth_controller.dart';
import 'package:donhang_app/design/brand.dart';
import 'package:donhang_app/design/theme.dart';
import 'package:donhang_app/l10n/app_localizations.dart';
import 'package:donhang_app/models.dart';
import 'package:donhang_app/offline/local_store.dart';
import 'package:donhang_app/offline/order_queue.dart';
import 'package:donhang_app/offline/queue_sync.dart';
import 'package:donhang_app/providers.dart';
import 'package:donhang_app/screens/queued_orders_screen.dart';

// A token whose payload holds only `sub`; the app never checks the signature.
String tokenFor(String subject) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': subject}))).replaceAll('=', '')}.signature';

class FixedAuth extends AuthController {
  final String? token;

  FixedAuth(this.token);

  @override
  String? build() => token;
}

// Answers each createOrder with the next scripted answer, and remembers the
// Idempotency-Key of every attempt.
class ScriptedApi extends ApiClient {
  final List<Future<OrderResult> Function()> answers;
  final List<String> keysSent = [];

  ScriptedApi(this.answers) : super(readToken: () => null);

  @override
  Future<OrderResult> createOrder(List<OrderItemRequest> items, {required String idempotencyKey}) {
    keysSent.add(idempotencyKey);
    return answers.removeAt(0)();
  }
}

Future<OrderResult> Function() created(int id, {int unitPriceVnd = 1000}) =>
    () async => OrderResult(id: id, status: 'pending', items: [
          OrderItemRequest(productId: 1, quantity: 2, unitPriceVnd: unitPriceVnd),
        ]);

Future<OrderResult> Function() problem(int status, {String detail = '', Duration? retryAfter}) =>
    () async => throw ApiProblem(status: status, type: 'about:blank', title: '', detail: detail, retryAfter: retryAfter);

Future<OrderResult> Function() noAnswer() => () async => throw ApiUnreachable();

QueuedOrder order(String key, {String subject = 'alice'}) => QueuedOrder(
      idempotencyKey: key,
      subject: subject,
      description: '2 × Bàn phím cơ',
      items: [OrderItemRequest(productId: 1, quantity: 2, unitPriceVnd: 1000)],
    );

ProviderContainer containerWith(ScriptedApi api, List<QueuedOrder> orders, {String? signedIn = 'alice'}) {
  final container = ProviderContainer(overrides: [
    localStoreProvider.overrideWithValue(MemoryLocalStore()),
    apiClientProvider.overrideWithValue(api),
    authProvider.overrideWith(() => FixedAuth(signedIn == null ? null : tokenFor(signedIn))),
  ]);
  addTearDown(container.dispose);
  for (final entry in orders) {
    container.read(orderQueueProvider.notifier).add(entry);
  }
  return container;
}

QueuedOrder entry(ProviderContainer container, String key) =>
    container.read(orderQueueProvider).firstWhere((order) => order.idempotencyKey == key);

void main() {
  // lesson: frontend.l3.syncing-the-queue
  // Oldest first, one at a time, each moved on only by the API's answer.
  test('sends the oldest order first and marks each by its answer', () async {
    final api = ScriptedApi([created(41), problem(400, detail: 'product 1 does not exist')]);
    final container = containerWith(api, [order('first'), order('second')]);

    await container.read(queueSyncProvider.notifier).sendNow();

    expect(api.keysSent, ['first', 'second']);
    expect(entry(container, 'first').status, QueuedOrderStatus.sent);
    expect(entry(container, 'first').result!.id, 41);
    expect(entry(container, 'second').status, QueuedOrderStatus.rejected);
    expect(entry(container, 'second').problem, 'product 1 does not exist');
  });

  // lesson: frontend.l3.syncing-the-queue
  // No answer: the order keeps waiting, and the next attempt sends the same
  // key, so an attempt that did reach the API cannot become a second order.
  test('no answer keeps the order waiting with the same key', () async {
    final api = ScriptedApi([noAnswer(), created(42)]);
    final container = containerWith(api, [order('only')]);
    final sync = container.read(queueSyncProvider.notifier);

    await sync.sendNow();
    expect(entry(container, 'only').status, QueuedOrderStatus.waiting);
    expect(container.read(queueSyncProvider).pause, SyncPause.notSent);

    await sync.sendNow();
    expect(api.keysSent, ['only', 'only']);
    expect(entry(container, 'only').status, QueuedOrderStatus.sent);
  });

  test('a 429 stops the sync until Retry-After has passed', () async {
    final api = ScriptedApi([problem(429, retryAfter: const Duration(seconds: 30))]);
    final container = containerWith(api, [order('first'), order('second')]);
    final sync = container.read(queueSyncProvider.notifier);

    await sync.sendNow();
    await sync.sendNow();

    expect(api.keysSent, ['first']);
    expect(container.read(queueSyncProvider).pause, SyncPause.rateLimited);
    expect(entry(container, 'second').status, QueuedOrderStatus.waiting);
  });

  test('a 401 stops the sync until the customer signs in again', () async {
    final api = ScriptedApi([problem(401)]);
    final container = containerWith(api, [order('first'), order('second')]);

    await container.read(queueSyncProvider.notifier).sendNow();

    expect(api.keysSent, ['first']);
    expect(container.read(queueSyncProvider).pause, SyncPause.signInNeeded);
  });

  // lesson: frontend.l3.syncing-the-queue
  // Bob queued an order on this browser; Alice is signed in now. Her token
  // must not place his order, so nothing is sent.
  test("sends only the signed-in customer's orders", () async {
    final api = ScriptedApi([]);
    final container = containerWith(api, [order('bobs', subject: 'bob')]);

    await container.read(queueSyncProvider.notifier).sendNow();

    expect(api.keysSent, isEmpty);
    expect(entry(container, 'bobs').status, QueuedOrderStatus.waiting);
  });

  // lesson: frontend.l3.sync-conflicts
  // The customer saw 1 000 dong a piece; the API charged the current price.
  test('flags an order whose price changed while it waited', () async {
    final api = ScriptedApi([created(43, unitPriceVnd: 1200)]);
    final container = containerWith(api, [order('only')]);

    await container.read(queueSyncProvider.notifier).sendNow();

    expect(entry(container, 'only').status, QueuedOrderStatus.sent);
    expect(entry(container, 'only').priceChanged, isTrue);
  });

  test('a page reload keeps the queue: it is read back from the store', () {
    final store = MemoryLocalStore();
    final first = ProviderContainer(overrides: [localStoreProvider.overrideWithValue(store)]);
    first.read(orderQueueProvider.notifier).add(order('kept'));
    first.dispose();

    final second = ProviderContainer(overrides: [localStoreProvider.overrideWithValue(store)]);
    addTearDown(second.dispose);
    expect(second.read(orderQueueProvider).single.idempotencyKey, 'kept');
  });

  // lesson: frontend.l3.sync-conflicts
  // On the queued orders screen a rejected order keeps the API's detail
  // until the customer removes it, and a changed price is said out loud.
  testWidgets('shows a rejected order until it is removed, and a changed price', (tester) async {
    final api = ScriptedApi([problem(400, detail: 'Product 3 does not exist.'), created(44, unitPriceVnd: 1200)]);
    final container = containerWith(api, [order('gone'), order('dearer')]);
    await container.read(queueSyncProvider.notifier).sendNow();

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(donHangBrand, Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const QueuedOrdersScreen(),
      ),
    ));

    expect(find.textContaining('Product 3 does not exist.'), findsOneWidget);
    expect(find.textContaining('the price changed: you saw 2,000 VND, the order costs 2,400 VND'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pump();
    expect(find.textContaining('Product 3 does not exist.'), findsNothing);
  });
}
