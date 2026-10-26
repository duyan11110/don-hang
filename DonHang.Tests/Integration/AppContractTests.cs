using System.Net.Http.Json;
using System.Text.Json;
using DonHang.Api;
using DonHang.Domain;
using Xunit;

namespace DonHang.Tests.Integration;

// lesson: frontend.l4.app-api-contract
// contracts/app/ holds sample answers with only the fields DonHang.App reads,
// written from the app's side. These tests ask the real api for a product
// and a placed order and check every field of each sample: it must be in the
// answer, with the same JSON type. Fields the app does not read may be added
// freely; renaming PriceVnd, say, fails here.
public sealed class AppContractTests(ApiFactory factory) : IClassFixture<ApiFactory>, IAsyncLifetime
{
    public Task InitializeAsync() => factory.Database.ResetAsync();

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task Product_HasEveryFieldTheAppReads()
    {
        int productId;
        await using (var db = factory.Database.CreateContext())
            productId = await TestProducts.InsertAsync(db, "Tai nghe", 890_000);

        var answer = await factory.CreateClient().GetFromJsonAsync<JsonElement>($"/api/v1/products/{productId}");

        AssertMatches(Sample("product.json"), answer, "product");
    }

    [Fact]
    public async Task Order_HasEveryFieldTheAppReads()
    {
        await using (var db = factory.Database.CreateContext())
        {
            db.Customers.Add(new Customer
            {
                FullName = "customer-an", Email = "customer-an@example.com", City = "Hà Nội", IdentitySubject = "customer-an",
            });
            await db.SaveChangesAsync();
        }
        int productId;
        await using (var db = factory.Database.CreateContext())
            productId = await TestProducts.InsertAsync(db, "Tai nghe", 890_000);
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-Subject", "customer-an");
        client.DefaultRequestHeaders.Add("X-Test-Roles", "customer");

        var placed = await client.PostAsJsonAsync("/api/v1/orders",
            new CreateOrderRequest([new CreateOrderItemRequest(productId, Quantity: 2, UnitPriceVnd: 890_000)]));
        placed.EnsureSuccessStatusCode();
        var answer = await client.GetFromJsonAsync<JsonElement>(placed.Headers.Location);

        AssertMatches(Sample("order.json"), answer, "order");
    }

    // Every property of the sample, at any depth: present, with the same
    // kind of JSON value. An array's first sample element describes each
    // element of the answer's array.
    private static void AssertMatches(JsonElement sample, JsonElement answer, string path)
    {
        Assert.True(sample.ValueKind == answer.ValueKind,
            $"{path}: the app expects {sample.ValueKind}, the api sends {answer.ValueKind}");
        if (sample.ValueKind == JsonValueKind.Object)
        {
            foreach (var field in sample.EnumerateObject())
            {
                Assert.True(answer.TryGetProperty(field.Name, out var value), $"{path}.{field.Name}: missing from the api's answer");
                AssertMatches(field.Value, value, $"{path}.{field.Name}");
            }
        }
        else if (sample.ValueKind == JsonValueKind.Array && sample.GetArrayLength() > 0)
        {
            Assert.NotEqual(0, answer.GetArrayLength());
            foreach (var item in answer.EnumerateArray())
                AssertMatches(sample[0], item, $"{path}[]");
        }
    }

    // contracts/app/ at the repository's root, found from the test's own folder.
    private static JsonElement Sample(string name)
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir is not null; dir = dir.Parent)
        {
            var file = Path.Combine(dir.FullName, "contracts", "app", name);
            if (File.Exists(file))
                return JsonDocument.Parse(File.ReadAllText(file)).RootElement;
        }
        throw new FileNotFoundException($"contracts/app/{name} not found above {AppContext.BaseDirectory}");
    }
}
