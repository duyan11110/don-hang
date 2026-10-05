// The fake payment gateway of the lab, reached as fake-gateway:8080 by
// DonHang.Payments only. It answers the way refund-design.md assumes the
// real one does: at once, in the answer to the refund call, and once per
// Idempotency-Key. It speaks its own language (refundId, reason, 422), which
// GatewayRefundClient translates; nothing else in Đơn Hàng sees it.
var builder = WebApplication.CreateBuilder(args);
var apiKey = builder.Configuration["Gateway:ApiKey"]
    ?? throw new InvalidOperationException("Gateway:ApiKey is not set");
var app = builder.Build();

// The payments this gateway took, by order: the card and bank transfer
// payments of db/seed.sql. Cash on delivery never went through a gateway.
var paymentMethods = new Dictionary<int, string>
{
    [1] = "card", [2] = "card", [3] = "bank_transfer", [7] = "card",
    [8] = "bank_transfer", [10] = "card",
};

// Every answer given, by Idempotency-Key, and every refund made. One lock
// around both: two calls with the same key never both refund.
var answers = new Dictionary<string, IResult>();
var refunds = new List<Refund>();

app.MapPost("/v1/refunds", (HttpRequest request, RefundRequest body) =>
{
    if (request.Headers.Authorization != $"Bearer {apiKey}")
        return Results.Json(new { reason = "unknown api key" }, statusCode: StatusCodes.Status401Unauthorized);

    var key = request.Headers["Idempotency-Key"].ToString();
    if (key.Length == 0)
        return Results.Json(new { reason = "Idempotency-Key is required" }, statusCode: StatusCodes.Status400BadRequest);

    // A key seen before gets the answer it got then, and nothing is refunded again.
    lock (answers)
    {
        if (!answers.TryGetValue(key, out var answer))
        {
            answer = Decide(key, body);
            answers[key] = answer;
        }
        return answer;
    }
});

// What the gateway has refunded, for the lab's scripts to compare with
// donhang_payments: one line per refund, never two for one key.
app.MapGet("/v1/refunds", () =>
{
    lock (answers) return refunds.ToArray();
});

app.MapGet("/health", () => "ok");

app.Run();

IResult Decide(string key, RefundRequest body)
{
    if (!paymentMethods.TryGetValue(body.OrderId, out var method))
        return Results.UnprocessableEntity(new { reason = $"no payment for order {body.OrderId} went through this gateway" });
    if (method == "bank_transfer")
        return Results.UnprocessableEntity(new { reason = "a bank transfer cannot be refunded through the card gateway" });

    var refund = new Refund($"rf-{refunds.Count + 1}", body.OrderId, body.AmountVnd, key);
    refunds.Add(refund);
    app.Logger.LogInformation("Refunded {AmountVnd} for order {OrderId} ({Key})", body.AmountVnd, body.OrderId, key);
    return Results.Ok(new { refundId = refund.RefundId, status = "refunded" });
}

record RefundRequest(int OrderId, int AmountVnd);

record Refund(string RefundId, int OrderId, int AmountVnd, string IdempotencyKey);
