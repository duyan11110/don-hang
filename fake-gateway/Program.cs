// The fake payment gateway of the lab, reached as fake-gateway:8080 by
// DonHang.Payments only. It answers the way refund-design.md assumes the
// real one does: at once, in the answer to the refund call, and once per
// Idempotency-Key. It speaks its own language (refundId, reason, 422), which
// GatewayRefundClient translates; nothing else in Đơn Hàng sees it.
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);
var apiKey = builder.Configuration["Gateway:ApiKey"]
    ?? throw new InvalidOperationException("Gateway:ApiKey is not set");

// lesson: backend.l3.trace-context-propagation
// A real gateway would not send its spans to Đơn Hàng; this one does, so the
// lab can show that ASP.NET Core instrumentation reads the traceparent header
// Payments' HttpClient wrote: the gateway's span joins the refund's trace.
var sampleRatio = builder.Configuration.GetValue("Telemetry:SampleRatio", 0.1);
builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource.AddService("fake-gateway"))
    .WithTracing(tracing => tracing
        .SetSampler(new ParentBasedSampler(new TraceIdRatioBasedSampler(sampleRatio)))
        .AddAspNetCoreInstrumentation(options => options.Filter = context =>
            !context.Request.Path.StartsWithSegments("/health"))
        .AddOtlpExporter());

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

// lesson: backend.l3.resilience-pipeline
// A switch for the lab's scripts, not part of any real gateway:
//   PUT /lab/delay?seconds=15   every refund call waits 15 s, then is handled
//   PUT /lab/delay?seconds=0    back to answering at once
// The call is handled after the wait even if the caller has stopped waiting:
// a timeout in Payments ends Payments' wait, not the gateway's work.
var delay = TimeSpan.Zero;
app.MapPut("/lab/delay", (int seconds) =>
{
    delay = TimeSpan.FromSeconds(seconds);
    app.Logger.LogInformation("Refund calls now wait {Seconds} s before an answer", seconds);
    return Results.Ok(new { delaySeconds = seconds });
});

app.MapPost("/v1/refunds", async (HttpRequest request, RefundRequest body) =>
{
    if (request.Headers.Authorization != $"Bearer {apiKey}")
        return Results.Json(new { reason = "unknown api key" }, statusCode: StatusCodes.Status401Unauthorized);

    var key = request.Headers["Idempotency-Key"].ToString();
    if (key.Length == 0)
        return Results.Json(new { reason = "Idempotency-Key is required" }, statusCode: StatusCodes.Status400BadRequest);

    if (delay > TimeSpan.Zero) await Task.Delay(delay);

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
