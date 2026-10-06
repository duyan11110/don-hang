using Npgsql;

namespace DonHang.Samples.Data.Sharding;

public sealed record ShardedOrder(int Id, int CustomerId, DateTimeOffset PlacedAt, int Shard);

// Orders split over several databases by customer_id. Each connection
// string is one shard, and its place in the list is the shard's number.
public sealed class ShardedOrders(IReadOnlyList<string> shards)
{
    // lesson: backend.l3.cross-shard-queries
    // The shard key is customer_id, so a customer's id alone says which
    // shard holds all of that customer's orders: only that shard is asked.
    public int ShardFor(int customerId) => customerId % shards.Count;

    public async Task<List<ShardedOrder>> LatestForCustomerAsync(
        int customerId, int count, CancellationToken cancellationToken)
    {
        var shard = ShardFor(customerId);
        const string sql = """
            SELECT id, customer_id, placed_at FROM orders
            WHERE customer_id = @customer_id
            ORDER BY placed_at DESC, id DESC LIMIT @count
            """;
        return await QueryAsync(shard, sql, customerId, count, cancellationToken);
    }

    // lesson: backend.l3.cross-shard-queries
    // No shard key: scatter the query to every shard at once, gather the
    // lists, keep the newest `count`. Each shard returns `count` orders, not
    // count / shards: the newest ones may all sit on one shard. The answer
    // waits for the slowest shard, and fails if any shard fails.
    public async Task<List<ShardedOrder>> LatestAcrossShardsAsync(
        int count, CancellationToken cancellationToken)
    {
        var queries = new List<Task<List<ShardedOrder>>>();
        for (var shard = 0; shard < shards.Count; shard++)
        {
            queries.Add(LatestOnShardAsync(shard, count, cancellationToken));
        }

        var perShard = await Task.WhenAll(queries);
        return Merge(perShard, count);
    }

    // The newest `count` orders of all the shards' lists together.
    public static List<ShardedOrder> Merge(IEnumerable<IReadOnlyList<ShardedOrder>> perShard, int count) =>
        perShard.SelectMany(orders => orders)
            .OrderByDescending(order => order.PlacedAt)
            .ThenByDescending(order => order.Id)
            .Take(count)
            .ToList();

    public async Task<List<ShardedOrder>> LatestOnShardAsync(
        int shard, int count, CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT id, customer_id, placed_at FROM orders
            ORDER BY placed_at DESC, id DESC LIMIT @count
            """;
        return await QueryAsync(shard, sql, customerId: null, count, cancellationToken);
    }

    private async Task<List<ShardedOrder>> QueryAsync(
        int shard, string sql, int? customerId, int count, CancellationToken cancellationToken)
    {
        await using var connection = new NpgsqlConnection(shards[shard]);
        await connection.OpenAsync(cancellationToken);

        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("count", count);
        if (customerId is not null)
        {
            command.Parameters.AddWithValue("customer_id", customerId.Value);
        }

        var orders = new List<ShardedOrder>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            orders.Add(new ShardedOrder(
                reader.GetInt32(0), reader.GetInt32(1), reader.GetFieldValue<DateTimeOffset>(2), shard));
        }

        return orders;
    }
}
