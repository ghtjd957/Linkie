namespace Pluggy.Core;

public enum AdbTransport
{
    Usb,
    Wifi,
    Emulator,
}

/// <param name="State">device / unauthorized / offline …</param>
public sealed record AdbEntry(string Serial, string State, string? Model, AdbTransport Transport);

public static class AdbParser
{
    /// <summary><c>adb devices -l</c> 출력.</summary>
    public static IReadOnlyList<AdbEntry> ParseDevices(string output)
    {
        var entries = new List<AdbEntry>();
        foreach (var rawLine in output.Split('\n'))
        {
            var line = rawLine.Trim();
            if (line.Length == 0 || line.StartsWith("List of devices") || line.StartsWith('*')) continue;

            var fields = line.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
            if (fields.Length < 2) continue;

            var serial = fields[0];
            string? model = null;
            foreach (var field in fields.Skip(2))
            {
                if (field.StartsWith("model:")) model = field["model:".Length..].Replace('_', '-');
            }

            var transport =
                serial.StartsWith("emulator-") ? AdbTransport.Emulator
                : serial.Contains(':') || serial.Contains("._adb-tls-connect") ? AdbTransport.Wifi
                : AdbTransport.Usb;

            entries.Add(new AdbEntry(serial, fields[1], model, transport));
        }
        return entries;
    }

    /// <summary><c>dumpsys battery</c> 출력에서 <c>level:</c> 값.</summary>
    public static int? ParseBatteryLevel(string output)
    {
        foreach (var rawLine in output.Split('\n'))
        {
            var line = rawLine.Trim();
            if (!line.StartsWith("level:")) continue;
            return int.TryParse(line["level:".Length..].Trim(), out var level) ? level : null;
        }
        return null;
    }

    public static Device ToDevice(AdbEntry entry, string? friendlyName, int? battery)
    {
        var transportLabel = entry.Transport switch
        {
            AdbTransport.Usb => "USB",
            AdbTransport.Wifi => "Wi-Fi",
            _ => "에뮬레이터",
        };
        var stateLabel = entry.State switch
        {
            "device" => null,
            "unauthorized" => "USB 디버깅 승인 필요",
            "offline" => "오프라인",
            _ => entry.State,
        };

        var name = friendlyName ?? entry.Model ?? entry.Serial;
        var parts = new List<string>();
        if (entry.Model is not null && entry.Model != name) parts.Add(entry.Model);
        parts.Add(transportLabel);
        if (stateLabel is not null) parts.Add(stateLabel);

        return new Device(
            Id: $"adb:{entry.Serial}",
            Name: name,
            Detail: string.Join(" · ", parts),
            Kind: DeviceKind.Dev,
            Accent: DeviceAccent.Android,
            Icon: DeviceIcon.Phone,
            Battery: battery,
            CopyText: entry.Serial,
            Serial: entry.Transport == AdbTransport.Usb ? entry.Serial : null,
            NeedsAttention: entry.State != "device");
    }
}
