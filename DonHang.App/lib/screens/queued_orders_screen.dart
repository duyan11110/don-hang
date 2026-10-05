import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../auth/token_subject.dart';
import '../design/components/message_view.dart';
import '../design/components/status_banner.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../offline/order_queue.dart';
import '../offline/queue_sync.dart';

// lesson: frontend.l3.offline-order-queue
// The orders this customer placed that the API has not answered yet, and
// the answers they have not seen yet. A waiting order has no number: only
// the API gives one. "Send now" starts a sync at once.
class QueuedOrdersScreen extends ConsumerWidget {
  const QueuedOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final token = ref.watch(authProvider);
    final subject = token == null ? null : tokenSubject(token);
    final orders = [for (final order in ref.watch(orderQueueProvider)) if (order.subject == subject) order];
    final sync = ref.watch(queueSyncProvider);
    final syncMessage = _syncMessage(context, sync);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.queuedOrdersTitle)),
      body: orders.isEmpty
          ? MessageView(message: l10n.queueEmpty)
          : ListView(
              padding: Insets.screen,
              children: [
                ?syncMessage,
                for (final order in orders)
                  Padding(padding: const EdgeInsets.only(top: Space.sm), child: _entry(context, ref, order)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: sync.sending ? null : () => ref.read(queueSyncProvider.notifier).sendNow(),
        icon: const Icon(Icons.send),
        label: Text(l10n.sendNow),
      ),
    );
  }

  // Why the last sync stopped, when it did.
  Widget? _syncMessage(BuildContext context, SyncState sync) {
    final l10n = AppLocalizations.of(context);
    final resumeAt = sync.resumeAt;
    return switch (sync.pause) {
      SyncPause.none => null,
      SyncPause.notSent => StatusBanner(message: l10n.syncNotSent, tone: StatusTone.info),
      SyncPause.rateLimited => StatusBanner(
          message: resumeAt == null ? l10n.syncRateLimited : l10n.syncRateLimitedUntil(resumeAt),
          tone: StatusTone.warning,
        ),
      SyncPause.signInNeeded => StatusBanner(
          message: l10n.syncSignInNeeded,
          tone: StatusTone.warning,
          actionLabel: l10n.signIn,
          onAction: () => context.go('/login'),
        ),
    };
  }

  // lesson: frontend.l3.sync-conflicts
  // lesson: frontend.l3.component-library
  // One banner per order, in the tone of what happened to it. A rejected
  // order stays, with the API's detail, until the customer removes it.
  Widget _entry(BuildContext context, WidgetRef ref, QueuedOrder order) {
    final l10n = AppLocalizations.of(context);
    final queue = ref.read(orderQueueProvider.notifier);
    final result = order.result;
    return switch (order.status) {
      QueuedOrderStatus.waiting => StatusBanner(message: l10n.queuedWaiting(order.description), tone: StatusTone.info),
      QueuedOrderStatus.rejected => StatusBanner(
          message: l10n.queuedRejected(order.description, order.problem ?? ''),
          tone: StatusTone.error,
          actionLabel: l10n.remove,
          onAction: () => queue.remove(order.idempotencyKey),
        ),
      QueuedOrderStatus.sent => StatusBanner(
          message: order.priceChanged
              ? l10n.queuedPriceChanged(result!.id, totalVnd(order.items), totalVnd(result.items))
              : l10n.queuedSent(result!.id, order.description),
          tone: order.priceChanged ? StatusTone.warning : StatusTone.success,
          actionLabel: l10n.openOrder,
          onAction: () => _open(context, queue, order),
        ),
    };
  }

  // A sent order now lives on the server: it leaves the queue and its own
  // screen opens.
  void _open(BuildContext context, OrderQueue queue, QueuedOrder order) {
    queue.remove(order.idempotencyKey);
    context.go('/orders/${order.result!.id}');
  }
}
