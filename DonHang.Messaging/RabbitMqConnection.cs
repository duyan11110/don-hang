using RabbitMQ.Client;

namespace DonHang.Messaging;

// Where RabbitMQ is: rabbitmq:5672 in the lab, user donhang, the password
// that scripts/dev-secrets.sh wrote to .env (Program.cs reads "RabbitMq").
public sealed class RabbitMqSettings
{
    public string Host { get; set; } = "localhost";
    public int Port { get; set; } = 5672;
    public string UserName { get; set; } = "donhang";
    public string Password { get; set; } = "";
}

// One TCP connection to RabbitMQ for the whole process, shared by the
// publisher and the consumers; each of them opens its own channel on it.
// It is opened on first use, not at startup, so a service starts and serves
// requests while RabbitMQ is down. Once open, the client library reconnects
// by itself after RabbitMQ restarts (automatic recovery, on by default).
public sealed class RabbitMqConnection(RabbitMqSettings settings, string clientName) : IAsyncDisposable
{
    private readonly SemaphoreSlim opening = new(1, 1);
    private IConnection? connection;

    public async Task<IConnection> GetAsync(CancellationToken cancellationToken)
    {
        if (connection is not null) return connection;

        await opening.WaitAsync(cancellationToken);
        try
        {
            var factory = new ConnectionFactory
            {
                HostName = settings.Host,
                Port = settings.Port,
                UserName = settings.UserName,
                Password = settings.Password,
                ClientProvidedName = clientName,
            };
            // Throws while RabbitMQ is unreachable; the caller tries again later.
            connection ??= await factory.CreateConnectionAsync(cancellationToken);
            return connection;
        }
        finally
        {
            opening.Release();
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (connection is not null) await connection.DisposeAsync();
    }
}
