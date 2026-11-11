# Linkie — Windows

작업 표시줄 알림 영역(트레이)에 아이콘으로 상주한다. 아이콘 안의 숫자가 연결된 기기 수이고, 누르면 목록이 뜬다.

- **개발 기기** — 안드로이드(adb, USB·Wi-Fi·에뮬레이터), 케이블로 꽂은 아이폰·아이패드
- **블루투스** — 연결된 기기와 배터리(기기가 알려 줄 때만)
- **USB** — 케이블로 꽂은 장치(허브와 PC 내장 장치는 숨김)

행을 클릭하면 시리얼·주소가 복사된다. 아이콘을 오른쪽 클릭하면 새로고침·로그인 시 실행·종료 메뉴가 나온다.

## 받기

저장소의 **Actions → windows → 최근 실행 → Artifacts** 또는 [Releases](../../../releases/latest) 에서 `Linkie-windows-x64` 를 내려받아 압축을 풀고 `Linkie.exe` 를 실행한다. 설치 과정은 없고, .NET 을 따로 깔 필요도 없다.

서명되지 않은 실행 파일이라 처음 실행할 때 SmartScreen 경고가 뜨면 「추가 정보 → 실행」을 누른다.

## 직접 빌드 (Windows, .NET 8 SDK)

```powershell
dotnet test windows/Linkie.Tests
dotnet run --project windows/Linkie.App
```

## 맥용과 다른 점

| | macOS | Windows |
|---|---|---|
| 상주 위치 | 메뉴바 | 트레이 |
| iOS 시뮬레이터 | 표시 | 없음(윈도우에 시뮬레이터가 없다) |
| iOS 실기기 | Xcode 도구로 이름·OS 버전까지 | USB 목록에서 골라 이름만 |
| 썬더볼트 | 별도 표시 | USB 로 보이는 것만 |
| 블루투스 배터리 | 대부분 표시 | 윈도우가 값을 가진 기기만(주로 헤드셋류) |

## 구조

- `Linkie.Core` — 기기 모델, adb·기기 조회 결과 파서, 중복 제거. 화면과 무관해 어느 OS 에서나 테스트된다.
- `Linkie.App` — 트레이 아이콘, 팝업 창(WPF), 명령 실행. 블루투스·USB 는 `Scripts/pnp.ps1` 이 `Get-PnpDevice` 로 조회한다.
- `Linkie.Tests` — 파서·병합 테스트.
