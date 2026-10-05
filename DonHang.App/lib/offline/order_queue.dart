import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import 'local_store.dart';

// Where an order is in the queue. Only the API's answer moves it on from
// waiting: 201 makes it sent, 400 or 409 makes it rejected.
enum QueuedOrderStatus { waiting, sent, rejected }

// lesson: frontend.l3.offline-order-queue
// One order the API has not answered yet, or whose answer the customer has
// not seen yet. The Idempotency-Key is made once, when the order is first
// sent, and kept for every later attempt; `subject` is the `sub` of the
// customer who placed it. The items keep the prices the customer saw.
class QueuedOrder {
  final String idempotencyKey;
  final String subject;
  final String description;
  final List<OrderItemRequest> items;
  final QueuedOrderStatus status;
  final OrderResult? result;
  final String? problem;

  QueuedOrder({
    required this.idempotencyKey,
    required this.subject,
    required this.description,
    required this.items,
    this.status = QueuedOrderStatus.waiting,
    this.result,
    this.problem,
  });

  // lesson: frontend.l3.sync-conflicts
  // True once the API has charged a total other than the one the customer
  // saw, which happens when a price changed while the order was waiting.
  bool get priceChanged {
    final charged = result;
    return charged != null && totalVnd(charged.items) != totalVnd(items);
  }

  Map<String, dynamic> toJson() => {
        'idempotencyKey': idempotencyKey,
        'subject': subject,
        'description': description,
        'items': [for (final item in items) item.toJson()],
        'status': status.name,
        if (result != null) 'result': result!.toJson(),
        if (problem != null) 'problem': problem,
      };

  factory QueuedOrder.fromJson(Map<String, dynamic> json) => QueuedOrder(
        idempotencyKey: json['idempotencyKey'] as String,
        subject: json['subject'] as String,
        description: json['description'] as String,
        items: [for (final item in json['items'] as List<dynamic>) OrderItemRequest.fromJson(item as Map<String, dynamic>)],
        status: QueuedOrderStatus.values.byName(json['status'] as String),
        result: json['result'] == null ? null : OrderResult.fromJson(json['result'] as Map<String, dynamic>),
        problem: json['problem'] as String?,
      );
}

// 16 random bytes as 32 hex digits: random enough that two orders never
// share a key, made without adding a package for UUIDs.
String newIdempotencyKey() {
  final random = Random.secure();
  return List<String>.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

// lesson: frontend.l3.offline-order-queue
// The queue, oldest first, as an outbox on the device: every change is
// written to localStorage before anything else happens, so a page reload
// cannot lose an order the customer has placed.
class OrderQueue extends Notifier<List<QueuedOrder>> {
  static const String storageKey = 'donhang.order_queue';

  @override
  List<QueuedOrder> build() {
    final saved = ref.watch(localStoreProvider).read(storageKey);
    if (saved == null) return [];
    return [for (final entry in jsonDecode(saved) as List<dynamic>) QueuedOrder.fromJson(entry as Map<String, dynamic>)];
  }

  void add(QueuedOrder order) => _save([...state, order]);

  void remove(String idempotencyKey) =>
      _save([for (final order in state) if (order.idempotencyKey != idempotencyKey) order]);

  void markSent(QueuedOrder order, OrderResult result) => _replace(order, QueuedOrderStatus.sent, result: result);

  void markRejected(QueuedOrder order, String problem) => _replace(order, QueuedOrderStatus.rejected, problem: problem);

  void _replace(QueuedOrder order, QueuedOrderStatus status, {OrderResult? result, String? problem}) {
    final updated = QueuedOrder(
      idempotencyKey: order.idempotencyKey,
      subject: order.subject,
      description: order.description,
      items: order.items,
      status: status,
      result: result,
      problem: problem,
    );
    _save([for (final entry in state) entry.idempotencyKey == order.idempotencyKey ? updated : entry]);
  }

  void _save(List<QueuedOrder> orders) {
    ref.read(localStoreProvider).write(storageKey, jsonEncode([for (final order in orders) order.toJson()]));
    state = orders;
  }
}

final orderQueueProvider = NotifierProvider<OrderQueue, List<QueuedOrder>>(OrderQueue.new);
