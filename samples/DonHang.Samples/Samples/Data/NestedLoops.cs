namespace DonHang.Samples.Data;

// lesson: foundation.l1.complexity-intro
public static class NestedLoops
{
    // Quadratic: for every order it walks the whole customer list again.
    public static int CountKnownCustomersSlowly(int[] orderCustomerIds, int[] customerIds)
    {
        var found = 0;
        foreach (var orderCustomerId in orderCustomerIds)
        {
            foreach (var customerId in customerIds)
            {
                if (orderCustomerId == customerId) found++;
            }
        }
        return found;
    }

    // Linear: the set is built once, and each question then costs the same.
    public static int CountKnownCustomersQuickly(int[] orderCustomerIds, int[] customerIds)
    {
        var known = new HashSet<int>(customerIds);
        return orderCustomerIds.Count(known.Contains);
    }

    public static void Run()
    {
        var orders = Enumerable.Range(1, 1_000).ToArray();
        var customers = Enumerable.Range(1, 1_000).ToArray();

        Console.WriteLine($"slow way: {CountKnownCustomersSlowly(orders, customers)} matches, 1000000 comparisons");
        Console.WriteLine($"fast way: {CountKnownCustomersQuickly(orders, customers)} matches, 1000 lookups");
    }
}
