using DonHang.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace DonHang.Infrastructure;

// lesson: design.l1.wiring-the-container
// The one call Program.cs makes to get Ordering's repositories, outbox,
// event handlers and DbContext registered — OrderService only ever sees the
// interfaces. Products, Redis and their cache are the Catalog module's own
// registrations from stage-3 (CatalogModule.AddCatalogModule).
public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddDonHangInfrastructure(
        this IServiceCollection services, string connectionString)
    {
        services.AddDbContext<DonHangDbContext>(options => options.UseNpgsql(connectionString));
        services.AddScoped<IOrderRepository, EfOrderRepository>();
        services.AddScoped<ICustomerRepository, EfCustomerRepository>();

        // lesson: backend.l3.outbox-pattern
        // From stage-3 a message for another service is an outbox row in the
        // order's DbContext; OutboxRelay (Program.cs) publishes it afterwards.
        services.AddScoped<IOutbox, EfOutbox>();

        // lesson: design.l3.dispatching-domain-events
        // One line per reaction to one kind of event. A new reaction to a
        // cancelled order is one more line here; Order and OrderService stay
        // as they are. DomainEventDispatcher gets every handler of each kind.
        services.AddScoped<IDomainEventHandler<OrderPlaced>, NotifyCustomerOnOrderEvents>();
        services.AddScoped<IDomainEventHandler<OrderCancelled>, NotifyCustomerOnOrderEvents>();
        services.AddScoped<IDomainEventHandler<OrderShipped>, NotifyCustomerOnOrderEvents>();
        services.AddScoped<IDomainEventHandler<OrderRefundRequested>, NotifyCustomerOnOrderEvents>();
        services.AddScoped<IDomainEventHandler<OrderRefunded>, NotifyCustomerOnOrderEvents>();
        services.AddScoped<IDomainEventHandler<OrderRefundFailed>, NotifyCustomerOnOrderEvents>();
        services.AddScoped<IDomainEventHandler<OrderPlaced>, RecordOrderStatusHistory>();
        services.AddScoped<IDomainEventHandler<OrderCancelled>, RecordOrderStatusHistory>();
        services.AddScoped<IDomainEventHandler<OrderShipped>, RecordOrderStatusHistory>();
        services.AddScoped<IDomainEventHandler<OrderRefundRequested>, RecordOrderStatusHistory>();
        services.AddScoped<IDomainEventHandler<OrderRefunded>, RecordOrderStatusHistory>();
        services.AddScoped<IDomainEventHandler<OrderRefundFailed>, RecordOrderStatusHistory>();
        services.AddScoped<DomainEventDispatcher>();

        // lesson: design.l3.read-model
        services.AddScoped<IOrderHistory, EfOrderHistory>();

        // lesson: design.l3.one-way-module-dependencies
        // Ordering asks for prices through its own port; this adapter answers
        // through ICatalog, which AddCatalogModule registers.
        services.AddScoped<IProductPrices, CatalogProductPrices>();
        return services;
    }
}
