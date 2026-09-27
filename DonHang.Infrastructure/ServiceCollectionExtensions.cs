using DonHang.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using StackExchange.Redis;

namespace DonHang.Infrastructure;

// lesson: design.l1.wiring-the-container
// The one call Program.cs makes to get a repository, a notifier and a
// DbContext registered — OrderService only ever sees the interfaces.
public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddDonHangInfrastructure(
        this IServiceCollection services, string connectionString, string redisConfiguration)
    {
        services.AddDbContext<DonHangDbContext>(options => options.UseNpgsql(connectionString));
        services.AddScoped<IOrderRepository, EfOrderRepository>();
        services.AddScoped<ICustomerRepository, EfCustomerRepository>();
        services.AddScoped<INotifier, LoggingNotifier>();

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
        return services;
    }
}
