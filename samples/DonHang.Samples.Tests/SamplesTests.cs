using DonHang.Samples.Clean;
using DonHang.Samples.Design;
using DonHang.Samples.Oop;
using Xunit;

namespace DonHang.Samples.Tests;

public class ShippingFeeTests
{
    [Fact]
    public void StandardShippingIsFreeFromTwoMillion()
    {
        ShippingFee fee = new StandardShipping();

        Assert.Equal(30_000, fee.ForOrder(1_999_999));
        Assert.Equal(0, fee.ForOrder(2_000_000));
    }

    [Fact]
    public void EveryKindAnswersTheSameCall()
    {
        var kinds = new ShippingFee[] { new StandardShipping(), new ExpressShipping(), new PickUpInStore() };

        Assert.Equal(new[] { 0, 60_000, 0 }, kinds.Select(kind => kind.ForOrder(2_000_000)));
    }
}

public class OrderEncapsulatedTests
{
    [Fact]
    public void TotalFollowsTheLines()
    {
        var order = new OrderEncapsulated(1);
        order.AddLine(productId: 1, quantity: 1, unitPriceVnd: 1_250_000);
        order.AddLine(productId: 2, quantity: 2, unitPriceVnd: 450_000);

        Assert.Equal(2_150_000, order.TotalVnd);
    }

    [Fact]
    public void AnEmptyOrderCannotBePaid()
    {
        var order = new OrderEncapsulated(2);

        Assert.Throws<InvalidOperationException>(order.MarkPaid);
    }
}

public class PlaceOrderTests
{
    [Fact]
    public void BothVersionsAgree()
    {
        var lines = new List<OrderLine> { new(1, 1_250_000), new(2, 450_000) };

        Assert.Equal(
            PlaceOrderLong.Place(customerId: 1, lines, customerIsLoyal: false),
            PlaceOrderSplit.Place(customerId: 1, lines, customerIsLoyal: false));
    }

    [Fact]
    public void AnOrderWithNoLinesIsRefused()
    {
        Assert.Equal(
            "an order needs at least one line",
            PlaceOrderSplit.Place(customerId: 1, [], customerIsLoyal: false));
    }
}

public class WrongTotalTests
{
    [Fact]
    public void TheReportedBugIsReal()
    {
        var orderOne = new (int Quantity, int UnitPriceVnd)[] { (1, 1_250_000), (2, 450_000) };

        // 2_150_000 is the right answer; this records what the code does today.
        Assert.Equal(1_250_000, DonHang.Samples.Debug.WrongTotal.TotalVnd(orderOne));
    }
}

// lesson: design.l2.strategy-pattern
public class CheckoutTotalTests
{
    private static readonly (int Quantity, int UnitPriceVnd)[] Items = [(1, 1_250_000), (2, 450_000)];

    [Fact]
    public void AddsTheStandardFee()
    {
        var checkout = new CheckoutTotal(new StandardShipping());

        Assert.Equal(2_150_000, checkout.ForItems(Items));
    }

    [Fact]
    public void AddsTheExpressFee()
    {
        var checkout = new CheckoutTotal(new ExpressShipping());

        Assert.Equal(2_210_000, checkout.ForItems(Items));
    }
}

public class ShippingFeeFactoryTests
{
    [Fact]
    public void EachKindGetsItsOwnClass()
    {
        Assert.IsType<StandardShipping>(ShippingFeeFactory.ForKind("standard"));
        Assert.IsType<ExpressShipping>(ShippingFeeFactory.ForKind("express"));
        Assert.IsType<PickUpInStore>(ShippingFeeFactory.ForKind("pickup"));
    }

    [Fact]
    public void AnUnknownKindIsRefused()
    {
        Assert.Throws<ArgumentException>(() => ShippingFeeFactory.ForKind("same_day"));
    }
}

// lesson: design.l2.observer-pattern
public class OrderEventsTests
{
    [Fact]
    public void HandlersRunInTheOrderTheySubscribed()
    {
        var log = new List<string>();
        var events = new OrderEvents();
        events.OrderPlaced += new EmailOnOrderPlaced(log).Handle;
        events.OrderPlaced += new StockOnOrderPlaced(log).Handle;

        events.Place(7);

        Assert.Equal(["email for order 7", "stock for order 7"], log);
    }

    [Fact]
    public void AThrowingHandlerStopsTheRestAndReachesPlace()
    {
        var log = new List<string>();
        var events = new OrderEvents();
        events.OrderPlaced += _ => throw new InvalidOperationException("mail server down");
        events.OrderPlaced += new StockOnOrderPlaced(log).Handle;

        Assert.Throws<InvalidOperationException>(() => events.Place(7));
        Assert.Empty(log);
    }
}
