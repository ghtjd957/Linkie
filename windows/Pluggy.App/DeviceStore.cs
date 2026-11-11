using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Pluggy.Core;

namespace Pluggy.App;

/// <summary>
/// 기기 목록의 정본. 모든 메서드는 UI 스레드에서 부른다 — await 뒤에도 UI 스레드로 돌아오므로 잠금이 필요 없다.
/// </summary>
internal sealed class DeviceStore
{
    public IReadOnlyList<Section> Sections { get; private set; } = Array.Empty<Section>();
    public int Total => Sections.Sum(s => s.Devices.Count);
    public bool IsRefreshing { get; private set; }

    /// <summary>목록 내용이나 새로고침 상태가 바뀌었을 때.</summary>
    public event Action? Changed;

    // 출처별 직전 값 — 한 출처가 실패해도 나머지는 그대로 둔다.
    private List<Device> _android = new();
    private IReadOnlyList<Device> _bluetooth = Array.Empty<Device>();
    private IReadOnlyList<Device> _usb = Array.Empty<Device>();
    private readonly Dictionary<string, string> _androidNames = new();
    private bool _started;

    public void Start()
    {
        if (_started) return;
        _started = true;
        _ = LoopAsync(RefreshDevAsync, TimeSpan.FromSeconds(3));
        _ = LoopAsync(RefreshPeripheralsAsync, TimeSpan.FromSeconds(10));
    }

    /// <summary>팝업을 열거나 새로고침을 눌렀을 때.</summary>
    public async Task RefreshNowAsync()
    {
        if (IsRefreshing) return;
        IsRefreshing = true;
        Changed?.Invoke();
        try
        {
            await Task.WhenAll(RefreshDevAsync(), RefreshPeripheralsAsync());
        }
        finally
        {
            IsRefreshing = false;
            Changed?.Invoke();
        }
    }

    private static async Task LoopAsync(Func<Task> refresh, TimeSpan interval)
    {
        while (true)
        {
            try { await refresh(); } catch (Exception) { /* 다음 주기에 다시 시도 */ }
            await Task.Delay(interval);
        }
    }

    private async Task RefreshDevAsync()
    {
        var android = await AndroidProvider.FetchAsync(_androidNames);
        if (android is not null) _android = android;
        Publish();
    }

    private async Task RefreshPeripheralsAsync()
    {
        var result = await PnpProvider.FetchAsync();
        if (result is not null)
        {
            _bluetooth = result.Bluetooth;
            _usb = result.Usb;
        }
        Publish();
    }

    private void Publish()
    {
        // 케이블로 꽂은 아이폰은 USB 출처에서 개발 기기로 분류돼 온다.
        var dev = _android.Concat(_usb.Where(d => d.Kind == DeviceKind.Dev));
        var wired = _usb.Where(d => d.Kind == DeviceKind.Wired);
        var merged = DeviceMerger.Merge(dev, _bluetooth, wired);
        if (DeviceMerger.SameContent(merged, Sections)) return;
        Sections = merged;
        Changed?.Invoke();
    }
}
