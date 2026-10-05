using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace DonHang.Messaging;

// lesson: backend.l3.idempotent-consumer
// The save that failed because inbox_messages already holds this message id:
// PostgreSQL refused a second row with the same primary key (error 23505).
// The message was handled before, so the consumer acknowledges it and stops.
public static class Inbox
{
    public static bool IsDuplicate(DbUpdateException ex) =>
        ex.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation } postgres
        && postgres.ConstraintName == "PK_inbox_messages";
}
