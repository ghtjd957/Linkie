using System.Text.Json;

namespace Tether.Core;

public sealed record PnpResult(IReadOnlyList<Device> Bluetooth, IReadOnlyList<Device> Usb);

/// <summary>
/// <c>Scripts/pnp.ps1</c> 이 내보내는 JSON 을 읽는다.
/// <code>{ "bluetooth": [{ name, address, le, battery }], "usb": [{ name, vendor, serial, vid, pid }] }</code>
/// </summary>
public static class PnpParser
{
    private const string AppleVendorId = "05AC";

    public static PnpResult? Parse(string json)
    {
        JsonDocument doc;
        try
        {
            doc = JsonDocument.Parse(json);
        }
        catch (JsonException)
        {
            return null;
        }

        using (doc)
        {
            if (doc.RootElement.ValueKind != JsonValueKind.Object) return null;

            var bluetooth = Items(doc.RootElement, "bluetooth")
                .Select(ParseBluetooth)
                .OfType<Device>()
                .OrderBy(d => d.Name, StringComparer.OrdinalIgnoreCase)
                .ToList();
            var usb = Items(doc.RootElement, "usb")
                .Select(ParseUsb)
                .OfType<Device>()
                .ToList();
            return new PnpResult(bluetooth, usb);
        }
    }

    private static Device? ParseBluetooth(JsonElement item)
    {
        var name = Str(item, "name");
        if (name is null) return null;
        var address = Str(item, "address");
        var le = item.TryGetProperty("le", out var leValue) && leValue.ValueKind == JsonValueKind.True;

        return new Device(
            Id: $"bt:{address ?? name}",
            Name: name,
            Detail: le ? "블루투스 LE" : "블루투스",
            Kind: DeviceKind.Bluetooth,
            Accent: DeviceAccent.Bluetooth,
            Icon: IconForName(name, DeviceIcon.Bluetooth),
            Battery: Int(item, "battery"),
            CopyText: address is null ? null : FormatAddress(address));
    }

    private static Device? ParseUsb(JsonElement item)
    {
        var name = Str(item, "name");
        if (name is null) return null;
        var serial = Str(item, "serial");
        var vid = Str(item, "vid")?.ToUpperInvariant();
        var pid = Str(item, "pid")?.ToUpperInvariant();
        var vendor = CleanVendor(Str(item, "vendor"));

        var parts = new List<string>();
        if (vendor is not null && !name.Contains(vendor, StringComparison.OrdinalIgnoreCase)) parts.Add(vendor);
        parts.Add("USB");

        // 윈도우에는 Xcode 도구가 없어서, 케이블로 꽂은 아이폰·아이패드는 USB 목록에서 골라 개발 기기로 올린다.
        var isAppleMobile = vid == AppleVendorId
            && (name.Contains("iPhone", StringComparison.OrdinalIgnoreCase)
                || name.Contains("iPad", StringComparison.OrdinalIgnoreCase));

        return new Device(
            Id: $"usb:{vid}:{pid}:{serial ?? name}",
            Name: name,
            Detail: string.Join(" · ", parts),
            Kind: isAppleMobile ? DeviceKind.Dev : DeviceKind.Wired,
            Accent: isAppleMobile ? DeviceAccent.Ios : DeviceAccent.Usb,
            Icon: IconForName(name, DeviceIcon.Usb),
            CopyText: serial,
            Serial: serial);
    }

    public static DeviceIcon IconForName(string name, DeviceIcon fallback)
    {
        var lower = name.ToLowerInvariant();
        bool Has(params string[] words) => words.Any(lower.Contains);

        if (Has("ipad", "tablet", "tab ")) return DeviceIcon.Tablet;
        if (Has("iphone", "android", "phone", "galaxy", "pixel")) return DeviceIcon.Phone;
        if (Has("airpods", "earpods", "buds", "headphone", "headset", "earphone", "wh-", "wf-", "audio"))
            return DeviceIcon.Headphones;
        if (Has("speaker", "soundbar")) return DeviceIcon.Speaker;
        if (Has("keyboard", "keychron", "키보드")) return DeviceIcon.Keyboard;
        if (Has("mouse", "trackpad", "mx master", "마우스")) return DeviceIcon.Mouse;
        if (Has("monitor", "display")) return DeviceIcon.Display;
        if (Has("controller", "gamepad", "xbox", "dualsense", "dualshock")) return DeviceIcon.Gamepad;
        if (Has("camera", "webcam")) return DeviceIcon.Camera;
        if (Has("disk", "ssd", "storage", "drive", "flash")) return DeviceIcon.Drive;
        return fallback;
    }

    /// <summary>"Apple, Inc." → "Apple". "(표준 시스템 장치)" 같은 자리 채움 값은 버린다.</summary>
    public static string? CleanVendor(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return null;
        var vendor = raw.Trim();
        if (vendor.StartsWith('(')) return null;
        foreach (var suffix in new[] { ", Inc.", " Inc.", ", Ltd.", " Ltd.", " Co.,", " Corp.", " Corporation" })
        {
            vendor = vendor.Replace(suffix, "", StringComparison.OrdinalIgnoreCase);
        }
        vendor = vendor.Trim();
        return vendor.Length == 0 ? null : vendor;
    }

    /// <summary>"AABBCCDDEEFF" → "AA:BB:CC:DD:EE:FF"</summary>
    public static string FormatAddress(string raw)
    {
        var hex = new string(raw.Where(Uri.IsHexDigit).ToArray()).ToUpperInvariant();
        if (hex.Length != 12) return raw;
        return string.Join(':', Enumerable.Range(0, 6).Select(i => hex.Substring(i * 2, 2)));
    }

    // PowerShell 의 ConvertTo-Json 은 원소가 하나면 배열 대신 객체를, 없으면 null 을 낼 수 있다.
    private static IEnumerable<JsonElement> Items(JsonElement root, string property)
    {
        if (!root.TryGetProperty(property, out var value)) return [];
        return value.ValueKind switch
        {
            JsonValueKind.Array => value.EnumerateArray().Where(e => e.ValueKind == JsonValueKind.Object).ToList(),
            JsonValueKind.Object => [value],
            _ => [],
        };
    }

    private static string? Str(JsonElement item, string property)
    {
        if (!item.TryGetProperty(property, out var value) || value.ValueKind != JsonValueKind.String) return null;
        var text = value.GetString()?.Trim();
        return string.IsNullOrEmpty(text) ? null : text;
    }

    private static int? Int(JsonElement item, string property)
    {
        if (!item.TryGetProperty(property, out var value)) return null;
        if (value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var number)) return number;
        if (value.ValueKind == JsonValueKind.String && int.TryParse(value.GetString(), out var parsed)) return parsed;
        return null;
    }
}
