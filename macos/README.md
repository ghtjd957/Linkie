# Tether

맥에 연결된 기기를 메뉴바에서 한눈에 보는 앱. 아이콘 옆 숫자가 연결된 기기 수이고, 누르면 목록이 내려온다.

- **개발 기기** — 안드로이드(adb, USB·Wi-Fi·에뮬레이터), 실행 중인 iOS 시뮬레이터, 연결된 iOS 실기기
- **블루투스** — 연결된 기기와 배터리(기기가 알려 줄 때만)
- **USB · 썬더볼트** — 케이블로 꽂은 장치(허브 자체는 숨기고 "허브 경유"로 표시)

행을 클릭하면 시리얼·UDID·주소가 복사된다.

배터리가 20% 이하로 내려간 기기는 알림으로 한 번 알려 준다(25%를 넘게 충전되면 다시 알릴 수 있는 상태로 돌아간다). 처음 실행할 때 알림 권한을 묻는다.

## 빌드 · 실행

```bash
cd macos && scripts/bundle.sh   # macos/Tether.app 생성
open Tether.app
```

계속 쓰려면 `Tether.app` 을 `/Applications` 로 옮긴 뒤 팝오버 아래 「로그인 시 실행」을 켠다.
macOS 14 이상, Xcode 명령줄 도구 필요. 외부 라이브러리 없음.

## 테스트

```bash
swift test
TETHER_SNAPSHOT_DIR=/tmp/tether swift test --filter Snapshot   # 팝오버를 라이트/다크 PNG 로 저장
```

`Tests/TetherTests/Fixtures/` 는 실제 명령 출력의 형태를 그대로 두고 기기 이름·시리얼·UDID·주소만 가짜 값으로 바꾼 것이다.

## 정보 출처

| 섹션 | 명령 |
|---|---|
| 안드로이드 | `adb devices -l`, `adb shell dumpsys battery` |
| iOS 시뮬레이터 | `xcrun simctl list devices booted -j` |
| iOS 실기기 | `xcrun devicectl list devices --json-output` |
| 블루투스 | `system_profiler SPBluetoothDataType -json` (배터리는 `ioreg -r -k BatteryPercent`, `pmset -g accps` 로 보충) |
| USB | `system_profiler SPUSBHostDataType -json` (macOS 26 에서 `SPUSBDataType` 은 빈 값) |
| 썬더볼트 | `system_profiler SPThunderboltDataType -json` |

개발 기기는 3초, 블루투스·USB 는 10초마다 갱신하고 팝오버를 열 때 즉시 갱신한다.
