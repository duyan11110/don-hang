using Npgsql;

namespace DonHang.Samples.Data;

// lesson: foundation.l1.async-in-csharp
public static class LoadOrdersAsync
{
    private static string ConnectionString =>
        "Host=db;Port=5432;Database=donhang;Username=donhang;" +
        $"Password={Environment.GetEnvironmentVariable("PGPASSWORD")}";

    public static async Task<List<string>> LoadPaidOrdersAsync(CancellationToken cancellationToken)
    {
        await using var connection = new NpgsqlConnection(ConnectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new NpgsqlCommand(
            "SELECT id, status FROM orders WHERE status = 'paid' ORDER BY id", connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var orders = new List<string>();
        while (await reader.ReadAsync(cancellationToken))
        {
            orders.Add($"order {reader.GetInt32(0)} is {reader.GetString(1)}");
        }

        return orders;
    }

    public static async Task RunAsync()
    {
        foreach (var order in await LoadPaidOrdersAsync(CancellationToken.None))
        {
            Console.WriteLine(order);
        }
    }
}
