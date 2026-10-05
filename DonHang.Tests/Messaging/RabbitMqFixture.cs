using DonHang.Messaging;
using RabbitMQ.Client;
using Testcontainers.RabbitMq;
using Xunit;

namespace DonHang.Tests.Messaging;

// A throwaway RabbitMQ for the tests, from the same image as the rabbitmq
// service in docker-compose.yml. Testcontainers maps its port 5672 to a
// free port on the host; Settings points the code under test at it.
public sealed class RabbitMqFixture : IAsyncLifetime
{
    private readonly RabbitMqContainer container = new RabbitMqBuilder("rabbitmq:4.1.8-management-alpine")
        .WithUsername("donhang")
        .WithPassword("test-only")
        .Build();

    public RabbitMqSettings Settings => new()
    {
        Host = container.Hostname,
        Port = container.GetMappedPublicPort(5672),
        UserName = "donhang",
        Password = "test-only",
    };

    public Task InitializeAsync() => container.StartAsync();

    public async Task DisposeAsync() => await container.DisposeAsync();

    // A connection of the test's own, to look at queues and to publish.
    public async Task<IConnection> ConnectAsync() =>
        await new ConnectionFactory
        {
            HostName = Settings.Host,
            Port = Settings.Port,
            UserName = Settings.UserName,
            Password = Settings.Password,
        }.CreateConnectionAsync();

    public Task StopAsync() => container.StopAsync();

    public Task StartAsync() => container.StartAsync();
}
