using DonHang.Catalog;
using DonHang.Messaging;
using DonHang.Notifications;
using DonHang.Payments;
using Xunit;

namespace DonHang.Tests.Architecture;

// lesson: design.l3.testing-module-boundaries
// The compiler already stops other projects from naming Catalog's `internal`
// types. These tests catch the two things it allows: a reference from Catalog
// to Ordering's projects, and one more type made public. From stage-3 they
// also keep the Notifications and Payments services apart from the rest.
public sealed class ModuleBoundaryTests
{
    private static readonly string[] ProjectsCatalogMustNotUse =
    [
        "DonHang.Domain",
        "DonHang.Infrastructure",
        "DonHang.Api",
    ];

    // Catalog's whole contract. Making another type public fails the test
    // below until this list changes too, so the pull request that widens the
    // contract shows it to its reviewers as an edit to this file.
    private static readonly string[] CatalogPublicTypes =
    [
        "CatalogModule",
        "CatalogProduct",
        "ICatalog",
    ];

    [Fact]
    public void CatalogUsesNoOrderingProject()
    {
        var referenced = typeof(ICatalog).Assembly.GetReferencedAssemblies()
            .Select(assembly => assembly.Name!)
            .Where(name => ProjectsCatalogMustNotUse.Contains(name))
            .ToList();

        Assert.Empty(referenced);
    }

    [Fact]
    public void CatalogMakesPublicOnlyItsContract()
    {
        var exported = typeof(ICatalog).Assembly.GetExportedTypes()
            .Select(type => type.Name)
            .Order()
            .ToList();

        Assert.Equal(CatalogPublicTypes, exported);
    }

    // lesson: backend.l3.message-broker
    // From stage-3 Notifications and Payments are services of their own: the
    // only Đơn Hàng project either may use is the shared DonHang.Messaging.
    // Everything else they know about an order arrives in a message.
    [Theory]
    [InlineData(typeof(OrderEventsConsumer))]
    [InlineData(typeof(RefundRequestedConsumer))]
    public void ServiceUsesNoDonHangProjectButMessaging(Type typeInTheService)
    {
        var referenced = typeInTheService.Assembly.GetReferencedAssemblies()
            .Select(assembly => assembly.Name!)
            .Where(name => name.StartsWith("DonHang.") && name != "DonHang.Messaging")
            .ToList();

        Assert.Empty(referenced);
    }

    // DonHang.Messaging is shared plumbing: it knows no order, payment or email.
    [Fact]
    public void MessagingUsesNoDonHangProject()
    {
        var referenced = typeof(OutboxMessage).Assembly.GetReferencedAssemblies()
            .Select(assembly => assembly.Name!)
            .Where(name => name.StartsWith("DonHang."))
            .ToList();

        Assert.Empty(referenced);
    }
}
