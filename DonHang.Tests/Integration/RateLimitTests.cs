using System.Net;
using System.Net.Http.Json;
using DonHang.Api;
using DonHang.Domain;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace DonHang.Tests.Integration;

// lesson: backend.l3.rate-limiting
// The "orders" rate limit through the whole api, with a limit of 2 orders per
// minute for each customer instead of the 10 Program.cs uses by default.
// WithWebHostBuilder starts a second copy of the api with that one setting
// changed, on the same database; its limiter counts from zero.
public sealed class RateLimitTests(ApiFactory factory) : IClassFixture<ApiFactory>, IAsyncLifetime
{
    private readonly WebApplicationFactory<Program> limited =
        factory.WithWebHostBuilder(builder => builder.UseSetting("RateLimiting:Orders:PermitLimit", "2"));

    public Task InitializeAsync() => factory.Database.ResetAsync();

    public async Task DisposeAsync() => await limited.DisposeAsync();

    // The third order within the window is refused before the controller
    // runs: 429, a Retry-After header, and no third order saved.
    [Fact]
    public async Task ThirdOrderInOneWindow_Returns429WithRetryAfter()
    {
        await InsertCustomerAsync("customer-an");
        var productId = await InsertProductAsync();
        var client = ClientFor("customer-an");

        var first = await PlaceOrderAsync(client, productId);
        var second = await PlaceOrderAsync(client, productId);
        var third = await PlaceOrderAsync(client, productId);

        Assert.Equal((HttpStatusCode.Created, HttpStatusCode.Created), (first.StatusCode, second.StatusCode));
        Assert.Equal(HttpStatusCode.TooManyRequests, third.StatusCode);
        Assert.InRange(third.Headers.RetryAfter!.Delta!.Value, TimeSpan.FromSeconds(1), TimeSpan.FromMinutes(1));
        await using var db = factory.Database.CreateContext();
        Assert.Equal(2, await db.Orders.CountAsync());
    }

    // Each customer has a window of their own: one customer over the limit
    // does not stop another from ordering.
    [Fact]
    public async Task OneCustomerOverTheLimit_AnotherStillPlacesOrders()
    {
        await InsertCustomerAsync("customer-an");
        await InsertCustomerAsync("customer-binh");
        var productId = await InsertProductAsync();
        var an = ClientFor("customer-an");
        for (var i = 0; i < 3; i++) await PlaceOrderAsync(an, productId);

        var binh = await PlaceOrderAsync(ClientFor("customer-binh"), productId);

        Assert.Equal(HttpStatusCode.TooManyRequests, (await PlaceOrderAsync(an, productId)).StatusCode);
        Assert.Equal(HttpStatusCode.Created, binh.StatusCode);
    }

    private HttpClient ClientFor(string subject)
    {
        var client = limited.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-Subject", subject);
        client.DefaultRequestHeaders.Add("X-Test-Roles", "customer");
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

    private async Task<int> InsertProductAsync()
    {
        await using var db = factory.Database.CreateContext();
        return await TestProducts.InsertAsync(db, "Pen", 15_000);
    }

    private static Task<HttpResponseMessage> PlaceOrderAsync(HttpClient client, int productId) =>
        client.PostAsJsonAsync("/api/v1/orders",
            new CreateOrderRequest([new CreateOrderItemRequest(productId, Quantity: 2, UnitPriceVnd: 15_000)]));
}
