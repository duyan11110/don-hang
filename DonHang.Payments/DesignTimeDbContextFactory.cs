using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace DonHang.Payments;

// Used only by `dotnet ef migrations add` and `migrations bundle`, so they
// need not start the whole service to build its model.
public sealed class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<PaymentsDbContext>
{
    public PaymentsDbContext CreateDbContext(string[] args)
    {
        var builder = new DbContextOptionsBuilder<PaymentsDbContext>();
        builder.UseNpgsql("Host=localhost;Database=donhang_payments;Username=donhang;Password=design-time-only");
        return new PaymentsDbContext(builder.Options);
    }
}
