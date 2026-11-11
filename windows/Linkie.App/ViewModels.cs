using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Windows;
using System.Windows.Media;
using Linkie.Core;

namespace Linkie.App;

internal static class Palette
{
    public static SolidColorBrush Brush(byte a, byte r, byte g, byte b)
    {
        var brush = new SolidColorBrush(Color.FromArgb(a, r, g, b));
        brush.Freeze();
        return brush;
    }

    private static Color AccentColor(DeviceAccent accent) => accent switch
    {
        DeviceAccent.Android => Color.FromRgb(0x30, 0xB8, 0x55),
        DeviceAccent.Ios => Color.FromRgb(0x0A, 0x84, 0xFF),
        DeviceAccent.Bluetooth => Color.FromRgb(0x32, 0xAD, 0xE6),
        _ => Color.FromRgb(0xFF, 0x37, 0x5F),
    };

    public static SolidColorBrush Accent(DeviceAccent accent)
    {
        var c = AccentColor(accent);
        return Brush(0xFF, c.R, c.G, c.B);
    }

    public static SolidColorBrush AccentFill(DeviceAccent accent)
    {
        var c = AccentColor(accent);
        return Brush(0x30, c.R, c.G, c.B);
    }

    public static readonly SolidColorBrush Good = Brush(0xFF, 0x30, 0xB8, 0x55);
    public static readonly SolidColorBrush GoodFill = Brush(0x30, 0x30, 0xB8, 0x55);
    public static readonly SolidColorBrush Warn = Brush(0xFF, 0xF5, 0x8A, 0x1F);
    public static readonly SolidColorBrush WarnFill = Brush(0x30, 0xF5, 0x8A, 0x1F);

    /// <summary>Segoe Fluent Icons / Segoe MDL2 Assets 공통 글리프.</summary>
    public static string Glyph(DeviceIcon icon) => icon switch
    {
        DeviceIcon.Phone => "",
        DeviceIcon.Tablet => "",
        DeviceIcon.Keyboard => "",
        DeviceIcon.Mouse => "",
        DeviceIcon.Headphones => "",
        DeviceIcon.Speaker => "",
        DeviceIcon.Display => "",
        DeviceIcon.Gamepad => "",
        DeviceIcon.Drive => "",
        DeviceIcon.Camera => "",
        DeviceIcon.Bluetooth => "",
        _ => "",
    };
}

public sealed class RowViewModel : INotifyPropertyChanged
{
    private readonly Device _device;
    private bool _copied;

    public RowViewModel(Device device)
    {
        _device = device;
        Accent = Palette.Accent(device.Accent);
        AccentFill = Palette.AccentFill(device.Accent);
        Glyph = Palette.Glyph(device.Icon);

        var low = device.Battery is <= 20;
        BatteryBrush = low ? Palette.Warn : Palette.Good;
        BatteryFill = low ? Palette.WarnFill : Palette.GoodFill;
        DotBrush = device.NeedsAttention ? Palette.Warn : Palette.Good;
    }

    public string Name => _device.Name;
    public string? CopyText => _device.CopyText;
    public string Glyph { get; }
    public Brush Accent { get; }
    public Brush AccentFill { get; }

    public string Detail => _copied ? $"복사됨 — {_device.CopyText}" : _device.Detail;

    public string BatteryText => _device.Battery is { } level ? $"{level}%" : "";
    public Brush BatteryBrush { get; }
    public Brush BatteryFill { get; }
    public Visibility BatteryVisibility => _device.Battery is null ? Visibility.Collapsed : Visibility.Visible;

    public Brush DotBrush { get; }
    public Visibility DotVisibility => _device.Battery is null ? Visibility.Visible : Visibility.Collapsed;

    public string ToolTip => _device.CopyText is { } text ? $"클릭해서 복사: {text}" : _device.Name;

    public bool Copied
    {
        get => _copied;
        set
        {
            if (_copied == value) return;
            _copied = value;
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(Detail)));
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(Copied)));
        }
    }

    public event PropertyChangedEventHandler? PropertyChanged;
}

public sealed class SectionViewModel
{
    public SectionViewModel(Section section)
    {
        Title = $"{section.Title} · {section.Devices.Count}";
        Rows = section.Devices.Select(d => new RowViewModel(d)).ToList();
    }

    public string Title { get; }
    public IReadOnlyList<RowViewModel> Rows { get; }
}
