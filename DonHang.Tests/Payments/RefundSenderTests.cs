using DonHang.Payments;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace DonHang.Tests.Payments;

// lesson: backend.l3.safe-to-repeat-saga-steps
// What RefundSender records for each of the gateway's three outcomes, with
// refund-design.md's waits. No database, no gateway: RecordResult only
// changes the row it is given and returns the message to save with it.
public sealed class RefundSenderTests
{
    private static readonly DateTimeOffset RequestedAt = new(2026, 10, 6, 8, 0, 0, TimeSpan.Zero);

    private static RefundSender NewSender() => new(
        new ServiceCollection().BuildServiceProvider().GetRequiredService<IServiceScopeFactory>(),
        new RefundSettings(), NullLogger<RefundSender>.Instance);

    private static Payment PendingRefund() => new()
    {
        Id = 9, OrderId = 1, Kind = "refund", Status = "pending", AmountVnd = 2_150_000, Method = "card",
        RequestedBy = "anh.tran@example.com", RequestedAt = RequestedAt, NextAttemptAt = RequestedAt,
    };

    [Fact]
    public void RecordResult_Refunded_MarksRefundedAndAnnouncesIt()
    {
        var refund = PendingRefund();

        var message = NewSender().RecordResult(refund, new(RefundOutcome.Refunded), RequestedAt.AddMinutes(1));

        Assert.Equal("refunded", refund.Status);
        Assert.Equal(RequestedAt.AddMinutes(1), refund.PaidAt);
        Assert.Equal("payment.refunded", message?.RoutingKey);
    }

    // lesson: backend.l3.compensating-action
    [Fact]
    public void RecordResult_Refused_MarksFailedWithTheReasonAndAnnouncesIt()
    {
        var refund = PendingRefund();

        var message = NewSender().RecordResult(refund, new(RefundOutcome.Refused, "card expired"), RequestedAt);

        Assert.Equal(("failed", "card expired"), (refund.Status, refund.FailureReason));
        Assert.Equal("payment.refund-failed", message?.RoutingKey);
        Assert.Contains("card expired", message!.Body);
    }

    // lesson: backend.l3.safe-to-repeat-saga-steps
    // An error or no answer: still pending, one more attempt counted, the
    // next one within 1 minute (jitter picks the moment), nothing announced yet.
    [Fact]
    public void RecordResult_TryAgainLater_StaysPendingAndWaits()
    {
        var refund = PendingRefund();
        var now = RequestedAt.AddSeconds(5);

        var message = NewSender().RecordResult(refund, new(RefundOutcome.TryAgainLater, "timeout"), now);

        Assert.Null(message);
        Assert.Equal(("pending", 1), (refund.Status, refund.Attempts));
        Assert.InRange(refund.NextAttemptAt!.Value, now.AddSeconds(30), now.AddMinutes(1));
    }

    [Fact]
    public void RecordResult_TryAgainLaterAfter24Hours_GivesUp()
    {
        var refund = PendingRefund();

        var message = NewSender().RecordResult(refund, new(RefundOutcome.TryAgainLater, "timeout"), RequestedAt.AddHours(24));

        Assert.Equal("failed", refund.Status);
        Assert.Equal("payment.refund-failed", message?.RoutingKey);
    }

    [Theory]
    [InlineData(1, 1)]
    [InlineData(2, 2)]
    [InlineData(4, 8)]
    [InlineData(7, 60)]
    [InlineData(20, 60)]
    public void BackoffDelay_DoublesUpToOneHour(int attempts, int expectedMinutes)
    {
        Assert.Equal(TimeSpan.FromMinutes(expectedMinutes), NewSender().BackoffDelay(attempts));
    }

    // lesson: backend.l3.retry-jitter
    // A random wait has no one right value to compare with, so the test asks
    // many times and checks that every answer falls inside the range: from
    // half the backoff delay up to the whole of it. And that the answers do
    // differ, or the jitter would spread nothing.
    [Theory]
    [InlineData(1, 1)]
    [InlineData(3, 4)]
    [InlineData(20, 60)]
    public void NextDelay_IsBetweenHalfAndAllOfTheBackoff(int attempts, int backoffMinutes)
    {
        var sender = NewSender();
        var backoff = TimeSpan.FromMinutes(backoffMinutes);

        var delays = Enumerable.Range(0, 1000).Select(_ => sender.NextDelay(attempts)).ToList();

        Assert.All(delays, delay => Assert.InRange(delay, backoff / 2, backoff));
        Assert.True(delays.Distinct().Count() > 1);
    }

    // Every call for one row sends the same key, whichever attempt it is.
    [Fact]
    public void IdempotencyKeyFor_IsRefundAndTheRowId()
    {
        var refund = PendingRefund();
        var first = GatewayRefundClient.IdempotencyKeyFor(refund);
        refund.Attempts = 3;

        Assert.Equal("refund-9", first);
        Assert.Equal(first, GatewayRefundClient.IdempotencyKeyFor(refund));
    }
}
