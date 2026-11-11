using System;
using System.Threading;
using System.Windows;

namespace Tether.App;

public partial class App : Application
{
    private Mutex? _singleInstance;
    private DeviceStore? _store;
    private TrayIcon? _tray;
    private PopupWindow? _popup;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        _singleInstance = new Mutex(initiallyOwned: true, @"Local\Tether.Tray", out var isFirst);
        if (!isFirst)
        {
            Shutdown();
            return;
        }

        _store = new DeviceStore();
        _popup = new PopupWindow(_store);
        _tray = new TrayIcon();

        _store.Changed += () => _tray.SetCount(_store.Total);
        _tray.Clicked += TogglePopup;
        _tray.RefreshRequested += () => _ = _store.RefreshNowAsync();
        _tray.QuitRequested += Shutdown;

        _store.Start();
    }

    private void TogglePopup()
    {
        if (_popup is null) return;
        if (_popup.IsVisible)
        {
            _popup.HidePopup();
            return;
        }
        // 아이콘을 누르는 순간 팝업이 포커스를 잃고 닫히므로, 방금 닫혔다면 다시 열지 않는다.
        if (DateTime.UtcNow - _popup.LastHiddenAt < TimeSpan.FromMilliseconds(300)) return;
        _popup.ShowPopup();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _tray?.Dispose();
        _singleInstance?.Dispose();
        base.OnExit(e);
    }
}
