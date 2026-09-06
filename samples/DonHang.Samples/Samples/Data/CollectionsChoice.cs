namespace DonHang.Samples.Data;

public sealed record Product(int Id, string Name, int PriceVnd);

// lesson: foundation.l1.collections-in-practice
public static class CollectionsChoice
{
    public static void Run()
    {
        var products = new List<Product>
        {
            new(1, "Bàn phím cơ", 1_250_000),
            new(2, "Chuột không dây", 450_000),
            new(3, "Tai nghe", 890_000),
        };

        // Keeps the order you put things in, and lets you walk them.
        foreach (var product in products)
            Console.WriteLine($"{product.Id} {product.Name}");

        // Answers "the one with this id" without looking at the others.
        var byId = products.ToDictionary(product => product.Id);
        Console.WriteLine($"product 2 is {byId[2].Name}");

        // Answers "is this one in here" and refuses duplicates.
        var idsInBasket = new HashSet<int> { 2, 3, 2 };
        Console.WriteLine($"{idsInBasket.Count} distinct ids, contains 3: {idsInBasket.Contains(3)}");
    }
}
