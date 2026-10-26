using System.Text.Json;
using Xunit;
using NotificationsCopy = DonHang.Notifications.OrderMessage;
using PaymentsCopy = DonHang.Payments.OrderMessage;
using Sent = DonHang.Domain.OrderMessage;

namespace DonHang.Tests.Messaging;

// lesson: backend.l4.message-schema-evolution
// The api publishes DonHang.Domain.OrderMessage; Notifications and Payments
// each read their own copy of the shape. This test serialises what the api
// sends, the way EfOutbox does, and reads it with both copies: renaming or
// retyping a property on either side fails here, in the pull request that
// makes the change, not in a dead-letter queue after the deploy.
public sealed class OrderMessageContractTests
{
    private static readonly Sent Message =
        new(7, "anh.tran@example.com", "Trần Minh Anh", new DateTimeOffset(2026, 10, 6, 8, 0, 0, TimeSpan.Zero));

    private static readonly string Body = JsonSerializer.Serialize(Message, JsonSerializerOptions.Web);

    [Fact]
    public void Notifications_ReadsEveryValueTheApiSends()
    {
        var read = JsonSerializer.Deserialize<NotificationsCopy>(Body, JsonSerializerOptions.Web)!;

        Assert.Equal((Message.OrderId, Message.CustomerEmail, Message.CustomerName, Message.OccurredAt),
            (read.OrderId, read.CustomerEmail, read.CustomerName, read.OccurredAt));
    }

    [Fact]
    public void Payments_ReadsEveryValueTheApiSends()
    {
        var read = JsonSerializer.Deserialize<PaymentsCopy>(Body, JsonSerializerOptions.Web)!;

        Assert.Equal((Message.OrderId, Message.CustomerEmail, Message.CustomerName, Message.OccurredAt),
            (read.OrderId, read.CustomerEmail, read.CustomerName, read.OccurredAt));
    }

    // A message written before a property existed may still wait in a queue
    // after the deploy. Without `customerName` both copies still read it,
    // with that property left null; the readers require only the order id
    // and the email address.
    [Fact]
    public void BothCopies_ReadAnOlderMessageWithoutCustomerName()
    {
        const string older = """{"orderId":7,"customerEmail":"anh.tran@example.com","occurredAt":"2026-10-06T08:00:00+00:00"}""";

        var notifications = JsonSerializer.Deserialize<NotificationsCopy>(older, JsonSerializerOptions.Web)!;
        var payments = JsonSerializer.Deserialize<PaymentsCopy>(older, JsonSerializerOptions.Web)!;

        Assert.Equal((7, "anh.tran@example.com", (string?)null), (notifications.OrderId, notifications.CustomerEmail, notifications.CustomerName));
        Assert.Equal((7, "anh.tran@example.com", (string?)null), (payments.OrderId, payments.CustomerEmail, payments.CustomerName));
    }
}
