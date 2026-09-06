namespace DonHang.Samples.Computer;

// lesson: foundation.l1.env-and-config
public static class ReadEnv
{
    private const string VariableName = "DONHANG_DB";

    public static void Run()
    {
        var configured = Environment.GetEnvironmentVariable(VariableName);
        var connectionString = configured ?? "Host=db;Database=donhang;Username=donhang";

        Console.WriteLine($"{VariableName} was {(configured is null ? "not set" : "set")}");
        Console.WriteLine($"the program will use: {connectionString}");

        Environment.SetEnvironmentVariable(VariableName, "changed inside this process");
        Console.WriteLine($"after changing it here: {Environment.GetEnvironmentVariable(VariableName)}");
        Console.WriteLine("the terminal that started this program still has its own value");
    }
}
