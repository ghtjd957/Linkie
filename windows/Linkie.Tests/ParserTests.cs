using Linkie.Core;
using Xunit;

namespace Linkie.Tests;

public class AdbParserTests
{
    private const string Output =
        "* daemon started successfully\r\n"
        + "List of devices attached\r\n"
        + "R3CX00TEST01            device product:q4qksx model:SM_F936N device:q4q transport_id:1\r\n"
        + "emulator-5554          device product:sdk_gphone64 model:sdk_gphone64_x86_64 device:emu64x transport_id:2\r\n"
        + "192.168.0.12:5555      device product:panther model:Pixel_7 device:panther transport_id:3\r\n"
        + "ZY22ABCDEF             unauthorized transport_id:4\r\n"
        + "\r\n";

    [Fact]
    public void 연결_방식과_상태를_구분한다()
    {
        var entries = AdbParser.ParseDevices(Output);

        Assert.Equal(
            new[] { AdbTransport.Usb, AdbTransport.Emulator, AdbTransport.Wifi, AdbTransport.Usb },
            entries.Select(e => e.Transport));
        Assert.Equal(new[] { "device", "device", "device", "unauthorized" }, entries.Select(e => e.State));
        Assert.Equal("SM-F936N", entries[0].Model);
        Assert.Null(entries[3].Model);
    }

    [Fact]
    public void 기기_이름이_있으면_모델은_부가정보로_간다()
    {
        var entry = AdbParser.ParseDevices(Output)[0];
        var device = AdbParser.ToDevice(entry, "Galaxy Z Fold4", 87);

        Assert.Equal("Galaxy Z Fold4", device.Name);
        Assert.Equal("SM-F936N · USB", device.Detail);
        Assert.Equal(87, device.Battery);
        Assert.Equal("R3CX00TEST01", device.Serial);
        Assert.False(device.NeedsAttention);
    }

    [Fact]
    public void 미승인_기기는_주의_표시를_단다()
    {
        var entry = AdbParser.ParseDevices(Output)[3];
        var device = AdbParser.ToDevice(entry, null, null);

        Assert.True(device.NeedsAttention);
        Assert.Equal("ZY22ABCDEF", device.Name);
        Assert.Equal("USB · USB 디버깅 승인 필요", device.Detail);
    }

    [Fact]
    public void 배터리_잔량을_읽는다()
    {
        Assert.Equal(87, AdbParser.ParseBatteryLevel("  AC powered: true\r\n  level: 87\r\n  scale: 100\r\n"));
        Assert.Null(AdbParser.ParseBatteryLevel("error: device offline"));
    }
}

public class PnpParserTests
{
    private const string Json = """
        {"bluetooth":[
           {"name":"WH-1000XM5","address":"AABBCCDDEEFF","le":false,"battery":70},
           {"name":"MX Master 3S","address":"112233445566","le":true,"battery":null}],
         "usb":[
           {"name":"SAMSUNG_Android","vendor":"SAMSUNG Electronics Co., Ltd.","serial":"R3CX00TEST01","vid":"04E8","pid":"6860"},
           {"name":"Apple iPhone","vendor":"Apple, Inc.","serial":"0000800000000000000000AB","vid":"05AC","pid":"12A8"},
           {"name":"USB Receiver","vendor":"(표준 시스템 장치)","serial":null,"vid":"046D","pid":"C52B"}]}
        """;

    [Fact]
    public void 블루투스_기기와_배터리를_읽는다()
    {
        var result = PnpParser.Parse(Json);

        Assert.NotNull(result);
        Assert.Equal(new[] { "MX Master 3S", "WH-1000XM5" }, result.Bluetooth.Select(d => d.Name));
        var headphones = result.Bluetooth[1];
        Assert.Equal(70, headphones.Battery);
        Assert.Equal("AA:BB:CC:DD:EE:FF", headphones.CopyText);
        Assert.Equal(DeviceIcon.Headphones, headphones.Icon);
        Assert.Equal("블루투스", headphones.Detail);

        var mouse = result.Bluetooth[0];
        Assert.Null(mouse.Battery);
        Assert.Equal("블루투스 LE", mouse.Detail);
        Assert.Equal(DeviceIcon.Mouse, mouse.Icon);
    }

