using System;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace Pluggy.App;

public partial class PopupWindow : Window
{
    private readonly DeviceStore _store;

    /// <summary>바깥을 눌러 닫힌 시각 — 트레이 아이콘을 다시 눌렀을 때 곧바로 또 열리는 것을 막는다.</summary>
    public DateTime LastHiddenAt { get; private set; } = DateTime.MinValue;

    internal PopupWindow(DeviceStore store)
    {
        _store = store;
        InitializeComponent();
        ApplyTheme();

        _store.Changed += Render;
        Deactivated += (_, _) => HidePopup();
        SizeChanged += (_, _) => MoveNextToTray();
        Render();
    }

    public void ShowPopup()
    {
        ApplyTheme();
        LoginCheck.IsChecked = SystemSettings.LaunchAtLogin;
        Show();
        MoveNextToTray();
        Activate();
        _ = _store.RefreshNowAsync();
    }

    public void HidePopup()
    {
        if (!IsVisible) return;
        LastHiddenAt = DateTime.UtcNow;
        Hide();
    }

    private void Render()
    {
        var sections = _store.Sections.Select(s => new SectionViewModel(s)).ToList();
        SectionList.ItemsSource = sections;

        var total = _store.Total;
        CountText.Text = total.ToString();
        CountPill.Visibility = total > 0 ? Visibility.Visible : Visibility.Collapsed;
        ListScroll.Visibility = total > 0 ? Visibility.Visible : Visibility.Collapsed;
        EmptyState.Visibility = total > 0 ? Visibility.Collapsed : Visibility.Visible;
        RefreshButton.Opacity = _store.IsRefreshing ? 0.4 : 1.0;
    }

    /// <summary>작업 표시줄을 뺀 화면의 오른쪽 아래 구석에 붙인다.</summary>
    private void MoveNextToTray()
    {
        var area = SystemParameters.WorkArea;
        Left = area.Right - ActualWidth;
        Top = area.Bottom - ActualHeight;
    }

    private void ApplyTheme()
    {
        var light = SystemSettings.AppsUseLightTheme;
        Resources["PanelBrush"] = light ? Palette.Brush(0xFA, 0xF6, 0xF6, 0xF8) : Palette.Brush(0xF7, 0x22, 0x23, 0x2A);
        Resources["OutlineBrush"] = light ? Palette.Brush(0x1F, 0x00, 0x00, 0x00) : Palette.Brush(0x24, 0xFF, 0xFF, 0xFF);
        Resources["TextBrush"] = light ? Palette.Brush(0xFF, 0x1C, 0x1C, 0x1E) : Palette.Brush(0xFF, 0xF2, 0xF2, 0xF7);
        Resources["SubBrush"] = light ? Palette.Brush(0x99, 0x1C, 0x1C, 0x1E) : Palette.Brush(0x99, 0xF2, 0xF2, 0xF7);
        Resources["FaintBrush"] = light ? Palette.Brush(0x66, 0x1C, 0x1C, 0x1E) : Palette.Brush(0x66, 0xF2, 0xF2, 0xF7);
        Resources["HoverBrush"] = light ? Palette.Brush(0x12, 0x00, 0x00, 0x00) : Palette.Brush(0x14, 0xFF, 0xFF, 0xFF);
    }

    private async void Row_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button { DataContext: RowViewModel row } || row.CopyText is null) return;
        try
        {
            Clipboard.SetText(row.CopyText);
        }
        catch (Exception)
        {
            return; // 다른 프로그램이 클립보드를 잡고 있으면 조용히 넘어간다.
        }
        row.Copied = true;
        await Task.Delay(1400);
        row.Copied = false;
    }

    private void Refresh_Click(object sender, RoutedEventArgs e) => _ = _store.RefreshNowAsync();

    private void LoginCheck_Click(object sender, RoutedEventArgs e)
    {
        SystemSettings.LaunchAtLogin = LoginCheck.IsChecked == true;
        LoginCheck.IsChecked = SystemSettings.LaunchAtLogin; // 실패했으면 실제 상태로 되돌린다.
    }

    private void Quit_Click(object sender, RoutedEventArgs e) => Application.Current.Shutdown();
}
