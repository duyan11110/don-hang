namespace DonHang.Domain;

// lesson: backend.l1.efcore-mapping
// One class per table in db/schema.sql that Ordering still uses. From stage-3
// `products` belongs to the Catalog module (DonHang.Catalog), and `payments`
// and `notifications` to the Payments and Notifications services, which keep
// them in databases of their own. No behaviour here beyond what a row is,
// except Order, which owns the rules about its own status.
public sealed class Customer
{
    public int Id { get; set; }
    public required string FullName { get; set; }
    public required string Email { get; set; }
    public required string City { get; set; }

    // lesson: backend.l2.validating-provider-tokens
    // Keycloak's id for this customer (the `sub` of their tokens); null until they have an account there.
    public string? IdentitySubject { get; set; }
}

// lesson: backend.l1.efcore-relationships-and-keys
// lesson: design.l2.ef-core-and-private-setters
// Id keeps a public setter: from stage-3 EfOrderRepository.AddAsync takes it
// from the database's id sequence, and FakeOrderRepository.AddAsync assigns
// it the same way, before the order is saved. So does Customer, a
// navigation used only for reading; IdempotencyKey can be given only while
// the order is created (init). Everything else changes only through the
// constructor and the methods below.
public sealed class Order
{
    public int Id { get; set; }
    public int CustomerId { get; private set; }
    public DateTimeOffset PlacedAt { get; private set; }
    public string Status { get; private set; }

    // lesson: design.l3.aggregate-root
    // The items live in this private list; outside code gets only a read-only
    // view of it, so nothing but Order can add, remove or clear an item.
    // EF Core reads and writes the list itself (DonHangDbContext says so).
    private readonly List<OrderItem> items = [];
    public IReadOnlyList<OrderItem> Items => items.AsReadOnly();

    // lesson: design.l3.domain-events
    // What has happened to this order since it was created or loaded. Order
    // only records an event; it calls no one. DomainEventDispatcher hands the
    // events to their handlers and then clears them. Not stored: EF Core ignores it.
    private readonly List<IDomainEvent> domainEvents = [];
    public IReadOnlyList<IDomainEvent> DomainEvents => domainEvents.AsReadOnly();

    public void ClearDomainEvents() => domainEvents.Clear();

    // lesson: backend.l2.idempotent-endpoints
    // The client's Idempotency-Key, stored in the same row as the order it
    // created; null when the client sent none. A unique index guards it.
    public string? IdempotencyKey { get; init; }

    // lesson: backend.l2.optimistic-concurrency
    // Not a column Đơn Hàng adds: DonHangDbContext maps this to PostgreSQL's
    // xmin system column, which changes every time the row is updated.
    public uint Version { get; private set; }

    // lesson: backend.l1.efcore-n-plus-one
    public Customer? Customer { get; set; }

    // lesson: design.l2.ef-core-and-private-setters
    // For EF Core only. It cannot pass the Items navigation to the public
    // constructor, so it creates the object with this one and then sets each
    // mapped property from the row it loaded — the checks below do not run.
    private Order()
    {
        Status = "";
    }

    // lesson: design.l2.valid-from-construction
    // lesson: design.l3.aggregate-root
    // The items are copied into Order's own list before they are checked, so
    // a caller that changes or clears its list afterwards changes nothing here.
    public Order(int customerId, IEnumerable<OrderItem> items, DateTimeOffset placedAt)
    {
        this.items.AddRange(items);
        if (this.items.Count == 0) throw new ArgumentException("an order needs at least one item");
        if (this.items.Any(item => item.Quantity < 1)) throw new ArgumentException("every item needs a quantity of at least 1");

        CustomerId = customerId;
        PlacedAt = placedAt;
        Status = "new";
        domainEvents.Add(new OrderPlaced(this, placedAt));
    }

    // lesson: design.l3.value-objects
    // Worked out from the items each time it is read; it is not a column.
    public Vnd Total
    {
        get
        {
            var total = Vnd.Zero;
            foreach (var item in items)
            {
                total = total.Plus(item.UnitPrice.Times(item.Quantity));
            }

            return total;
        }
    }

