using DonHang.Domain;
using Microsoft.EntityFrameworkCore;

namespace DonHang.Infrastructure;

public sealed class EfCustomerRepository(DonHangDbContext db) : ICustomerRepository
{
    public Task<Customer?> FindByIdentitySubjectAsync(string identitySubject) =>
        db.Customers.AsNoTracking().FirstOrDefaultAsync(c => c.IdentitySubject == identitySubject);

    public Task<Customer?> FindAsync(int id) =>
        db.Customers.AsNoTracking().FirstOrDefaultAsync(c => c.Id == id);
}
