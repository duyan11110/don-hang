using Prometheus;

namespace DonHang.Api.Monitoring;

// lesson: devops.l2.counters-and-rate
// Đơn Hàng's own metric, next to the http_* ones prometheus-net provides.
// A counter only goes up (and starts again from 0 when the api restarts);
// /metrics shows its current value as donhang_orders_placed_total.
public static class OrderMetrics
{
    public static readonly Counter OrdersPlaced = Metrics.CreateCounter(
        "donhang_orders_placed_total",
        "Orders created through POST /api/v1/orders or /api/v2/orders; a repeated Idempotency-Key does not count.");
}
