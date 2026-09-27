using DonHang.Samples.Oop;

namespace DonHang.Samples.Design;

// lesson: design.l2.factory
// Turns the kind string that arrives from outside into a ShippingFee object.
// The branch on the string is still here, but only to pick a class: the fee
// rules stay in the subclasses (compare ShippingFeeIfElseChain). A new kind is
// one new subclass plus one new line below.
public static class ShippingFeeFactory
{
    public static ShippingFee ForKind(string kind) => kind switch
    {
        "standard" => new StandardShipping(),
        "express" => new ExpressShipping(),
        "pickup" => new PickUpInStore(),
        _ => throw new ArgumentException($"unknown shipping kind: {kind}"),
    };
}
