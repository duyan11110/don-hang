using System.Collections.Concurrent;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using StackExchange.Redis;

namespace DonHang.Catalog;

// lesson: design.l2.decorator-pattern
// An IProductRepository that holds another IProductRepository
// (EfProductRepository) and adds one job around its calls: a copy of each
// product in Redis. Callers cannot tell it apart from the repository inside.
// From stage-3 it is part of the Catalog module and `internal`.
internal sealed class ProductCache(IProductRepository inner, IConnectionMultiplexer redis, ILogger<ProductCache> logger)
    : IProductRepository
{
    // lesson: backend.l2.cache-invalidation
    // The longest a stale copy can live, even if a delete below is missed.
    private static readonly TimeSpan Ttl = TimeSpan.FromMinutes(5);

    // One SemaphoreSlim per key, shared by every request in this api process.
    private static readonly ConcurrentDictionary<string, SemaphoreSlim> Locks = new();

    // lesson: backend.l2.cache-aside
    // Redis first; only on a miss ask the repository inside, then keep its answer.
    public async Task<Product?> FindAsync(int id)
    {
        var key = $"product:{id}";
        var cached = await GetAsync(key);
        if (cached is not null) return cached; // cache hit: no query

        // lesson: backend.l2.cache-stampede
        // Only one request per key goes on to PostgreSQL; the others wait here.
        var keyLock = Locks.GetOrAdd(key, _ => new SemaphoreSlim(1, 1));
        await keyLock.WaitAsync();
        try
        {
            // While this request waited, the one before it may have filled the key.
            cached = await GetAsync(key);
            if (cached is not null) return cached;

            var product = await inner.FindAsync(id); // cache miss: one query
            if (product is not null) await SetAsync(key, product);
            return product;
        }
        finally
        {
            keyLock.Release();
        }
    }

    // lesson: backend.l2.cache-invalidation
    // Save first, then delete the copy: the next read is a miss that loads the
    // new price. Deleting before the save would let a read put the old one back.
    public async Task<Product?> UpdatePriceAsync(int id, int priceVnd)
    {
        var product = await inner.UpdatePriceAsync(id, priceVnd);
        if (product is not null) await RemoveAsync($"product:{id}");
        return product;
    }

    // lesson: backend.l2.cache-aside
    // Redis holds only copies, so any Redis error counts as a miss: product
    // reads get slower while Redis is down, not broken.
    private async Task<Product?> GetAsync(string key)
    {
        try
        {
            var json = await redis.GetDatabase().StringGetAsync(key);
            return json.IsNull ? null : JsonSerializer.Deserialize<Product>(json.ToString(), JsonSerializerOptions.Web);
        }
        catch (Exception ex) when (IsRedisFailure(ex))
        {
            logger.LogWarning(ex, "Redis read of {Key} failed; reading PostgreSQL instead", key);
            return null;
        }
    }

    // lesson: backend.l3.slow-dependencies
    // What a failed Redis command throws: an error, a timeout, or, when the
    // connection is torn down while the command waits, a cancelled task (no
    // cancellation token is passed here, so nothing else cancels it).
    private static bool IsRedisFailure(Exception ex) =>
        ex is RedisException or RedisTimeoutException or TaskCanceledException;

    private async Task SetAsync(string key, Product product)
    {
        try
        {
            var json = JsonSerializer.Serialize(product, JsonSerializerOptions.Web);
            await redis.GetDatabase().StringSetAsync(key, json, Ttl);
        }
        catch (Exception ex) when (IsRedisFailure(ex))
        {
            logger.LogWarning(ex, "Redis write of {Key} failed; the next read queries PostgreSQL again", key);
        }
    }

    private async Task RemoveAsync(string key)
    {
        try
        {
            await redis.GetDatabase().KeyDeleteAsync(key);
        }
        catch (Exception ex) when (IsRedisFailure(ex))
        {
            logger.LogWarning(ex, "Redis delete of {Key} failed; the old copy lives until its TTL ends", key);
        }
    }
}
