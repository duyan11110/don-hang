using DonHang.Domain;
using DonHang.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using Xunit;

namespace DonHang.Tests.Integration;

// lesson: design.l2.class-fixtures
// lesson: design.l2.resetting-data-between-tests
// One PostgresFixture (one container) for every test in this class. Before
// each test, InitializeAsync empties the tables: the tests share a database,
// and xUnit does not promise to run them in the order they are written.
public sealed class EfOrderRepositoryTests(PostgresFixture database)
    : IClassFixture<PostgresFixture>, IAsyncLifetime
{
    public Task InitializeAsync() => database.ResetAsync();

    public Task DisposeAsync() => Task.CompletedTask;

    // lesson: design.l2.testing-the-real-repository
    // Save through one DbContext, read back through a new one: the second
    // context has tracked nothing, so the items can only come from
    // PostgreSQL, through FindAsync's query and its Include.
    [Fact]
    public async Task FindAsync_SavedOrderWithTwoItems_ReadsBothItemsBack()
    {
        int orderId;
        await using (var db = database.CreateContext())
        {
            var (customerId, penId, bookId) = await InsertCustomerAndProductsAsync(db);
            var repository = new EfOrderRepository(db);
            var order = new Order(customerId,
                [
                    new(penId, quantity: 2, new Vnd(15_000)),
                    new(bookId, quantity: 1, new Vnd(120_000)),
                ],
                DateTimeOffset.UtcNow);
            await repository.AddAsync(order);
            await repository.SaveChangesAsync();
            orderId = order.Id;
        }

        await using var readDb = database.CreateContext();
        var found = await new EfOrderRepository(readDb).FindAsync(orderId);

        Assert.NotNull(found);
        Assert.Equal("new", found.Status);
        Assert.Equal(2, found.Items.Count);
        Assert.Equal(new Vnd(150_000), found.Total);
    }

    // lesson: design.l2.testing-the-real-repository
    // What FakeOrderRepository accepts without complaint: PostgreSQL refuses
    // an order whose customer_id names no customer (the foreign key).
    [Fact]
    public async Task SaveChangesAsync_OrderForMissingCustomer_IsRefused()
    {
        await using var db = database.CreateContext();
        var (_, penId, _) = await InsertCustomerAndProductsAsync(db);
        var repository = new EfOrderRepository(db);
        await repository.AddAsync(new Order(customerId: -1,
            [new(penId, quantity: 1, new Vnd(15_000))], DateTimeOffset.UtcNow));

        var error = await Assert.ThrowsAsync<DbUpdateException>(repository.SaveChangesAsync);
        Assert.Equal(PostgresErrorCodes.ForeignKeyViolation, Assert.IsType<PostgresException>(error.InnerException).SqlState);
    }

    // lesson: design.l2.resetting-data-between-tests
    // Both tests insert this same customer, and customers.email is unique:
    // without the reset, whichever test ran second would fail here.
    // From stage-3 DonHangDbContext has no Products: `products` belongs to the
    // Catalog module, so the test adds its two rows with SQL.
    private static async Task<(int CustomerId, int PenId, int BookId)> InsertCustomerAndProductsAsync(DonHangDbContext db)
    {
        var customer = new Customer { FullName = "Test Customer", Email = "test.customer@example.com", City = "Hà Nội" };
        db.Add(customer);
        await db.SaveChangesAsync();
        var penId = await TestProducts.InsertAsync(db, "Pen", 15_000);
        var bookId = await TestProducts.InsertAsync(db, "Book", 120_000);
        return (customer.Id, penId, bookId);
    }
}
