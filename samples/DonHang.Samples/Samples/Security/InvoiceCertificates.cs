using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;

namespace DonHang.Samples.Security;

// A root certificate authority for Đơn Hàng and the certificate that binds
// the name of the invoice signer to its public key. Everything is made in
// memory for the lab; ADR 0015 keeps the real keys in an HSM.
public static class InvoiceCertificates
{
    public const string InvoiceSubject = "CN=Don Hang invoices";

    // lesson: backend.l4.pki-and-signing
    // The root may only certify other keys (keyCertSign), and is a CA
    // (basic constraints); it signs itself, so nothing vouches for it but
    // the verifiers that choose to trust it.
    public static X509Certificate2 CreateRoot(string subject = "CN=Don Hang root CA")
    {
        var key = ECDsa.Create(ECCurve.NamedCurves.nistP256);
        var request = new CertificateRequest(subject, key, HashAlgorithmName.SHA256);
        request.CertificateExtensions.Add(new X509BasicConstraintsExtension(true, false, 0, true));
        request.CertificateExtensions.Add(new X509KeyUsageExtension(X509KeyUsageFlags.KeyCertSign, true));
        request.CertificateExtensions.Add(new X509SubjectKeyIdentifierExtension(request.PublicKey, false));
        var now = DateTimeOffset.UtcNow;
        return request.CreateSelfSigned(now.AddDays(-1), now.AddYears(10));
    }

    // lesson: backend.l4.pki-and-signing
    // The invoice certificate is not a CA, and its key may only make digital
    // signatures (critical: a verifier that does not understand the
    // extension must reject the certificate). The root signs it.
    public static X509Certificate2 IssueInvoiceCertificate(X509Certificate2 root, ECDsa invoiceKey)
    {
        var request = new CertificateRequest(InvoiceSubject, invoiceKey, HashAlgorithmName.SHA256);
        request.CertificateExtensions.Add(new X509BasicConstraintsExtension(false, false, 0, true));
        request.CertificateExtensions.Add(new X509KeyUsageExtension(X509KeyUsageFlags.DigitalSignature, true));
        request.CertificateExtensions.Add(X509AuthorityKeyIdentifierExtension.CreateFromCertificate(root, true, false));
        var now = DateTimeOffset.UtcNow;
        return request.Create(root, now.AddHours(-1), now.AddYears(2), RandomNumberGenerator.GetBytes(16));
    }

    // lesson: backend.l4.pki-and-signing
    // The verifier trusts one root, Đơn Hàng's, and nothing from the
    // machine's own store. The chain must lead from the certificate to that
    // root, every signature checked on the way. RevocationMode.NoCheck: the
    // lab publishes no CRL or OCSP responder to ask whether it was revoked.
    public static bool IsTrusted(X509Certificate2 certificate, X509Certificate2 trustedRoot)
    {
        using var chain = new X509Chain();
        chain.ChainPolicy.TrustMode = X509ChainTrustMode.CustomRootTrust;
        chain.ChainPolicy.CustomTrustStore.Add(trustedRoot);
        chain.ChainPolicy.RevocationMode = X509RevocationMode.NoCheck;
        return chain.Build(certificate);
    }
}
