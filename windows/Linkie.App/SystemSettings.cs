using System;
using Microsoft.Win32;

namespace Linkie.App;

internal static class SystemSettings
{
    private const string PersonalizeKey = @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize";
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string RunValueName = "Linkie";

    /// <summary>앱 창이 밝은 테마인지.</summary>
    public static bool AppsUseLightTheme => ReadFlag("AppsUseLightTheme", fallback: true);

    /// <summary>작업 표시줄이 밝은 테마인지(트레이 아이콘 색을 정한다).</summary>
    public static bool TaskbarUsesLightTheme => ReadFlag("SystemUsesLightTheme", fallback: false);

    private static bool ReadFlag(string name, bool fallback)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(PersonalizeKey);
            return key?.GetValue(name) is int value ? value != 0 : fallback;
        }
        catch (Exception)
        {
            return fallback;
        }
    }

    public static bool LaunchAtLogin
    {
        get
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(RunKey);
                return key?.GetValue(RunValueName) is string;
            }
            catch (Exception)
            {
                return false;
            }
        }
        set
        {
            try
            {
                using var key = Registry.CurrentUser.CreateSubKey(RunKey);
                if (value && Environment.ProcessPath is { } path)
                {
                    key.SetValue(RunValueName, $"\"{path}\"");
                }
                else
                {
                    key.DeleteValue(RunValueName, throwOnMissingValue: false);
                }
            }
            catch (Exception)
            {
                // 레지스트리를 못 쓰면 다음에 읽을 때 실제 상태가 그대로 보인다.
            }
        }
    }
}
