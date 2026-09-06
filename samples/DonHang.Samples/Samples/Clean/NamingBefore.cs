namespace DonHang.Samples.Clean;

// lesson: foundation.l1.naming
// Nothing here is wrong. Everything here has to be decoded.
public static class NamingBefore
{
    public static int Calc(List<(int q, int p)> l, bool f)
    {
        var t = 0;
        foreach (var x in l)
        {
            t += x.q * x.p;
        }

        if (f)
        {
            t -= t * 10 / 100;
        }

        return t;
    }
}
