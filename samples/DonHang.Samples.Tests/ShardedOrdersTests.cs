using DonHang.Samples.Data.Sharding;
using Xunit;

namespace DonHang.Samples.Tests;

public class ShardedOrdersTests
{
    private static readonly DateTimeOffset Noon = new(2026, 5, 19, 12, 0, 0, TimeSpan.FromHours(7));

    private static ShardedOrder Order(int id, int minutesAfterNoon, int shard) =>
        new(id, CustomerId: 1, Noon.AddMinutes(minutesAfterNoon), shard);

    [Fact]
    public void ShardForIsTheCustomerIdModuloTheNumberOfShards()
    {
        var orders = new ShardedOrders(["shard 0", "shard 1"]);

        Assert.Equal(1, orders.ShardFor(7));
        Assert.Equal(0, orders.ShardFor(12));
    }

    [Fact]
    public void MergeKeepsTheNewestAcrossShards()
    {
        List<ShardedOrder> shard0 = [Order(4, 40, 0), Order(2, 20, 0)];
        List<ShardedOrder> shard1 = [Order(3, 30, 1), Order(1, 10, 1)];

        var newest = ShardedOrders.Merge([shard0, shard1], 3);

        Assert.Equal([4, 3, 2], newest.Select(order => order.Id));
    }

    [Fact]
    public void HalfFromEachShardMissesNewestOrdersThatSitOnOneShard()
    {
        // Shard 1 has the four newest orders; shard 0 only older ones.
        List<ShardedOrder> shard0 = [Order(2, 2, 0), Order(1, 1, 0)];
        List<ShardedOrder> shard1 = [Order(6, 60, 1), Order(5, 50, 1), Order(4, 40, 1), Order(3, 30, 1)];

        var right = ShardedOrders.Merge([shard0, shard1], 4);
        var halves = ShardedOrders.Merge([shard0.Take(2).ToList(), shard1.Take(2).ToList()], 4);

        Assert.Equal([6, 5, 4, 3], right.Select(order => order.Id));
        Assert.Equal([6, 5, 2, 1], halves.Select(order => order.Id));
    }
}
