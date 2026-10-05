import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_client.dart';
import '../auth/auth_controller.dart';
import '../auth/token_subject.dart';
import '../providers.dart';
import 'browser.dart';
import 'order_queue.dart';

// Why the last sync stopped before the queue was empty.
enum SyncPause { none, notSent, rateLimited, signInNeeded }

class SyncState {
  final bool sending;
  final SyncPause pause;
  // After a 429: no send before this time (null when Retry-After was missing).
  final DateTime? resumeAt;

  const SyncState({this.sending = false, this.pause = SyncPause.none, this.resumeAt});
}

// lesson: frontend.l3.syncing-the-queue
// Sends the waiting orders when the app starts, when a customer signs in,
// when the browser says it is online again, and when the customer taps
// "Send now". There is no timer and no backoff: a sync that stops waits
// for the next of these.
class QueueSync extends Notifier<SyncState> {
  @override
  SyncState build() {
    ref.listen(authProvider, (previous, token) {
      if (token != null) sendNow();
    });
    ref.onDispose(listenForOnline(sendNow));
    Future.microtask(sendNow);
    return const SyncState();
  }

  // lesson: frontend.l3.syncing-the-queue
  // One order at a time, oldest first, and only the orders of the customer
  // signed in now: another customer on this browser cannot place them.
  Future<void> sendNow() async {
    final resumeAt = state.resumeAt;
    if (state.sending || (resumeAt != null && DateTime.now().isBefore(resumeAt))) return;
    final token = ref.read(authProvider);
    final subject = token == null ? null : tokenSubject(token);
    if (subject == null) {
      state = SyncState(pause: _hasWaiting() ? SyncPause.signInNeeded : SyncPause.none);
      return;
    }
    state = const SyncState(sending: true);
    final waiting = [
      for (final order in ref.read(orderQueueProvider))
        if (order.status == QueuedOrderStatus.waiting && order.subject == subject) order,
    ];
    for (final order in waiting) {
      final stop = await _send(order);
      if (stop != null) {
        state = stop;
        return;
      }
    }
    state = const SyncState();
  }

  // lesson: frontend.l3.syncing-the-queue
  // lesson: frontend.l3.sync-conflicts
  // Sends one order with the key it got when it was first sent. Returns
  // null to go on with the next order, or the reason the sync stops here.
  Future<SyncState?> _send(QueuedOrder order) async {
    final queue = ref.read(orderQueueProvider.notifier);
    try {
      final result = await ref.read(apiClientProvider).createOrder(order.items, idempotencyKey: order.idempotencyKey);
      queue.markSent(order, result);
      return null;
    } on ApiUnreachable {
      return const SyncState(pause: SyncPause.notSent);
    } on ApiProblem catch (problem) {
      switch (problem.status) {
        case 400 || 409:
          queue.markRejected(order, problem.detail);
          return null;
        case 429:
          final wait = problem.retryAfter;
          return SyncState(pause: SyncPause.rateLimited, resumeAt: wait == null ? null : DateTime.now().add(wait));
        case 401:
          return const SyncState(pause: SyncPause.signInNeeded);
        default:
          return const SyncState(pause: SyncPause.notSent);
      }
    }
  }

  bool _hasWaiting() => ref.read(orderQueueProvider).any((order) => order.status == QueuedOrderStatus.waiting);
}

final queueSyncProvider = NotifierProvider<QueueSync, SyncState>(QueueSync.new);
