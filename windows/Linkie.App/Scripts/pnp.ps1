# 연결된 블루투스·USB 기기를 JSON 한 줄로 내보낸다. Linkie 가 주기적으로 실행한다.
#   { "bluetooth": [{ name, address, le, battery }], "usb": [{ name, vendor, serial, vid, pid }] }
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$keyConnected = '{83DA6326-97A6-4088-9453-A1923F573B29} 15'   # 블루투스 기기가 지금 연결돼 있는지
$keyBattery   = '{104EA319-6EE2-4701-BD47-8DDBF425BBE5} 2'    # 블루투스 배터리(%) — 기기가 알려 줄 때만
$keyBusDesc   = 'DEVPKEY_Device_BusReportedDeviceDesc'        # 기기가 스스로 밝힌 제품 이름
$keyContainer = 'DEVPKEY_Device_ContainerId'
$keyVendor    = 'DEVPKEY_Device_Manufacturer'
$keyService   = 'DEVPKEY_Device_Service'

# PC 본체에 내장된 장치(웹캠·지문 인식기 등)는 모두 이 컨테이너에 속한다.
$machineContainer = '{00000000-0000-0000-FFFF-FFFFFFFFFFFF}'

function Get-Props($ids, $keys) {
    $table = @{}
    if (-not $ids) { return $table }
    foreach ($p in (Get-PnpDeviceProperty -InstanceId $ids -KeyName $keys)) {
        if (-not $table.ContainsKey($p.InstanceId)) { $table[$p.InstanceId] = @{} }
        $table[$p.InstanceId][$p.KeyName] = $p.Data
    }
    return $table
}

$present = @(Get-PnpDevice -PresentOnly)

# --- 블루투스: 페어링만 된 기기는 빼고 연결된 것만 ---
$btNodes = @($present | Where-Object { $_.InstanceId -match '^BTH(ENUM|LE)\\DEV_[0-9A-Fa-f]{12}' })
$btProps = Get-Props @($btNodes | ForEach-Object { $_.InstanceId }) @($keyConnected, $keyBattery)
$bluetooth = @()
foreach ($d in $btNodes) {
    $p = $btProps[$d.InstanceId]
    if (-not $p -or $p[$keyConnected] -ne $true) { continue }
    $null = $d.InstanceId -match '^BTH(ENUM|LE)\\DEV_([0-9A-Fa-f]{12})'
    $battery = $p[$keyBattery]
    $bluetooth += [pscustomobject]@{
        name    = $d.FriendlyName
        address = $Matches[2].ToUpper()
        le      = ($Matches[1] -eq 'LE')
        battery = $(if ($battery -ne $null) { [int]$battery } else { $null })
    }
}

# --- USB: 기기 단위 노드만(복합 기기의 인터페이스 노드 `&MI_xx` 는 제외) ---
$usbNodes = @($present | Where-Object {
    $_.InstanceId -match '^USB\\VID_[0-9A-Fa-f]{4}&PID_[0-9A-Fa-f]{4}\\[^\\]+$' -and $_.Class -ne 'Bluetooth'
})
$usbProps = Get-Props @($usbNodes | ForEach-Object { $_.InstanceId }) @($keyBusDesc, $keyContainer, $keyVendor, $keyService)
$usb = @()
foreach ($d in $usbNodes) {
    $p = $usbProps[$d.InstanceId]
    if (-not $p) { $p = @{} }
    if ("$($p[$keyService])" -match '^usbhub') { continue }                       # 허브 자체는 숨김
    if ("{$($p[$keyContainer])}".ToUpper() -eq $machineContainer) { continue }    # 내장 장치는 숨김

    $null = $d.InstanceId -match '^USB\\VID_([0-9A-Fa-f]{4})&PID_([0-9A-Fa-f]{4})\\([^\\]+)$'
    $tail = $Matches[3]
    $name = $p[$keyBusDesc]
    if (-not $name) { $name = $d.FriendlyName }
    $usb += [pscustomobject]@{
        name   = $name
        vendor = $p[$keyVendor]
        # 시리얼이 없는 기기는 윈도우가 `6&1a2b3c&0&2` 같은 위치 값을 대신 넣는다.
        serial = $(if ($tail -notmatch '&') { $tail } else { $null })
        vid    = $Matches[1].ToUpper()
        pid    = $Matches[2].ToUpper()
    }
}

[pscustomobject]@{ bluetooth = @($bluetooth); usb = @($usb) } | ConvertTo-Json -Depth 4 -Compress
