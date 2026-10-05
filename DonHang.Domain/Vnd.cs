namespace DonHang.Domain;

// lesson: design.l3.value-objects
// An amount of money in whole đồng. A record, so two Vnd with the same Amount
// are equal; no setter and no `with`, so a Vnd never changes once created.
// Adding or multiplying gives a new Vnd. Used for OrderItem.UnitPrice and
// Order.Total only; elsewhere an amount is still an int named ...Vnd.
public sealed record Vnd
{
    public int Amount { get; }

    public Vnd(int amount)
    {
        if (amount < 0) throw new ArgumentOutOfRangeException(nameof(amount), "an amount in VND cannot be negative");
        Amount = amount;
    }

    public static Vnd Zero { get; } = new(0);

    // checked: an amount too big for an int throws instead of turning negative.
    public Vnd Plus(Vnd other) => new(checked(Amount + other.Amount));

    public Vnd Times(int quantity) => new(checked(Amount * quantity));

    public override string ToString() => $"{Amount} VND";
}
