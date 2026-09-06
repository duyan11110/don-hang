namespace DonHang.Samples.Oop;

// lesson: foundation.l1.oop-encapsulation
// Every field is public, so any code anywhere can put an order into a state
// the business does not allow: paid but empty, or with a negative total.
public sealed class OrderExposed
{
    public int Id;
    public string Status = "new";
    public int TotalVnd;
    public List<OrderLineExposed> Lines = new();
}

public sealed class OrderLineExposed
{
    public int ProductId;
    public int Quantity;
    public int UnitPriceVnd;
}
