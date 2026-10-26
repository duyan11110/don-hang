using DonHang.Samples.Release;
using Xunit;

namespace DonHang.Samples.Tests;

public class FeatureFlagsTests
{
    private static readonly int[] Customers = Enumerable.Range(1, 1000).ToArray();

    // lesson: devops.l4.feature-flags
    [Fact]
    public void SameCustomer_AlwaysGetsTheSameAnswer()
    {
        var flag = new FeatureFlag("new-checkout", 30);

        foreach (var customer in Customers)
            Assert.Equal(FeatureFlags.IsOn(flag, customer), FeatureFlags.IsOn(new FeatureFlag("new-checkout", 30), customer));
    }

    // lesson: devops.l4.feature-flags
    // Raising the percentage only adds customers: nobody who had the feature
    // at 10% loses it at 50%.
    [Fact]
    public void CustomersOnAt10Percent_AreStillOnAt50Percent()
    {
        var at10 = Customers.Where(c => FeatureFlags.IsOn(new FeatureFlag("new-checkout", 10), c)).ToList();
        var at50 = Customers.Where(c => FeatureFlags.IsOn(new FeatureFlag("new-checkout", 50), c)).ToHashSet();

        Assert.NotEmpty(at10);
        Assert.True(at50.Count > at10.Count);
        Assert.All(at10, customer => Assert.Contains(customer, at50));
    }

    [Fact]
    public void ZeroPercent_IsOffForAll_AndHundredPercent_IsOnForAll()
    {
        Assert.DoesNotContain(Customers, c => FeatureFlags.IsOn(FeatureFlag.Off("new-checkout"), c));
        Assert.All(Customers, c => Assert.True(FeatureFlags.IsOn(FeatureFlag.On("new-checkout"), c)));
    }
}
