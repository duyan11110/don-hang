using DonHang.Domain;

namespace DonHang.Tests;

// What Catalog would answer, from a dictionary: product 1 costs 100 000 đ and
// no other product exists unless a test adds one.
public sealed class FakeProductPrices : IProductPrices
{
    public Dictionary<int, Vnd> Prices { get; } = new() { [1] = new Vnd(100_000) };

    public Task<Vnd?> CurrentPriceAsync(int productId) =>
        Task.FromResult(Prices.GetValueOrDefault(productId));
}
