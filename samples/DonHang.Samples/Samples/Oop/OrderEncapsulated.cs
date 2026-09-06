namespace DonHang.Samples.Oop;

// lesson: foundation.l1.oop-encapsulation
public sealed class OrderEncapsulated
{
    private readonly List<OrderLineExposed> lines = new();

    public OrderEncapsulated(int id) => Id = id;

    public int Id { get; }
    public string Status { get; private set; } = "new";
    public int TotalVnd => lines.Sum(line => line.Quantity * line.UnitPriceVnd);

    public void AddLine(int productId, int quantity, int unitPriceVnd)
    {
        if (quantity <= 0)
            throw new ArgumentOutOfRangeException(nameof(quantity), "a line needs a quantity");
        if (unitPriceVnd <= 0)
            throw new ArgumentOutOfRangeException(nameof(unitPriceVnd), "a line needs a price");

        lines.Add(new OrderLineExposed
        {
            ProductId = productId,
            Quantity = quantity,
            UnitPriceVnd = unitPriceVnd,
        });
    }

    public void MarkPaid()
    {
        if (lines.Count == 0)
            throw new InvalidOperationException("an order with no lines cannot be paid");

        Status = "paid";
    }
}
