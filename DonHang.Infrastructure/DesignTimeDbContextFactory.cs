using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace DonHang.Infrastructure;

// lesson: backend.l1.migrations
// Used only by `dotnet ef migrations add`/`database update` at design time —
// it never runs when DonHang.Api starts (Program.cs builds the real options).
public sealed class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<DonHangDbContext>
{
    public DonHangDbContext CreateDbContext(string[] args)
    {
        var builder = new DbContextOptionsBuilder<DonHangDbContext>();
        builder.UseNpgsql("Host=localhost;Database=donhang;Username=donhang;Password=design-time-only");
        return new DonHangDbContext(builder.Options);
    }
}