    [Fact]
    public void USB_기기를_읽고_아이폰은_개발_기기로_올린다()
    {
        var result = PnpParser.Parse(Json);

        Assert.NotNull(result);
        Assert.Equal(3, result.Usb.Count);

        var android = result.Usb[0];
        Assert.Equal(DeviceKind.Wired, android.Kind);
        Assert.Equal("R3CX00TEST01", android.Serial);

        var iphone = result.Usb[1];
        Assert.Equal(DeviceKind.Dev, iphone.Kind);
        Assert.Equal(DeviceAccent.Ios, iphone.Accent);
        Assert.Equal("USB", iphone.Detail); // 제조사가 이름에 이미 들어 있으면 반복하지 않는다

        var receiver = result.Usb[2];
        Assert.Equal("USB", receiver.Detail); // 자리 채움 제조사는 버린다
        Assert.Null(receiver.Serial);
    }

    [Theory]
    [InlineData("""{"bluetooth":null,"usb":null}""")]
    [InlineData("""{"bluetooth":[],"usb":[]}""")]
    [InlineData("{}")]
    public void 비어_있어도_빈_목록으로_읽는다(string json)
    {
        var result = PnpParser.Parse(json);

        Assert.NotNull(result);
        Assert.Empty(result.Bluetooth);
        Assert.Empty(result.Usb);
    }

    [Fact]
    public void 원소가_하나라_객체로_나와도_읽는다()
    {
        var result = PnpParser.Parse(
            """{"bluetooth":{"name":"Keyboard","address":"AABBCCDDEE01","le":true,"battery":"55"},"usb":[]}""");

        Assert.NotNull(result);
        var keyboard = Assert.Single(result.Bluetooth);
        Assert.Equal(55, keyboard.Battery);
    }

    [Fact]
    public void JSON_이_아니면_null()
    {
        Assert.Null(PnpParser.Parse("Get-PnpDevice : 오류"));
        Assert.Null(PnpParser.Parse(""));
    }

    /// <summary>
    /// 윈도우 빌드 서버가 실제로 돌린 pnp.ps1 출력을 읽어 본다. 로컬에서는 환경 변수가 없어 건너뛴다.
    /// </summary>
    [Fact]
    public void 실제_스크립트_출력을_읽는다()
    {
        var path = Environment.GetEnvironmentVariable("LINKIE_PNP_SMOKE_FILE");
        if (string.IsNullOrEmpty(path)) return;

        var result = PnpParser.Parse(File.ReadAllText(path));
        Assert.NotNull(result);
    }
}

public class MergeTests
{
    [Fact]
    public void 케이블로_꽂은_개발_기기는_USB_목록에서_지운다()
    {
        var adb = AdbParser.ToDevice(new AdbEntry("R3CX00TEST01", "device", "SM-F936N", AdbTransport.Usb), null, null);
        var usbPhone = new Device("usb:1", "SAMSUNG_Android", "USB", DeviceKind.Wired, DeviceAccent.Usb,
            DeviceIcon.Phone, Serial: "R3CX00TEST01");
        var earpods = new Device("usb:2", "EarPods", "Apple · USB", DeviceKind.Wired, DeviceAccent.Usb,
            DeviceIcon.Headphones, Serial: "EARPODS0001");

        var sections = DeviceMerger.Merge(new[] { adb }, Array.Empty<Device>(), new[] { usbPhone, earpods });

        Assert.Equal(new[] { DeviceKind.Dev, DeviceKind.Wired }, sections.Select(s => s.Kind)); // 빈 블루투스는 숨김
        Assert.Equal(new[] { "EarPods" }, sections[1].Devices.Select(d => d.Name));
    }

    [Fact]
    public void 전부_비면_섹션이_없다()
    {
        Assert.Empty(DeviceMerger.Merge(Array.Empty<Device>(), Array.Empty<Device>(), Array.Empty<Device>()));
    }

    [Fact]
    public void 내용이_같으면_같은_목록으로_본다()
    {
        Device Make(int? battery) => new("bt:1", "Mouse", "블루투스", DeviceKind.Bluetooth, DeviceAccent.Bluetooth,
            DeviceIcon.Mouse, Battery: battery);
        IReadOnlyList<Section> Sections(int? battery) =>
            DeviceMerger.Merge(Array.Empty<Device>(), new[] { Make(battery) }, Array.Empty<Device>());

        Assert.True(DeviceMerger.SameContent(Sections(50), Sections(50)));
        Assert.False(DeviceMerger.SameContent(Sections(50), Sections(49)));
    }
}