    // lesson: design.l2.status-changes-through-methods
    // One method per allowed change, each checking the status it starts from.
    // No endpoint takes payments at stage-2; OrderTests uses this to get a paid order.
    public void MarkPaid()
    {
        if (Status == "cancelled") throw new OrderStatusException(Id, "already-cancelled", $"order {Id} is cancelled");
        if (Status != "new") throw new OrderStatusException(Id, "already-paid", $"order {Id} is already paid");
        Status = "paid";
    }

    // lesson: design.l2.domain-model
    // lesson: backend.l3.saga-in-progress-status
    // From stage-3 a paid order is not cancelled here: its money must go back
    // first, so it leaves through RequestRefund and the refund saga instead.
    // A refund in progress blocks cancelling, like it blocks shipping.
    public void Cancel()
    {
        if (Status == "cancelled") throw new OrderStatusException(Id, "already-cancelled", $"order {Id} is already cancelled");
        if (Status == "shipped") throw new OrderStatusException(Id, "already-shipped", $"order {Id} has already shipped");
        if (Status == "paid") throw new OrderStatusException(Id, "paid", $"order {Id} is paid; request a refund instead");
        if (Status == "refunding") throw new OrderStatusException(Id, "refund-in-progress", $"order {Id} is being refunded");
        Status = "cancelled";

        // lesson: design.l3.domain-events
        // Recorded only after the change is made: a refused Cancel() throws
        // above and records nothing.
        domainEvents.Add(new OrderCancelled(this, DateTimeOffset.UtcNow));
    }

    public void Ship()
    {
        if (Status == "cancelled") throw new OrderStatusException(Id, "already-cancelled", $"order {Id} is cancelled");
        if (Status == "shipped") throw new OrderStatusException(Id, "already-shipped", $"order {Id} has already shipped");
        if (Status == "refunding") throw new OrderStatusException(Id, "refund-in-progress", $"order {Id} is being refunded");
        if (Status != "paid") throw new OrderStatusException(Id, "not-paid", $"order {Id} is not paid yet");
        Status = "shipped";
        domainEvents.Add(new OrderShipped(this, DateTimeOffset.UtcNow));
    }

    // lesson: backend.l3.saga-in-progress-status
    // lesson: backend.l3.saga
    // The first step of the refund saga. Only a paid order can ask for its
    // money back; `refunding` then tells every other request that a refund is
    // under way, so a second refund, a cancel or a ship is refused meanwhile.
    public void RequestRefund()
    {
        if (Status == "refunding") throw new OrderStatusException(Id, "refund-in-progress", $"order {Id} is already being refunded");
        if (Status != "paid") throw new OrderStatusException(Id, "not-paid", $"order {Id} is not paid, so there is nothing to refund");
        Status = "refunding";
        domainEvents.Add(new OrderRefundRequested(this, DateTimeOffset.UtcNow));
    }

    // lesson: backend.l3.saga
    // The gateway has returned the money (payment.refunded): the order ends
    // as cancelled, which is what the customer asked for.
    public void CompleteRefund()
    {
        if (Status != "refunding") throw new OrderStatusException(Id, "not-refunding", $"order {Id} is not being refunded");
        Status = "cancelled";
        domainEvents.Add(new OrderRefunded(this, DateTimeOffset.UtcNow));
    }

    // lesson: backend.l3.compensating-action
    // The gateway refused the refund (payment.refund-failed). The order's own
    // step cannot be rolled back, it was committed long ago, so a new change
    // undoes its effect: the order is paid again and can still ship.
    public void FailRefund()
    {
        if (Status != "refunding") throw new OrderStatusException(Id, "not-refunding", $"order {Id} is not being refunded");
        Status = "paid";
        domainEvents.Add(new OrderRefundFailed(this, DateTimeOffset.UtcNow));
    }
}

// lesson: design.l3.aggregate-root
// Every value comes through the constructor and nothing has a public setter,
// so once Order has checked an item, no code can change it. EF Core sets
// OrderId when it saves the order, and uses this same constructor to load.
public sealed class OrderItem(int productId, int quantity, Vnd unitPrice)
{
    public int OrderId { get; private set; }
    public int ProductId { get; private set; } = productId;
    public int Quantity { get; private set; } = quantity;

    // lesson: design.l3.value-objects
    // Was `int UnitPriceVnd` until stage-2: any int, even a negative one.
    public Vnd UnitPrice { get; private set; } = unitPrice;
}
