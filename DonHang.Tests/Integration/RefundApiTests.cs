using System.Net;
using System.Net.Http.Json;
using DonHang.Api;
using DonHang.Domain;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace DonHang.Tests.Integration;

// lesson: backend.l3.saga-in-progress-status
// POST /api/v1/orders/{id}/refund through the whole api: the 202, the order
// left `refunding`, its order.refund-requested outbox row, and the 409s that
// keep a second refund, or a ship, away while it is in progress.
public sealed class RefundApiTests(ApiFactory factory) : IClassFixture<ApiFactory>, IAsyncLifetime
{
    public Task InitializeAsync() => factory.Database.ResetAsync();

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task PostRefund_PaidOrder_Returns202RefundingWithItsMessage()
    {
        var orderId = await PaidOrderForAsync("customer-an");

        var response = await ClientFor("customer-an", "customer").PostAsync($"/api/v1/orders/{orderId}/refund", null);

        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
        Assert.Equal("refunding", (await response.Content.ReadFromJsonAsync<OrderDto>())!.Status);
        await using var db = factory.Database.CreateContext();
        var routingKeys = await db.OutboxMessages.OrderBy(m => m.CreatedAt).Select(m => m.RoutingKey).ToListAsync();
        Assert.Equal(["order.placed", "order.refund-requested"], routingKeys);
    }

    [Fact]
    public async Task PostRefund_Twice_SecondReturns409()
    {
        var orderId = await PaidOrderForAsync("customer-an");
        var client = ClientFor("customer-an", "customer");
        await client.PostAsync($"/api/v1/orders/{orderId}/refund", null);

        var second = await client.PostAsync($"/api/v1/orders/{orderId}/refund", null);

        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
        Assert.Equal("https://donhang.local/problems/refund-in-progress", (await second.Content.ReadFromJsonAsync<Problem>())!.Type);
    }

    [Fact]
    public async Task ShipOrder_Refunding_Returns409()
    {
        var orderId = await PaidOrderForAsync("customer-an");
        await ClientFor("customer-an", "customer").PostAsync($"/api/v1/orders/{orderId}/refund", null);

        var response = await ClientFor("staff-lan", "staff").PatchAsync($"/api/v1/orders/{orderId}/ship", null);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task PostRefund_AnotherCustomersOrder_Returns403()
    {
        var orderId = await PaidOrderForAsync("customer-an");
        await InsertCustomerAsync("customer-binh");

        var response = await ClientFor("customer-binh", "customer").PostAsync($"/api/v1/orders/{orderId}/refund", null);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    private HttpClient ClientFor(string subject, string roles)
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-Subject", subject);
        client.DefaultRequestHeaders.Add("X-Test-Roles", roles);
        return client;
    }

    private async Task InsertCustomerAsync(string subject)
    {
        await using var db = factory.Database.CreateContext();
        db.Customers.Add(new Customer
        {
            FullName = subject, Email = $"{subject}@example.com", City = "Hà Nội", IdentitySubject = subject,
        });
        await db.SaveChangesAsync();
    }

    // An order placed through the api, then marked paid with SQL: no
    // endpoint takes payments, as in the lab, where the seed's orders are paid.
    private async Task<int> PaidOrderForAsync(string subject)
    {
        await InsertCustomerAsync(subject);
        int productId;
        await using (var db = factory.Database.CreateContext())
        {
            productId = await TestProducts.InsertAsync(db, "Pen", 15_000);
        }

        var response = await ClientFor(subject, "customer").PostAsJsonAsync("/api/v1/orders",
            new CreateOrderRequest([new CreateOrderItemRequest(productId, Quantity: 1, UnitPriceVnd: 15_000)]));
        var order = await response.Content.ReadFromJsonAsync<OrderDto>();
        await using (var db = factory.Database.CreateContext())
        {
            await db.Database.ExecuteSqlAsync($"UPDATE orders SET status = 'paid' WHERE id = {order!.Id}");
        }
        return order.Id;
    }

    private sealed record Problem(string? Type);
}
