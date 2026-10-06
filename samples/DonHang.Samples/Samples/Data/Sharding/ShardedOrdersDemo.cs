namespace DonHang.Samples.Data.Sharding;

// Run by scripts/backend/shard-split.sh, after it has copied donhang_perf's
// orders into donhang_shard_0 and donhang_shard_1 by customer_id % 2.
public static class ShardedOrdersDemo
{
    private static string Shard(string database) =>
        $"Host={Environment.GetEnvironmentVariable("PGHOST") ?? "localhost"};Port=5432;" +
        $"Database={database};Username=donhang;" +
        $"Password={Environment.GetEnvironmentVariable("PGPASSWORD")}";

    public static async Task RunAsync()
    {
        var orders = new ShardedOrders([Shard("donhang_shard_0"), Shard("donhang_shard_1")]);
        var cancel = CancellationToken.None;

        Console.WriteLine($"customer 7 is on shard {orders.ShardFor(7)}; its 3 newest orders:");
        foreach (var order in await orders.LatestForCustomerAsync(7, 3, cancel))
        {
            Console.WriteLine($"  order {order.Id}, shard {order.Shard}");
        }

        const int count = 30;
        var newest = await orders.LatestAcrossShardsAsync(count, cancel);
        Console.WriteLine($"the {count} newest orders of all customers (each shard returned {count}):");
        Console.WriteLine($"  orders {newest[^1].Id} to {newest[0].Id}");
        Console.WriteLine($"  {newest.Count(order => order.Shard == 0)} from shard 0, " +
                          $"{newest.Count(order => order.Shard == 1)} from shard 1");

        // The mistake: half of `count` from each of the two shards.
        var halves = ShardedOrders.Merge(
            [await orders.LatestOnShardAsync(0, count / 2, cancel),
             await orders.LatestOnShardAsync(1, count / 2, cancel)],
            count);
        var newestIds = newest.Select(order => order.Id).ToHashSet();
        Console.WriteLine($"with {count / 2} from each shard instead: " +
                          $"{halves.Count(order => !newestIds.Contains(order.Id))} of the {count} are not among the newest");
    }
}
