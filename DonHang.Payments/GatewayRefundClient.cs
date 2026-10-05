using System.Net;

namespace DonHang.Payments;

// The three outcomes of asking the gateway for a refund, in Đơn Hàng's own
// words. Reason is the gateway's text for a refusal, or what went wrong.
public enum RefundOutcome
{
    Refunded,
    Refused,
    TryAgainLater,
}

public sealed record GatewayRefundResult(RefundOutcome Outcome, string? Reason = null);

// Where the payment gateway is and the key it gives Đơn Hàng. Only this
// service has them: Program.cs reads "Gateway" (fake-gateway in the lab).
public sealed class GatewaySettings
{
    public string BaseAddress { get; set; } = "http://localhost:8090/";
    public string ApiKey { get; set; } = "";
}

// lesson: backend.l3.safe-to-repeat-saga-steps
// The anti-corruption layer between Đơn Hàng and the payment gateway: the
// only class that knows the gateway's URL, headers, status codes and JSON.
// Whatever the gateway answers comes out as one of three outcomes; nothing
// else in Đơn Hàng ever sees a gateway response.
public sealed class GatewayRefundClient(HttpClient http)
{
    // lesson: backend.l3.safe-to-repeat-saga-steps
    // The same key on every call for one refund row, so the gateway refunds
    // once however many times a timeout makes RefundSender ask again.
    public static string IdempotencyKeyFor(Payment refund) => $"refund-{refund.Id}";

    // 200: refunded. 422: the gateway refuses this refund for good, and says
    // why. Anything else, an error status, a broken connection or no answer
    // in time, may succeed on a later try.
    public async Task<GatewayRefundResult> RefundAsync(Payment refund, CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "v1/refunds")
        {
            Content = JsonContent.Create(new { orderId = refund.OrderId, amountVnd = refund.AmountVnd }),
        };
        request.Headers.Add("Idempotency-Key", IdempotencyKeyFor(refund));
        try
        {
            using var response = await http.SendAsync(request, cancellationToken);
            if (response.IsSuccessStatusCode) return new(RefundOutcome.Refunded);
            if (response.StatusCode == HttpStatusCode.UnprocessableEntity)
                return new(RefundOutcome.Refused, await ReadReasonAsync(response, cancellationToken));
            return new(RefundOutcome.TryAgainLater, $"the gateway answered {(int)response.StatusCode}");
        }
        catch (HttpRequestException ex)
        {
            return new(RefundOutcome.TryAgainLater, ex.Message);
        }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return new(RefundOutcome.TryAgainLater, "the gateway did not answer in time");
        }
    }

    private sealed record GatewayError(string? Reason);

    private static async Task<string> ReadReasonAsync(HttpResponseMessage response, CancellationToken cancellationToken)
    {
        var error = await response.Content.ReadFromJsonAsync<GatewayError>(cancellationToken);
        return error?.Reason ?? "the gateway gave no reason";
    }
}
