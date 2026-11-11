using System;
using System.Runtime.InteropServices;
using Drawing = System.Drawing;
using Drawing2D = System.Drawing.Drawing2D;
using WinForms = System.Windows.Forms;

namespace Pluggy.App;

/// <summary>작업 표시줄 알림 영역 아이콘. 연결된 기기 수를 아이콘 안에 그린다.</summary>
internal sealed class TrayIcon : IDisposable
{
    private readonly WinForms.NotifyIcon _icon;
    private readonly WinForms.ToolStripMenuItem _loginItem;
    private IntPtr _iconHandle = IntPtr.Zero;
    private int _count = -1;
    private bool _lightTaskbar;

    public event Action? Clicked;
    public event Action? RefreshRequested;
    public event Action? QuitRequested;

    public TrayIcon()
    {
        _loginItem = new WinForms.ToolStripMenuItem("로그인 시 실행") { CheckOnClick = true };
        _loginItem.Click += (_, _) => SystemSettings.LaunchAtLogin = _loginItem.Checked;

        var menu = new WinForms.ContextMenuStrip();
        menu.Opening += (_, _) => _loginItem.Checked = SystemSettings.LaunchAtLogin;
        menu.Items.Add("새로고침", null, (_, _) => RefreshRequested?.Invoke());
        menu.Items.Add(_loginItem);
        menu.Items.Add(new WinForms.ToolStripSeparator());
        menu.Items.Add("종료", null, (_, _) => QuitRequested?.Invoke());

        _icon = new WinForms.NotifyIcon { ContextMenuStrip = menu, Visible = true };
        _icon.MouseClick += (_, e) =>
        {
            if (e.Button == WinForms.MouseButtons.Left) Clicked?.Invoke();
        };
        SetCount(0);
    }

    public void SetCount(int count)
    {
        var lightTaskbar = SystemSettings.TaskbarUsesLightTheme;
        if (count == _count && lightTaskbar == _lightTaskbar) return;
        _count = count;
        _lightTaskbar = lightTaskbar;

        var previous = _iconHandle;
        _iconHandle = Draw(count, lightTaskbar);
        _icon.Icon = Drawing.Icon.FromHandle(_iconHandle);
        _icon.Text = $"연결된 기기 {count}개";
        if (previous != IntPtr.Zero) DestroyIcon(previous);
    }

    /// <summary>둥근 사각 테두리 안에 숫자. 작업 표시줄이 밝으면 검정, 어두우면 흰색.</summary>
    private static IntPtr Draw(int count, bool lightTaskbar)
    {
        const int size = 32;
        using var bitmap = new Drawing.Bitmap(size, size);
        using var graphics = Drawing.Graphics.FromImage(bitmap);
        graphics.SmoothingMode = Drawing2D.SmoothingMode.AntiAlias;
        graphics.TextRenderingHint = Drawing.Text.TextRenderingHint.AntiAliasGridFit;
        graphics.Clear(Drawing.Color.Transparent);

        var color = lightTaskbar ? Drawing.Color.Black : Drawing.Color.White;

        using var outline = RoundedRect(new Drawing.RectangleF(2.5f, 2.5f, size - 5f, size - 5f), 8f);
        using var pen = new Drawing.Pen(color, 2.6f);
        graphics.DrawPath(pen, outline);

        var text = count > 99 ? "99" : count.ToString();
        using var font = new Drawing.Font("Segoe UI", text.Length > 1 ? 13f : 16f,
            Drawing.FontStyle.Bold, Drawing.GraphicsUnit.Pixel);
        using var brush = new Drawing.SolidBrush(color);
        using var format = new Drawing.StringFormat
        {
            Alignment = Drawing.StringAlignment.Center,
            LineAlignment = Drawing.StringAlignment.Center,
        };
        graphics.DrawString(text, font, brush, new Drawing.RectangleF(0, 0, size, size), format);

        return bitmap.GetHicon();
    }

    private static Drawing2D.GraphicsPath RoundedRect(Drawing.RectangleF bounds, float radius)
    {
        var diameter = radius * 2;
        var path = new Drawing2D.GraphicsPath();
        path.AddArc(bounds.X, bounds.Y, diameter, diameter, 180, 90);
        path.AddArc(bounds.Right - diameter, bounds.Y, diameter, diameter, 270, 90);
        path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(bounds.X, bounds.Bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }

    public void Dispose()
    {
        _icon.Visible = false;
        _icon.Dispose();
        if (_iconHandle != IntPtr.Zero) DestroyIcon(_iconHandle);
        _iconHandle = IntPtr.Zero;
    }

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool DestroyIcon(IntPtr handle);
}
