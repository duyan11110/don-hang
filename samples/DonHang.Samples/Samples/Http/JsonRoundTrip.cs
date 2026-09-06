using System.Text;
using System.Text.Json;

namespace DonHang.Samples.Http;

public sealed record OrderLineDto(int ProductId, int Quantity);

// lesson: foundation.l1.json-and-encoding
public static class JsonRoundTrip
{
    private static readonly JsonSerializerOptions Options =
        new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

    public static void Run()
    {
        var line = new OrderLineDto(ProductId: 3, Quantity: 2);

        var json = JsonSerializer.Serialize(line, Options);
        Console.WriteLine(json);

        var backAgain = JsonSerializer.Deserialize<OrderLineDto>(json, Options);
        Console.WriteLine($"the same values came back: {backAgain == line}");

        // The names must agree on both sides, or a field silently stays empty.
        var pascalCase = """{"ProductId":3,"Quantity":2}""";
        var strict = JsonSerializer.Deserialize<OrderLineDto>(pascalCase, Options);
        Console.WriteLine($"PascalCase read with a camelCase policy: {strict}");

        var text = """{"city":"Đà Nẵng"}""";
        Console.WriteLine($"characters: {text.Length}, bytes in UTF-8: {Encoding.UTF8.GetByteCount(text)}");
    }
}
