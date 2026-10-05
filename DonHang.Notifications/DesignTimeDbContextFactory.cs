using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace DonHang.Notifications;

// Used only by `dotnet ef migrations add` and `migrations bundle`, so they
// need not start the whole service to build its model.
public sealed class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<NotificationsDbContext>
{
    public NotificationsDbContext CreateDbContext(string[] args)
    {
        var builder = new DbContextOptionsBuilder<NotificationsDbContext>();
        builder.UseNpgsql("Host=localhost;Database=donhang_notifications;Username=donhang;Password=design-time-only");
        return new NotificationsDbContext(builder.Options);
    }
}
