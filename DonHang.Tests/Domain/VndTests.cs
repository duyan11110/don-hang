using DonHang.Domain;
using Xunit;

namespace DonHang.Tests.Domain;

// lesson: design.l3.value-objects
// Vnd on its own: known only by its Amount, never negative, never changed.
public sealed class VndTests
{
    [Fact]
    public void TwoVndWithTheSameAmount_AreEqual()
    {
        var a = new Vnd(450_000);
        var b = new Vnd(450_000);

        Assert.Equal(a, b);
        Assert.True(a == b);
        Assert.False(ReferenceEquals(a, b));
    }

    [Fact]
    public void Constructor_NegativeAmount_Throws()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => new Vnd(-1));
    }

    [Fact]
    public void Plus_ReturnsANewVnd_AndChangesNeither()
    {
        var price = new Vnd(450_000);
        var fee = new Vnd(30_000);

        var total = price.Plus(fee);

        Assert.Equal(new Vnd(480_000), total);
        Assert.Equal(new Vnd(450_000), price);
        Assert.Equal(new Vnd(30_000), fee);
    }

    [Fact]
    public void Times_MultipliesByAQuantity()
    {
        Assert.Equal(new Vnd(900_000), new Vnd(450_000).Times(2));
    }
}
