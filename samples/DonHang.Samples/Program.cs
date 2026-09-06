using DonHang.Samples.Clean;
using DonHang.Samples.Computer;
using DonHang.Samples.Data;
using DonHang.Samples.Debug;
using DonHang.Samples.Http;

// Every sample in this project is one lesson's example, run by name:
//     dotnet run --project samples/DonHang.Samples -- throws-deep
var samples = new Dictionary<string, Func<Task>>
{
    ["hello-process"] = Sync(HelloProcess.Run),
    ["stack-heap"] = Sync(StackHeap.Run),
    ["read-config-file"] = Sync(ReadConfigFile.Run),
    ["read-env"] = Sync(ReadEnv.Run),
    ["threads-vs-async"] = ThreadsVsAsync.RunAsync,
    ["json-round-trip"] = Sync(JsonRoundTrip.Run),
    ["time-demo"] = Sync(TimeDemo.Run),
    ["collections-choice"] = Sync(CollectionsChoice.Run),
    ["nested-loops"] = Sync(NestedLoops.Run),
    ["load-orders"] = LoadOrdersAsync.RunAsync,
    ["wrong-total"] = Sync(WrongTotal.Run),
    ["throws-deep"] = Sync(ThrowsDeep.Run),
    ["logging-demo"] = Sync(LoggingDemo.Run),
    ["place-order"] = Sync(PlaceOrder),
};

if (args.Length == 0 || !samples.TryGetValue(args[0], out var run))
{
    Console.WriteLine("usage: dotnet run --project samples/DonHang.Samples -- <sample>");
    foreach (var name in samples.Keys.Order())
    {
        Console.WriteLine($"  {name}");
    }

    return 1;
}

await run();
return 0;

static Func<Task> Sync(Action action) => () =>
{
    action();
    return Task.CompletedTask;
};

static void PlaceOrder()
{
    var lines = new List<OrderLine> { new(1, 1_250_000), new(2, 450_000) };

    Console.WriteLine(PlaceOrderLong.Place(customerId: 1, lines, customerIsLoyal: false));
    Console.WriteLine(PlaceOrderSplit.Place(customerId: 1, lines, customerIsLoyal: false));
}
