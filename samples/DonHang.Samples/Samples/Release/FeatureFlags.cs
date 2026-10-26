using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text;

namespace DonHang.Samples.Release;

// A flag is off (0), on (100) or on for a share of customers in between.
// The api has no flags at stage-4: this sample and docs/design/feature-flags.md
// are the convention it will follow.
public sealed record FeatureFlag(string Name, int PercentOfCustomers)
{
    public static FeatureFlag Off(string name) => new(name, 0);

    public static FeatureFlag On(string name) => new(name, 100);
}

public static class FeatureFlags
{
    // lesson: devops.l4.feature-flags
    // Each customer gets a number from 0 to 99 for each flag, and the flag is
    // on for them when that number is below the percentage: raising it only
    // adds customers. The number comes from SHA-256 of the flag's name and
    // the customer id, the same on every run and every machine; a string's
    // GetHashCode changes from one process to the next.
    public static bool IsOn(FeatureFlag flag, int customerId) => flag.PercentOfCustomers switch
    {
        <= 0 => false,
        >= 100 => true,
        var percent => Bucket(flag.Name, customerId) < percent,
    };

    public static int Bucket(string flagName, int customerId)
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes($"{flagName}:{customerId}"));
        return (int)(BinaryPrimitives.ReadUInt32BigEndian(hash) % 100);
    }
}
