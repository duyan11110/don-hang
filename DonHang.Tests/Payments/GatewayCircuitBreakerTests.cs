using System.Net;
using System.Net.Http.Json;
using DonHang.Payments;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace DonHang.Tests.Payments;

// lesson: backend.l3.circuit-breaker
// GatewayRefundClient with the same pipeline Payments' Program.cs builds
// (GatewayPipeline.AddGatewayRefundClient), but in front of a fake handler
// instead of the network: the handler answers what each test needs and
// counts the calls that really reached it.
public sealed class GatewayCircuitBreakerTests
{
    private static readonly GatewaySettings Settings = new()
    {
        BaseAddress = "http://gateway.test/",
        Timeout = TimeSpan.FromSeconds(1),
        FailureRatio = 0.5,
        MinimumThroughput = 3,
        SamplingDuration = TimeSpan.FromSeconds(30),
        BreakDuration = TimeSpan.FromSeconds(1),
    };

    private sealed class FakeGateway(Func<HttpResponseMessage> answer, TimeSpan? delay = null) : HttpMessageHandler
    {
        public int Calls;

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Interlocked.Increment(ref Calls);
            if (delay is { } wait) await Task.Delay(wait, cancellationToken);
            return answer();
        }
    }

    private static GatewayRefundClient ClientFor(FakeGateway gateway)
    {
        var services = new ServiceCollection().AddLogging();
        services.AddGatewayRefundClient(Settings).ConfigurePrimaryHttpMessageHandler(() => gateway);
        return services.BuildServiceProvider().GetRequiredService<GatewayRefundClient>();
    }

    private static Payment Refund() => new()
    {
        Id = 9, OrderId = 1, Kind = "refund", Status = "pending", AmountVnd = 2_150_000, Method = "card",
        RequestedBy = "anh.tran@example.com", RequestedAt = DateTimeOffset.UtcNow, NextAttemptAt = DateTimeOffset.UtcNow,
    };

    // lesson: backend.l3.resilience-pipeline
    // A gateway that takes 5 s: the pipeline's timeout (1 s here) ends the
    // call, and GatewayRefundClient reports it as try again later.
    [Fact]
    public async Task ASlowGateway_IsEndedByTheTimeout()
    {
        var gateway = new FakeGateway(() => new HttpResponseMessage(HttpStatusCode.OK), delay: TimeSpan.FromSeconds(5));
        var client = ClientFor(gateway);

        var started = DateTimeOffset.UtcNow;
        var result = await client.RefundAsync(Refund(), default);

        Assert.Equal((RefundOutcome.TryAgainLater, "the gateway did not answer in time"), (result.Outcome, result.Reason));
        Assert.True(DateTimeOffset.UtcNow - started < TimeSpan.FromSeconds(4));
    }

    // Three 500s in a row: the third makes 3 calls, all failed, so the circuit
    // opens. The fourth call fails at once and never reaches the gateway.
    [Fact]
    public async Task ThreeFailedCalls_OpenTheCircuit_AndTheNextCallIsNotSent()
    {
        var gateway = new FakeGateway(() => new HttpResponseMessage(HttpStatusCode.InternalServerError));
        var client = ClientFor(gateway);

        for (var i = 0; i < 3; i++)
            Assert.Equal(RefundOutcome.TryAgainLater, (await client.RefundAsync(Refund(), default)).Outcome);
        var refused = await client.RefundAsync(Refund(), default);

        Assert.Equal(RefundOutcome.TryAgainLater, refused.Outcome);
        Assert.Contains("circuit", refused.Reason);
        Assert.Equal(3, gateway.Calls);
    }

    // The gateway refusing a refund (422) is a normal answer: however many
    // refusals come back, every call is still sent.
    [Fact]
    public async Task Refusals_DoNotOpenTheCircuit()
    {
        var gateway = new FakeGateway(() => new HttpResponseMessage(HttpStatusCode.UnprocessableEntity)
        {
            Content = JsonContent.Create(new { reason = "a bank transfer cannot be refunded" }),
        });
        var client = ClientFor(gateway);

        for (var i = 0; i < 5; i++)
            Assert.Equal(RefundOutcome.Refused, (await client.RefundAsync(Refund(), default)).Outcome);

        Assert.Equal(5, gateway.Calls);
    }

    // After BreakDuration the circuit is half-open: one trial call is sent,
    // and when it succeeds the circuit closes and calls go through again.
    [Fact]
    public async Task AfterTheBreak_ASuccessfulTrialCall_ClosesTheCircuit()
    {
        var failing = true;
        var gateway = new FakeGateway(() => failing
            ? new HttpResponseMessage(HttpStatusCode.ServiceUnavailable)
            : new HttpResponseMessage(HttpStatusCode.OK) { Content = JsonContent.Create(new { status = "refunded" }) });
        var client = ClientFor(gateway);
        for (var i = 0; i < 3; i++) await client.RefundAsync(Refund(), default);

        failing = false;
        await Task.Delay(Settings.BreakDuration + TimeSpan.FromMilliseconds(200));
        var trial = await client.RefundAsync(Refund(), default);
        var next = await client.RefundAsync(Refund(), default);

        Assert.Equal((RefundOutcome.Refunded, RefundOutcome.Refunded), (trial.Outcome, next.Outcome));
        Assert.Equal(5, gateway.Calls);
    }
}
