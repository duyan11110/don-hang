using System.Net;
using System.Net.Http.Json;
using DonHang.Api;
using DonHang.Domain;
using Xunit;

namespace DonHang.Tests.Integration;

// lesson: design.l3.read-model
// The read model end to end: each change made through the api adds its row
// to order_status_history in the same save, and GET .../history reads them.
public sealed class OrderHistoryTests(ApiFactory factory) : IClassFixture<ApiFactory>, IAsyncLifetime
{
    public Task InitializeAsync() => factory.Database.ResetAsync();

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task PlacedThenCancelled_HistoryHasBothChangesInOrder()
    {
        var customer = await SignedInCustomerAsync("customer-an");
        var orderId = await PlaceOrderAsync(customer);
        (await customer.PatchAsync($"/api/v1/orders/{orderId}/cancel", null)).EnsureSuccessStatusCode();

        var history = await customer.GetFromJsonAsync<List<OrderStatusChangeDto>>($"/api/v1/orders/{orderId}/history");

        Assert.Equal(
            [("placed", "new"), ("cancelled", "cancelled")],
            history!.Select(change => (change.Event, change.Status)).ToList());
    }

    // A refused change records no event, so it adds no row either.
    [Fact]
    public async Task RefusedShip_AddsNoRow()
    {
        var customer = await SignedInCustomerAsync("customer-an");
        var orderId = await PlaceOrderAsync(customer);
        var staff = Client("staff-lan", "staff");

        var ship = await staff.PatchAsync($"/api/v1/orders/{orderId}/ship", null);
        var history = await staff.GetFromJsonAsync<List<OrderStatusChangeDto>>($"/api/v1/orders/{orderId}/history");

        Assert.Equal(HttpStatusCode.Conflict, ship.StatusCode);
        Assert.Equal("placed", Assert.Single(history!).Event);
    }

    // The same OrderOwner rule as GET /api/v1/orders/{id}.
    [Fact]
    public async Task AnotherCustomer_Gets403()
    {
        var owner = await SignedInCustomerAsync("customer-an");
        var other = await SignedInCustomerAsync("customer-binh");
        var orderId = await PlaceOrderAsync(owner);

        var response = await other.GetAsync($"/api/v1/orders/{orderId}/history");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    private HttpClient Client(string subject, string roles)
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-Subject", subject);
        client.DefaultRequestHeaders.Add("X-Test-Roles", roles);
        return client;
    }

    private async Task<HttpClient> SignedInCustomerAsync(string subject)
    {
        await using var db = factory.Database.CreateContext();
        db.Customers.Add(new Customer
        {
            FullName = subject, Email = $"{subject}@example.com", City = "Hà Nội", IdentitySubject = subject,
        });
        await db.SaveChangesAsync();
        return Client(subject, "customer");
    }

    private async Task<int> PlaceOrderAsync(HttpClient customer)
    {
        int productId;
        await using (var db = factory.Database.CreateContext())
        {
            productId = await TestProducts.InsertAsync(db, "Pen", 15_000);
        }

        var response = await customer.PostAsJsonAsync("/api/v1/orders",
            new CreateOrderRequest([new CreateOrderItemRequest(productId, Quantity: 1, UnitPriceVnd: 15_000)]));
        response.EnsureSuccessStatusCode();
        var order = await response.Content.ReadFromJsonAsync<OrderDto>();
        return order!.Id;
    }
}
