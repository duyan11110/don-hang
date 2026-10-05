using System.Net;
using System.Net.Http.Json;
using DonHang.Api;
using DonHang.Domain;
using Xunit;

namespace DonHang.Tests.Integration;

// lesson: design.l2.webapplicationfactory
// Each test talks to the api the way a client does: an HTTP request in, a
// status code, headers and JSON out, through the real middleware, routing,
// controllers, authorization, PostgreSQL and Redis.
public sealed class OrdersApiTests(ApiFactory factory) : IClassFixture<ApiFactory>, IAsyncLifetime
{
    public Task InitializeAsync() => factory.Database.ResetAsync();

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task PostOrder_SignedInCustomer_Returns201WithLocation()
    {
        await InsertCustomerAsync("customer-an");
        var productId = await InsertProductAsync();

        var response = await PlaceOrderAsync(ClientFor("customer-an", "customer"), productId);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var order = await response.Content.ReadFromJsonAsync<OrderDto>();
        Assert.Equal($"/api/v1/orders/{order!.Id}", response.Headers.Location!.AbsolutePath);
    }

    // lesson: design.l2.testing-protected-endpoints
    // No X-Test-Subject header: TestAuthHandler gives no identity, so the
    // request is refused before the controller runs, as without a token.
    [Fact]
    public async Task PostOrder_NoCaller_Returns401()
    {
        var productId = await InsertProductAsync();

        var response = await PlaceOrderAsync(factory.CreateClient(), productId);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    // lesson: design.l2.testing-protected-endpoints
    // OrderOwnerHandler runs for real: customer-binh is a customer, but not this order's.
    [Fact]
    public async Task GetOrder_AnotherCustomersOrder_Returns403()
    {
        await InsertCustomerAsync("customer-an");
        await InsertCustomerAsync("customer-binh");
        var orderId = await PlaceOrderForAsync("customer-an");

        var response = await ClientFor("customer-binh", "customer").GetAsync($"/api/v1/orders/{orderId}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    // lesson: design.l2.testing-protected-endpoints
    // The StaffOnly policy runs for real: a customer may not ship, even their own order.
    [Fact]
    public async Task ShipOrder_Customer_Returns403()
    {
        await InsertCustomerAsync("customer-an");
        var orderId = await PlaceOrderForAsync("customer-an");

        var response = await ClientFor("customer-an", "customer").PatchAsync($"/api/v1/orders/{orderId}/ship", null);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    // lesson: design.l2.test-pyramid
    // OrderTests checks the status rules on Order itself; this checks once
    // that a refusal reaches the client as 409 with its problem `type`.
    [Fact]
    public async Task ShipOrder_StaffAndNewOrder_Returns409NotPaid()
    {
        await InsertCustomerAsync("customer-an");
        var orderId = await PlaceOrderForAsync("customer-an");

        var response = await ClientFor("staff-lan", "staff").PatchAsync($"/api/v1/orders/{orderId}/ship", null);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var problem = await response.Content.ReadFromJsonAsync<Problem>();
        Assert.Equal("https://donhang.local/problems/not-paid", problem!.Type);
    }

    // lesson: design.l3.one-way-module-dependencies
    // The client still sends unitPriceVnd; the api answers with Catalog's price.
    [Fact]
    public async Task PostOrder_PriceFromClient_IsIgnored()
    {
        await InsertCustomerAsync("customer-an");
        var productId = await InsertProductAsync(); // costs 15 000 đ

        var response = await ClientFor("customer-an", "customer").PostAsJsonAsync("/api/v1/orders",
            new CreateOrderRequest([new CreateOrderItemRequest(productId, Quantity: 1, UnitPriceVnd: 1)]));

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var order = await response.Content.ReadFromJsonAsync<OrderDto>();
        Assert.Equal(15_000, Assert.Single(order!.Items).UnitPriceVnd);
    }

    [Fact]
    public async Task PostOrder_UnknownProduct_Returns400()
    {
        await InsertCustomerAsync("customer-an");

        var response = await PlaceOrderAsync(ClientFor("customer-an", "customer"), productId: 999_999);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    // lesson: design.l2.testing-protected-endpoints
    // The caller the api will see: X-Test-Subject becomes the `sub` claim,
    // X-Test-Roles (comma-separated) the `roles` claims.
    private HttpClient ClientFor(string subject, string roles)
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-Subject", subject);
        client.DefaultRequestHeaders.Add("X-Test-Roles", roles);
        return client;
    }

    // lesson: design.l2.testing-protected-endpoints
    // identity_subject = the header's subject: the same link the api makes
    // from a Keycloak `sub` to a customers row.
    private async Task InsertCustomerAsync(string subject)
    {
        await using var db = factory.Database.CreateContext();
        db.Customers.Add(new Customer
        {
            FullName = subject, Email = $"{subject}@example.com", City = "Hà Nội", IdentitySubject = subject,
        });
        await db.SaveChangesAsync();
    }

    private async Task<int> InsertProductAsync()
    {
        await using var db = factory.Database.CreateContext();
        return await TestProducts.InsertAsync(db, "Pen", 15_000);
    }

    private static Task<HttpResponseMessage> PlaceOrderAsync(HttpClient client, int productId) =>
        client.PostAsJsonAsync("/api/v1/orders",
            new CreateOrderRequest([new CreateOrderItemRequest(productId, Quantity: 2, UnitPriceVnd: 15_000)]));

    private async Task<int> PlaceOrderForAsync(string subject)
    {
        var response = await PlaceOrderAsync(ClientFor(subject, "customer"), await InsertProductAsync());
        response.EnsureSuccessStatusCode();
        var order = await response.Content.ReadFromJsonAsync<OrderDto>();
        return order!.Id;
    }

    // The one field of a problem+json body these tests compare.
    private sealed record Problem(string? Type);
}
