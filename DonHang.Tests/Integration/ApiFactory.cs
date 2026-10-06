using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using Testcontainers.Redis;
using Xunit;

namespace DonHang.Tests.Integration;

// lesson: design.l2.webapplicationfactory
// Runs DonHang.Api's own Program.cs inside the test process, against a real
// PostgreSQL (PostgresFixture, migrated before the app starts) and a real
// Redis, both from the images docker-compose.yml uses. The app builds once,
// on the first CreateClient(), after InitializeAsync has started both.
public sealed class ApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly RedisContainer redis = new RedisBuilder("redis:8.10.2-alpine").Build();

    public PostgresFixture Database { get; } = new();

    public async Task InitializeAsync()
    {
        await Database.InitializeAsync();
        await redis.StartAsync();
    }

    // lesson: design.l2.webapplicationfactory
    // lesson: design.l2.testing-protected-endpoints
    // UseSetting feeds the containers' connection strings to the app as
    // configuration, where the lab passes them as environment variables.
    // ConfigureTestServices runs after Program.cs's registrations: it makes
    // TestAuthHandler the default scheme and, from stage-3, removes the hosted
    // services (OutboxRelay, PaymentEventsConsumer): there is no RabbitMQ
    // here, so outbox rows simply stay unpublished for the tests to read.
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseSetting("ConnectionStrings:Default", Database.ConnectionString);
        builder.UseSetting("ConnectionStrings:Redis", redis.GetConnectionString());
        // From stage-3 POST /api/v1/orders is rate limited per customer; the
        // tests place many orders as the same few customers within a minute.
        // RateLimitTests sets a low limit for itself.
        builder.UseSetting("RateLimiting:Orders:PermitLimit", "1000");
        builder.ConfigureTestServices(services =>
        {
            services.RemoveAll<IHostedService>();
            services.AddAuthentication(TestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(TestAuthHandler.SchemeName, null);
        });
    }

    async Task IAsyncLifetime.DisposeAsync()
    {
        await DisposeAsync();
        await redis.DisposeAsync();
        await Database.DisposeAsync();
    }
}
