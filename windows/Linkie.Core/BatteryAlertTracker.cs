namespace Linkie.Core;

/// <summary>
/// 어떤 기기에 배터리 부족 알림을 보낼지 정한다. 한 번 알린 기기는 충전돼 올라올 때까지 다시 알리지 않는다.
/// </summary>
public sealed class BatteryAlertTracker
{
    private readonly HashSet<string> _alerted = new();

    /// <summary>이 값 이하로 내려가면 알린다.</summary>
    public int Threshold { get; init; } = 20;

    /// <summary>임계값 근처에서 잔량이 오르내릴 때 알림이 반복되지 않도록, 이만큼 더 올라와야 다시 알릴 수 있다.</summary>
    public int RearmMargin { get; init; } = 5;

    /// <summary>
    /// 새로 부족해진 기기만 돌려준다. 목록에 없는 기기(연결 해제)는 상태를 그대로 둔다 —
    /// 블루투스가 잠깐 끊겼다 붙을 때마다 다시 울리지 않게.
    /// </summary>
    public IReadOnlyList<Device> Update(IEnumerable<Device> devices)
    {
        var fresh = new List<Device>();
        foreach (var device in devices)
        {
            if (device.Battery is not { } level) continue;
            if (level <= Threshold)
            {
                if (_alerted.Add(device.Id)) fresh.Add(device);
            }
            else if (level > Threshold + RearmMargin)
            {
                _alerted.Remove(device.Id);
            }
        }
        return fresh;
    }
}
