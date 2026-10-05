namespace DonHang.Domain;

// One line of an order as the customer asks for it: which product and how
// many. No price: OrderService takes each price from IProductPrices.
public sealed record RequestedItem(int ProductId, int Quantity);
