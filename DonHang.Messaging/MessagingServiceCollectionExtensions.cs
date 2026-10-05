using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace DonHang.Messaging;

// What a service's Program.cs calls to talk to RabbitMQ: one shared
// connection, and for a service that publishes, its relay and publisher.
public static class MessagingServiceCollectionExtensions
{
    // clientName shows in RabbitMQ's list of connections (rabbitmqctl, the
    // management page), so each service names itself.
    public static IServiceCollection AddRabbitMq(
        this IServiceCollection services, RabbitMqSettings settings, string clientName)
    {
        services.AddSingleton(new RabbitMqConnection(settings, clientName));
        return services;
    }

    // The relay reads TDbContext's outbox_messages and publishes to exchange.
    public static IServiceCollection AddOutboxRelay<TDbContext>(this IServiceCollection services, string exchange)
        where TDbContext : DbContext
    {
        services.AddSingleton(provider => new RabbitMqPublisher(provider.GetRequiredService<RabbitMqConnection>(), exchange));
        services.AddHostedService<OutboxRelay<TDbContext>>();
        return services;
    }
}
