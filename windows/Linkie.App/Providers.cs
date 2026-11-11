using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Linkie.Core;

namespace Linkie.App;

internal static class AndroidProvider
{
    public static string? FindAdb()
    {
        var candidates = new List<string>();
        foreach (var key in new[] { "ANDROID_HOME", "ANDROID_SDK_ROOT" })
        {
            var root = Environment.GetEnvironmentVariable(key);
            if (!string.IsNullOrEmpty(root)) candidates.Add(Path.Combine(root, "platform-tools", "adb.exe"));
        }
        candidates.Add(Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Android", "Sdk", "platform-tools", "adb.exe"));
        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator))
        {
            if (!string.IsNullOrWhiteSpace(dir)) candidates.Add(Path.Combine(dir.Trim(), "adb.exe"));
        }
        return candidates.FirstOrDefault(File.Exists);
    }

    /// <summary>adb 가 없으면 빈 목록, 명령이 실패하면 null(직전 값 유지).</summary>
    public static async Task<List<Device>?> FetchAsync(Dictionary<string, string> nameCache)
    {
        var adb = FindAdb();
        if (adb is null) return new List<Device>();

        var output = await Shell.RunAsync(adb, new[] { "devices", "-l" }, TimeSpan.FromSeconds(5));
        if (output is null) return null;

        var devices = new List<Device>();
        foreach (var entry in AdbParser.ParseDevices(output))
        {
            int? battery = null;
            if (entry.State == "device")
            {
                if (!nameCache.ContainsKey(entry.Serial))
                {
                    var raw = await Shell.RunAsync(
                        adb,
                        new[] { "-s", entry.Serial, "shell", "settings", "get", "global", "device_name" },
                        TimeSpan.FromSeconds(3));
                    var name = raw?.Trim();
                    if (!string.IsNullOrEmpty(name) && name != "null") nameCache[entry.Serial] = name;
                }

                var dump = await Shell.RunAsync(
                    adb,
                    new[] { "-s", entry.Serial, "shell", "dumpsys", "battery" },
                    TimeSpan.FromSeconds(3));
                if (dump is not null) battery = AdbParser.ParseBatteryLevel(dump);
            }

            nameCache.TryGetValue(entry.Serial, out var friendlyName);
            devices.Add(AdbParser.ToDevice(entry, friendlyName, battery));
        }
        return devices;
    }
}

internal static class PnpProvider
{
    private static readonly Lazy<string> EncodedScript = new(() =>
    {
        using var stream = typeof(PnpProvider).Assembly.GetManifestResourceStream("pnp.ps1")
            ?? throw new InvalidOperationException("pnp.ps1 리소스를 찾을 수 없습니다.");
        using var reader = new StreamReader(stream, Encoding.UTF8);
        // -EncodedCommand 는 UTF-16LE 를 Base64 로 감싼 값을 받는다.
        return Convert.ToBase64String(Encoding.Unicode.GetBytes(reader.ReadToEnd()));
    });

    /// <summary>블루투스·USB 기기. 스크립트가 실패하면 null(직전 값 유지).</summary>
    public static async Task<PnpResult?> FetchAsync()
    {
        var powershell = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.System),
            "WindowsPowerShell", "v1.0", "powershell.exe");

        var output = await Shell.RunAsync(
            powershell,
            new[]
            {
                "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
                "-EncodedCommand", EncodedScript.Value,
            },
            TimeSpan.FromSeconds(20));
        return output is null ? null : PnpParser.Parse(output);
    }
}
