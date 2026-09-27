using DonHang.Samples.Oop;

namespace DonHang.Samples.Design;

// lesson: design.l2.strategy-pattern
// The shipping rule is handed in from outside, through the constructor.
// CheckoutTotal adds whatever fee it is given and never asks which kind of
// shipping that was — a new ShippingFee subclass needs no change here.
public sealed class CheckoutTotal(ShippingFee shippingFee)
{
    public int ForItems(IEnumerable<(int Quantity, int UnitPriceVnd)> items)
    {
        var itemsTotalVnd = items.Sum(item => item.Quantity * item.UnitPriceVnd);
        return itemsTotalVnd + shippingFee.ForOrder(itemsTotalVnd);
    }
}
