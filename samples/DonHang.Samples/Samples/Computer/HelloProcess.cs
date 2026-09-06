namespace DonHang.Samples.Computer;

// lesson: foundation.l1.program-to-process
public static class HelloProcess
{
    public static void Run()
    {
        var process = System.Diagnostics.Process.GetCurrentProcess();

        Console.WriteLine($"process id: {process.Id}");
        Console.WriteLine($"started from: {Environment.ProcessPath}");
        Console.WriteLine($"working directory: {Environment.CurrentDirectory}");
        Console.WriteLine("this process ends when Main returns, and reports 0");
    }
}
