using DonHang.Domain;
using Microsoft.EntityFrameworkCore;

namespace DonHang.Infrastructure;

// The notifications table read as a job queue. NotificationSender claims a
// batch, works on it, then completes it; one scope, one DbContext per batch.
public sealed class NotificationQueue(DonHangDbContext db)
{
    // lesson: backend.l2.skip-locked-claiming
    // Opens a transaction and locks up to batchSize due, pending rows with
    // FOR UPDATE. SKIP LOCKED passes over rows another copy of the api has
    // already locked, so two senders never claim the same row. The locks
    // last until CompleteAsync commits; if the api dies first, PostgreSQL
    // rolls the transaction back and the rows are pending for the next claim.
    public async Task<List<Notification>> ClaimDueAsync(int batchSize, CancellationToken cancellationToken)
    {
        await db.Database.BeginTransactionAsync(cancellationToken);
        var now = DateTimeOffset.UtcNow;
        return await db.Notifications
            .FromSql($"""
                SELECT * FROM notifications
                WHERE status = 'pending' AND next_attempt_at <= {now}
                ORDER BY next_attempt_at, id
                LIMIT {batchSize}
                FOR UPDATE SKIP LOCKED
                """)
            .Include(n => n.Order!).ThenInclude(o => o.Customer)
            .ToListAsync(cancellationToken);
    }

    // Saves what the sender changed on the claimed rows and releases their locks.
    public async Task CompleteAsync(CancellationToken cancellationToken)
    {
        await db.SaveChangesAsync(cancellationToken);
        await db.Database.CommitTransactionAsync(cancellationToken);
    }
}
