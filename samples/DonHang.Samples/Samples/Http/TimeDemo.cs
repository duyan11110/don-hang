namespace DonHang.Samples.Http;

// lesson: foundation.l1.time-and-timezones
public static class TimeDemo
{
    public static void Run()
    {
        // Order 12 of the lab data: early morning in Vietnam, yesterday in UTC.
        var placedAt = new DateTimeOffset(2026, 3, 31, 6, 20, 0, TimeSpan.FromHours(7));

        Console.WriteLine($"as stored and transmitted: {placedAt:o}");
        Console.WriteLine($"the same instant in UTC:   {placedAt.ToUniversalTime():o}");

        var vietnam = TimeZoneInfo.FindSystemTimeZoneById("Asia/Ho_Chi_Minh");
        var inVietnam = TimeZoneInfo.ConvertTime(placedAt, vietnam);

        Console.WriteLine($"the day this order belongs to in Vietnam: {inVietnam:yyyy-MM-dd}");
        Console.WriteLine($"the day the same order belongs to in UTC: {placedAt.UtcDateTime:yyyy-MM-dd}");
    }
}
