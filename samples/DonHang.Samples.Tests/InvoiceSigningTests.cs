using System.Security.Cryptography;
using System.Text;
using DonHang.Samples.Security;
using Xunit;

namespace DonHang.Samples.Tests;

public class InvoiceSigningTests
{
    private static readonly byte[] InvoiceBytes = InvoiceSigning.ToBytes(InvoiceSigning.SeedOrder1());

    // lesson: backend.l4.signing-documents
    // The public key alone checks the signature; one changed amount in the
    // signed bytes, or a public key from another pair, and the check fails.
    [Fact]
    public void Signature_VerifiesWithThePublicKeyAlone()
    {
        using var key = InvoiceSigning.NewKey();
        var signature = InvoiceSigning.Sign(InvoiceBytes, key);

        Assert.True(InvoiceSigning.Verify(InvoiceBytes, signature, key.ExportSubjectPublicKeyInfo()));
    }

    [Fact]
    public void Signature_FailsWhenAnAmountChanges()
    {
        using var key = InvoiceSigning.NewKey();
        var signature = InvoiceSigning.Sign(InvoiceBytes, key);

        var changed = Encoding.UTF8.GetBytes(Encoding.UTF8.GetString(InvoiceBytes).Replace("2150000", "2150001"));

        Assert.NotEqual(InvoiceBytes, changed);
        Assert.False(InvoiceSigning.Verify(changed, signature, key.ExportSubjectPublicKeyInfo()));
    }

    [Fact]
    public void Signature_FailsWithAnotherPublicKey()
    {
        using var key = InvoiceSigning.NewKey();
        using var other = InvoiceSigning.NewKey();
        var signature = InvoiceSigning.Sign(InvoiceBytes, key);

        Assert.False(InvoiceSigning.Verify(InvoiceBytes, signature, other.ExportSubjectPublicKeyInfo()));
    }

    // lesson: backend.l4.pki-and-signing
    // A chain that reaches the trusted root is accepted; a certificate with
    // the very same name, signed by another root, is not.
    [Fact]
    public void InvoiceCertificate_ChainsToTheTrustedRoot()
    {
        using var root = InvoiceCertificates.CreateRoot();
        using var key = InvoiceSigning.NewKey();
        using var certificate = InvoiceCertificates.IssueInvoiceCertificate(root, key);

        Assert.True(InvoiceCertificates.IsTrusted(certificate, root));
    }

    [Fact]
    public void SameSubjectFromAnotherRoot_IsNotTrusted()
    {
        using var root = InvoiceCertificates.CreateRoot();
        using var otherRoot = InvoiceCertificates.CreateRoot();
        using var key = InvoiceSigning.NewKey();
        using var forged = InvoiceCertificates.IssueInvoiceCertificate(otherRoot, key);

        Assert.Equal(InvoiceCertificates.InvoiceSubject, forged.Subject);
        Assert.False(InvoiceCertificates.IsTrusted(forged, root));
    }

    // The verifier takes the public key from the certificate it trusts, not
    // from whoever sent the invoice.
    [Fact]
    public void InvoiceSignature_VerifiesWithThePublicKeyFromTheCertificate()
    {
        using var root = InvoiceCertificates.CreateRoot();
        using var key = InvoiceSigning.NewKey();
        using var certificate = InvoiceCertificates.IssueInvoiceCertificate(root, key);
        var signature = InvoiceSigning.Sign(InvoiceBytes, key);

        Assert.True(InvoiceCertificates.IsTrusted(certificate, root));
        Assert.True(InvoiceSigning.Verify(InvoiceBytes, signature, certificate.PublicKey.ExportSubjectPublicKeyInfo()));
    }
}
