using DonHang.Domain;
using Xunit;

namespace DonHang.Tests.Architecture;

// lesson: design.l2.testing-the-dependency-rule
// An architecture test: it checks what DonHang.Domain is built against, not
// what its code does. The core may use .NET itself and nothing outer.
// From stage-3 that includes DonHang.Catalog: Ordering's core asks for prices
// through its own IProductPrices, never through Catalog's types. Nor does it
// see RabbitMQ or the outbox table: only its own IOutbox.
public sealed class DependencyRuleTests
{
    private static readonly string[] ForbiddenPrefixes =
    [
        "DonHang.Infrastructure",
        "DonHang.Api",
        "DonHang.Catalog",
        "DonHang.Messaging",
        "RabbitMQ",
        "Microsoft.EntityFrameworkCore",
        "Microsoft.AspNetCore",
        "Npgsql",
        "StackExchange.Redis",
        "MailKit",
    ];

    [Fact]
    public void DomainReferencesNoOuterAssembly()
    {
        var referenced = typeof(OrderService).Assembly.GetReferencedAssemblies();

        var forbidden = referenced
            .Select(assembly => assembly.Name!)
            .Where(name => ForbiddenPrefixes.Any(prefix => name.StartsWith(prefix)))
            .ToList();

        Assert.Empty(forbidden);
    }
}
