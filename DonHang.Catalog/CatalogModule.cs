using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using StackExchange.Redis;

namespace DonHang.Catalog;

// lesson: design.l3.modules-cut-through-layers
// Everything the Catalog module needs, registered by the module itself:
// its DbContext, its repository, its Redis cache and its contract. Program.cs
// calls AddCatalogModule once and sees only ICatalog afterwards.
public static class CatalogModule
{
    public static IServiceCollection AddCatalogModule(
        this IServiceCollection services, string connectionString, string redisConfiguration)
    {
        services.AddDbContext<CatalogDbContext>(options => options.UseNpgsql(connectionString));

        // lesson: backend.l2.cache-aside
        // One ConnectionMultiplexer for the whole app: it is built to be shared
        // by every request. abortConnect=false (in redisConfiguration) lets the
        // app start, and keep trying to connect, while Redis is down; FailFast
        // makes each command fail at once meanwhile, instead of waiting.
        services.AddSingleton<IConnectionMultiplexer>(_ =>
        {
            var options = ConfigurationOptions.Parse(redisConfiguration);
            options.BacklogPolicy = BacklogPolicy.FailFast;
            return ConnectionMultiplexer.Connect(options);
        });

        // lesson: design.l2.decorator-pattern
        // Whoever asks for an IProductRepository gets a ProductCache with an
        // EfProductRepository inside it. Nothing else knows about the wrapping.
        services.AddScoped<EfProductRepository>();
        services.AddScoped<IProductRepository>(provider => new ProductCache(
            provider.GetRequiredService<EfProductRepository>(),
            provider.GetRequiredService<IConnectionMultiplexer>(),
            provider.GetRequiredService<ILogger<ProductCache>>()));

        services.AddScoped<ICatalog, CatalogService>();
        return services;
    }
}
