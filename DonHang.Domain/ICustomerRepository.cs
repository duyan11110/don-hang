namespace DonHang.Domain;

// lesson: backend.l2.validating-provider-tokens
// A token's `sub` is Keycloak's id for the user, not a customers.id: the
// customer is the row that stores that id in identity_subject.
public interface ICustomerRepository
{
    Task<Customer?> FindByIdentitySubjectAsync(string identitySubject);

    // lesson: backend.l3.message-broker
    // From stage-3: the email address and name every order message carries.
    Task<Customer?> FindAsync(int id);
}
