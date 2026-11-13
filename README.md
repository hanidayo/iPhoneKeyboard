# 갤럭시 천지인 키보드 (iOS)

갤럭시 삼성 키보드의 천지인 배열을 아이폰에서 쓰는 키보드 확장입니다.

```
 ㅣ    ㆍ    ㅡ    ⌫
 ㄱㅋ  ㄴㄹ  ㄷㅌ  →
 ㅂㅍ  ㅅㅎ  ㅈㅊ  .,?!
 !#1 😊   ㅇㅁ  ⎵   ↵      (영문은 iOS 기본 키보드를 🌐로 전환해서 사용)
```

## 기능
- 천지인 한글 조합: 자음 연타(ㄱ→ㅋ→ㄲ), 겹받침, 받침이 다음 글자로 넘어가기(각+ㅣ → 가기, 각+ㆍㅣ → 가거)
- 같은 자음을 연속으로 쓸 때는 **→ 키** (안 → → → 녕). 연타 간격보다 오래 쉬었다가 누르면 바로 새 글자
- 스페이스는 항상 띄어쓰기
- **스페이스를 좌우로 밀면 커서 이동** (갤럭시 순정과 같은 방식)
- 천지인 키 **길게 누르기 → 숫자** (ㅣ=1 … ㅇㅁ=0)
- `.,?!` 키 연타 → `. , ? !` 순환
- 백스페이스: 조합 중이면 자모 단위로 지움, 꾹 누르면 연속 삭제
- !#1: 숫자·기호 (iOS 순정과 같은 배열, #+= / 123 두 페이지)
- 인증번호 칸이면 툴바에 "탭하면 기본 키보드로" 버튼 → iOS 키보드에서 문자 인증번호 자동 입력
- 😊: 이모티콘 패널 (최근 사용 + 8개 분류)
- 다크 모드 자동 대응
- **툴바**(키보드 위): ⚙ 키보드 설정 · 📋 클립보드 기록 · 가운데에 복사한 글/사진 칩(복사 후 1분만 보임) · 키보드 내리기
  - 복사 내용은 칩을 누를 때만 읽어서 '붙여넣기 허용' 창이 계속 뜨지 않음
  - 글: 칩을 누르면 바로 붙여넣기
  - 사진: iOS 키보드는 사진을 직접 넣을 수 없어서, 칩을 누르면 "입력창 길게 눌러 붙여넣기" 안내
- **→ 키**: 조합 중이면 글자를 끝냄(같은 자음 연속 입력: 안 → 녕), 아니면 커서 오른쪽 이동
- **키보드 설정**(⚙): 자음 연타 간격, 스페이스 커서 속도, 키보드 높이, 진동, 키 소리
- 진동·키 소리·클립보드는 아이폰 설정에서 이 키보드의 **전체 접근 허용**을 켜야 동작

## 빌드하기 (Mac 필요)

### 방법 A — XcodeGen (추천, 가장 간단)
```bash
brew install xcodegen
cd GalaxyKeyboard
xcodegen          # GalaxyKeyboard.xcodeproj 생성
open GalaxyKeyboard.xcodeproj
```
1. 두 타깃(GalaxyKeyboard, ChunjiinKeyboard) 모두 **Signing & Capabilities → Team**에서 내 Apple ID 선택
2. 번들 ID가 이미 쓰이고 있다는 오류가 나면 `project.yml`의 `com.hani`를 아무 이름으로 바꾸고 다시 `xcodegen`
3. 아이폰을 연결하고 ▶ 실행 (처음이면 아이폰에서 개발자 모드 켜기 + 설정 → 일반 → VPN 및 기기 관리에서 신뢰)

### 방법 B — Xcode에서 직접
1. 새 프로젝트: iOS App (SwiftUI) → `HostApp/GalaxyKeyboardApp.swift` 내용으로 교체
2. File → New → Target → **Custom Keyboard Extension** 추가
3. 생성된 확장 폴더의 파일을 지우고 `KeyboardExtension/*.swift` 4개를 넣기
4. 확장 Info.plist의 `NSExtension → NSExtensionAttributes`에서 `PrimaryLanguage`를 `ko-KR`로, 진동을 쓰려면 `RequestsOpenAccess`를 `YES`로

### 아이폰에서 켜기
설정 → 일반 → 키보드 → 키보드 → 새로운 키보드 추가 → **갤럭시 천지인**
진동을 원하면 추가된 키보드를 눌러 **전체 접근 허용**을 켭니다 (이 키보드는 네트워크를 쓰지 않습니다).

> 무료 Apple ID로 설치하면 **7일마다** Xcode에서 다시 설치해야 합니다. 개발자 프로그램(연 $99)에 가입하면 1년 유지, TestFlight로도 설치할 수 있습니다.

## 조정할 수 있는 값
| 무엇 | 위치 |
|---|---|
| 연타 간격 (기본 0.8초) | `ChunjiinEngine.multitapTimeout` |
| 스페이스 드래그 감도 | `KeyView.dragStep` (작을수록 빠름), `dragThreshold` |
| 키보드 높이 | `KeyboardViewController.keyboardHeight` |
| 진동 / 키 소리 | `enableHaptic`, `enableSound` |
| 길게 누르기 시간 | `KeyView`의 `0.4` |
| 이모지 목록 | `EmojiData.swift` |
| 키 색 | `Palette` (KeyView.swift) |

## iOS 제약 (코드로 바꿀 수 없음)
- 키보드 **아래 지구본·마이크 줄**은 iOS가 그리는 영역이라 옮기거나 숨길 수 없습니다. 마이크는 설정 → 일반 → 키보드 → '받아쓰기 활성화'를 끄면 사라집니다.
- 비밀번호 칸, 일부 전화번호 패드에서는 iOS가 자동으로 기본 키보드로 바꿉니다.
- 키보드 확장은 마이크를 쓸 수 없어서 키보드 안에 음성 입력 버튼은 넣을 수 없습니다.

## 파일 구성
```
HostApp/GalaxyKeyboardApp.swift      설치 안내 + 테스트 입력칸
KeyboardExtension/
  ChunjiinEngine.swift               천지인 한글 조합 로직
  KeyboardViewController.swift       배열(천지인/영문/기호), 입력 처리, 스페이스 커서 이동
  KeyView.swift                      키 버튼 (탭/길게/반복/드래그), 색상
  EmojiPanelView.swift               이모티콘 패널
  EmojiData.swift                    이모지 목록
project.yml                          XcodeGen 설정
```

## GitHub Actions로 IPA 받기 (Mac 없이)
1. 이 폴더 전체(숨김 폴더 `.github` 포함)를 GitHub 저장소의 `main` 브랜치에 올립니다.
2. 올리면 **Actions** 탭에서 `Build IPA`가 자동으로 실행됩니다 (macOS 러너에서 약 5~10분).
3. 끝나면 **Releases**에 `GalaxyKeyboard.ipa`가 올라옵니다.
4. 이 IPA는 **서명되지 않은 파일**이라 그대로는 설치되지 않습니다. PC에서 **Sideloadly**(또는 AltStore)로 내 Apple ID를 넣고 설치하면 서명돼서 설치됩니다.
   - 무료 Apple ID는 7일마다 다시 설치해야 합니다.
   - 무료 계정은 앱 ID가 최대 3개인데, 이 앱은 앱 + 키보드 확장으로 2개를 씁니다.
5. 빌드가 실패하면 Actions 실행 화면의 로그(또는 `build-log` 아티팩트)를 확인하세요.
