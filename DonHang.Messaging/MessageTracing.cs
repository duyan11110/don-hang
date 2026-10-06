using System.Diagnostics;
using System.Text;
using RabbitMQ.Client;

namespace DonHang.Messaging;

// lesson: backend.l3.tracing-through-the-outbox
// Carries a trace from the code that saved an outbox row, through RabbitMQ,
// to the consumer that handles the message. The spans come from Đơn Hàng's
// own ActivitySource, which each service's Program.cs tells OpenTelemetry to
// record. RabbitMQ.Client has spans of its own ("RabbitMQ.Client.*"); no
// service records them, so the library starts none and writes no traceparent
// header over the one set here.
public static class MessageTracing
{
    public const string SourceName = "DonHang.Messaging";
    public const string TraceParentHeader = "traceparent";
    private static readonly ActivitySource Source = new(SourceName);

    // The W3C traceparent of the span current right now, or null outside any
    // span: "00-<32 hex trace id>-<16 hex span id>-<flags>".
    public static string? CurrentTraceParent() =>
        Activity.Current is { IdFormat: ActivityIdFormat.W3C } current ? current.Id : null;

    // lesson: backend.l3.tracing-through-the-outbox
    // The relay's span for one message: a child of the context saved in the
    // row, not of the relay's own work. A row saved before trace_parent existed
    // has none, and its message starts a new trace instead.
    public static Activity? StartPublish(OutboxMessage message, string exchange)
    {
        var activity = StartChildOf(message.TraceParent, $"publish {message.RoutingKey}", ActivityKind.Producer);
        activity?.SetTag("messaging.system", "rabbitmq");
        activity?.SetTag("messaging.destination.name", exchange);
        activity?.SetTag("messaging.message.id", message.Id.ToString());
        return activity;
    }

    // lesson: backend.l3.tracing-through-the-outbox
    // A consumer's span for one delivery: a child of the publish span that
    // the message's traceparent header names.
    public static Activity? StartConsume(IReadOnlyBasicProperties properties, string queue)
    {
        var activity = StartChildOf(Read(properties), $"process {queue}", ActivityKind.Consumer);
        activity?.SetTag("messaging.system", "rabbitmq");
        activity?.SetTag("messaging.message.id", properties.MessageId);
        return activity;
    }

    // A span that continues a trace saved earlier as a traceparent string,
    // such as a refund row's; with nothing saved, the span starts a new trace.
    public static Activity? StartChildOf(string? traceParent, string name, ActivityKind kind = ActivityKind.Internal)
    {
        var parent = traceParent is not null && ActivityContext.TryParse(traceParent, null, isRemote: true, out var saved)
            ? saved
            : default;
        return Source.StartActivity(name, kind, parent);
    }

    // RabbitMQ hands header values back as bytes.
    private static string? Read(IReadOnlyBasicProperties properties) =>
        properties.Headers?.TryGetValue(TraceParentHeader, out var value) == true
            ? value switch { byte[] bytes => Encoding.UTF8.GetString(bytes), string text => text, _ => null }
            : null;
}
