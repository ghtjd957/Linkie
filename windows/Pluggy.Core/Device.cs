namespace Pluggy.Core;

/// <summary>팝업의 섹션 단위.</summary>
public enum DeviceKind
{
    Dev,
    Bluetooth,
    Wired,
}

/// <summary>행 아이콘 색을 고르는 축. 실제 색은 화면 쪽이 정한다.</summary>
public enum DeviceAccent
{
    Android,
    Ios,
    Bluetooth,
    Usb,
}

/// <summary>행 아이콘 모양. 실제 글리프는 화면 쪽이 정한다.</summary>
public enum DeviceIcon
{
    Phone,
    Tablet,
    Keyboard,
    Mouse,
    Headphones,
    Speaker,
    Display,
    Gamepad,
    Drive,
    Camera,
    Bluetooth,
    Usb,
}

public sealed record Device(
    string Id,
    string Name,
    string Detail,
    DeviceKind Kind,
    DeviceAccent Accent,
    DeviceIcon Icon,
    // 0~100. 기기가 알려 줄 때만.
    int? Battery = null,
    // 행을 클릭했을 때 복사할 값(시리얼·주소).
    string? CopyText = null,
    // USB 목록과의 중복 제거에 쓰는 하드웨어 시리얼.
    string? Serial = null,
    // 연결은 됐지만 바로 쓸 수 없는 상태(디버깅 미승인 등).
    bool NeedsAttention = false);

public sealed record Section(DeviceKind Kind, IReadOnlyList<Device> Devices)
{
    public string Title => Kind switch
    {
        DeviceKind.Dev => "개발 기기",
        DeviceKind.Bluetooth => "블루투스",
        _ => "USB",
    };
}

public static class DeviceMerger
{
    /// <summary>시리얼 비교용 정규화 — 아이폰 UDID 는 출처에 따라 하이픈 유무가 다르다.</summary>
    public static string? NormalizeSerial(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return null;
        var cleaned = raw.Replace("-", "").Trim().ToUpperInvariant();
        return cleaned.Length == 0 ? null : cleaned;
    }

    /// <summary>
    /// 섹션으로 묶고, 케이블로 꽂은 개발 기기가 USB 목록에 한 번 더 나오는 것을 지운다. 빈 섹션은 뺀다.
    /// </summary>
    public static IReadOnlyList<Section> Merge(
        IEnumerable<Device> dev, IEnumerable<Device> bluetooth, IEnumerable<Device> wired)
    {
        var devList = dev.ToList();
        var devSerials = devList
            .Select(d => NormalizeSerial(d.Serial))
            .Where(s => s is not null)
            .ToHashSet();

        var uniqueWired = wired
            .Where(d => NormalizeSerial(d.Serial) is not { } serial || !devSerials.Contains(serial))
            .ToList();

        return new[]
            {
                new Section(DeviceKind.Dev, devList),
                new Section(DeviceKind.Bluetooth, bluetooth.ToList()),
                new Section(DeviceKind.Wired, uniqueWired),
            }
            .Where(s => s.Devices.Count > 0)
            .ToList();
    }

    public static bool SameContent(IReadOnlyList<Section> a, IReadOnlyList<Section> b) =>
        a.Count == b.Count
        && a.Zip(b).All(pair => pair.First.Kind == pair.Second.Kind
                                && pair.First.Devices.SequenceEqual(pair.Second.Devices));
}
