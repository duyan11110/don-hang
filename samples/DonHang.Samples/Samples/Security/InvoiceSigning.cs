using System.Security.Cryptography;
using System.Text.Json;

namespace DonHang.Samples.Security;

public sealed record InvoiceLine(int ProductId, string Name, int Quantity, int UnitPriceVnd);

public sealed record Invoice(int OrderId, string CustomerName, DateTimeOffset PaidAt, IReadOnlyList<InvoiceLine> Lines, int TotalVnd);

// An invoice for a paid order, signed so that a customer or an auditor can
// check it with the public key alone. Đơn Hàng issues no invoices at stage-4:
// this is a sample, not a feature of the api.
public static class InvoiceSigning
{
    // Order 1 of db/seed.sql, paid by card on 2 March 2026.
    public static Invoice SeedOrder1() => new(
        OrderId: 1,
        CustomerName: "Trần Minh Anh",
        PaidAt: new DateTimeOffset(2026, 3, 2, 9, 20, 0, TimeSpan.FromHours(7)),
        Lines: [new(1, "Bàn phím cơ", 1, 1_250_000), new(2, "Chuột không dây", 2, 450_000)],
        TotalVnd: 2_150_000);

    // The bytes that get signed. They are made once and kept with the
    // signature: serialising the invoice again later may not give the same
    // bytes, and the signature covers these exact ones.
    public static byte[] ToBytes(Invoice invoice) => JsonSerializer.SerializeToUtf8Bytes(invoice, JsonSerializerOptions.Web);

    // A key pair made in memory, for the lab only: where the real key lives
    // and who may use it is ADR 0015 (an HSM only Payments can call).
    public static ECDsa NewKey() => ECDsa.Create(ECCurve.NamedCurves.nistP256);

    // lesson: backend.l4.signing-documents
    // lesson: backend.l4.signing-key-custody
    // Signing needs the private key: ECDsa over the SHA-256 hash of the bytes.
    // Checking needs only the public key, exported as SubjectPublicKeyInfo,
    // the form a certificate carries; the key that checks cannot sign.
    public static byte[] Sign(byte[] invoiceBytes, ECDsa privateKey) =>
        privateKey.SignData(invoiceBytes, HashAlgorithmName.SHA256);

    public static bool Verify(byte[] invoiceBytes, byte[] signature, byte[] publicKey)
    {
        using var key = ECDsa.Create();
        key.ImportSubjectPublicKeyInfo(publicKey, out _);
        return key.VerifyData(invoiceBytes, signature, HashAlgorithmName.SHA256);
    }
}
