namespace DonHang.Notifications;

// lesson: backend.l3.message-broker
// One email to send, the same job queue row as at stage-2, now in the
// Notifications service's own database. It keeps the customer's email
// address and name from the message: there is no customers table here, and
// order_id is only a number, with no foreign key to a table this database
// does not have.
public sealed class Notification
{
    public int Id { get; set; }
    public int OrderId { get; set; }
    public required string Email { get; set; }
    public required string FullName { get; set; }
    public required string Channel { get; set; }
    public required string Subject { get; set; }
    public required string Status { get; set; }
    public int Attempts { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset NextAttemptAt { get; set; }
    public DateTimeOffset? SentAt { get; set; }
}
