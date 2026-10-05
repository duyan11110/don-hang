using DonHang.Domain;

namespace DonHang.Tests;

// Customer 1 of db/seed.sql, and no one else.
public sealed class FakeCustomerRepository : ICustomerRepository
{
    private static readonly Customer AnhTran = new()
    {
        Id = 1, FullName = "Trần Minh Anh", Email = "anh.tran@example.com", City = "Hà Nội",
    };

    public Task<Customer?> FindByIdentitySubjectAsync(string identitySubject) => Task.FromResult<Customer?>(null);

    public Task<Customer?> FindAsync(int id) => Task.FromResult(id == AnhTran.Id ? AnhTran : null);
}
