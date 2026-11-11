using System;
using System.Diagnostics;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Linkie.App;

internal static class Shell
{
    /// <summary>명령을 창 없이 실행해 표준 출력을 돌려준다. 실행 실패·비정상 종료·타임아웃이면 null.</summary>
    public static async Task<string?> RunAsync(string fileName, string[] arguments, TimeSpan timeout)
    {
        var info = new ProcessStartInfo(fileName)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8,
        };
        foreach (var argument in arguments) info.ArgumentList.Add(argument);

        try
        {
            using var process = Process.Start(info);
            if (process is null) return null;

            using var cancel = new CancellationTokenSource(timeout);
            // 파이프 버퍼가 차서 멈추지 않도록 두 스트림을 모두 끝까지 읽는다.
            var stdout = process.StandardOutput.ReadToEndAsync(cancel.Token);
            var stderr = process.StandardError.ReadToEndAsync(cancel.Token);
            try
            {
                await process.WaitForExitAsync(cancel.Token);
                var output = await stdout;
                await stderr;
                return process.ExitCode == 0 ? output : null;
            }
            catch (OperationCanceledException)
            {
                try { process.Kill(entireProcessTree: true); } catch { /* 이미 끝났으면 무시 */ }
                return null;
            }
        }
        catch (Exception)
        {
            return null;
        }
    }
}
