namespace DonHang.Samples.Design;

// lesson: design.l2.observer-pattern
// OrderEvents keeps the list of subscribers (the event) and calls each one;
// it never knows what they do. Handlers run one after another, in the order
// they subscribed, on the caller's thread, before Place returns.
public sealed class OrderEvents
{
    public event Action<int>? OrderPlaced;

    public void Place(int orderId)
    {
        // ... the order would be saved here ...
        OrderPlaced?.Invoke(orderId);
    }
}

// Two subscribers that know nothing about each other.
public sealed class EmailOnOrderPlaced(List<string> log)
{
    public void Handle(int orderId) => log.Add($"email for order {orderId}");
}

public sealed class StockOnOrderPlaced(List<string> log)
{
    public void Handle(int orderId) => log.Add($"stock for order {orderId}");
}
