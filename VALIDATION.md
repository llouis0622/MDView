# MDView 1.0 검증 요약

검증일: 2026-10-16

## 환경과 배포본

- macOS 27.0.1 (26A434), Apple Silicon Mac
- Apple Swift 6.4, Command Line Tools, macOS SDK 27.0
- Universal Mach-O: `arm64`, `x86_64`
- 두 slice의 `LC_BUILD_VERSION minos`: `13.0`
- ad-hoc 서명: `codesign --verify --deep --strict` 통과. Developer ID 및 공증 없음.
- 사용자 PNG `Resources/LLouis.png` (692×693 RGBA)를 원본 그대로 보존. 16–1024px 투명 아이콘, 7개 ICNS 표현, macOS Finder 아이콘 조회 및 실제 픽셀 확인.

## 실제 실행 시험

같은 AppKit/WKWebView 통합 시험 **41개를 두 아키텍처에서 각각 통과**했습니다.

- arm64 네이티브: **41 PASS / 0 FAIL** (`Artifacts/test-results-arm64.txt`)
- x86_64, 기존 Rosetta 사용: **41 PASS / 0 FAIL** (`Artifacts/test-results-x86_64.txt`)
- 실제 Intel Mac과 macOS 13에서는 실행하지 않았습니다.

| 영역 | 확인 내용 |
| --- | --- |
| 렌더링 | 한국어 제목·본문·목차, 표, fenced code |
| Mermaid | 네트워크 없이 flowchart·sequence SVG 생성, 잘못된 문법·설정 override는 원문 표시 |
| 검색 | 한국어, 다음·이전, 검색 해제, 결과 없음 |
| 보기 | 라이트·다크 테마, 글자 크기, 목차 표시·숨기기 |
| 파일 | 실제 파일 메뉴의 NSOpenPanel 표시·취소, 취소 후 기존 문서 유지 |
| 교체 | 새 파일의 검색·스크롤·목차 초기화, 반복 빠른 드롭에서 마지막 파일 우선 |
| 드롭 | macOS 파일 URL pasteboard 해석 및 실제 앱의 드롭 수신 처리 함수 호출, 빈 목록·여러 파일 거절 |
| 예외 | 빈 파일, 불완전 Markdown, 잘못된 인코딩, BOM UTF-16, NUL 바이너리, 다른 확장자, 없는 파일 |
| 큰 문서 | 1 MiB 초과 원문 보기, 8 MiB 초과 거절, 오류 후 기존 문서 유지 |
| 안전성 | 원문 HTML·script·iframe·SVG 비활성, javascript 링크·원격 이미지 제외, CSP fetch 차단 |
| 이미지 | 한국어·공백 파일명 상대 PNG 표시, 없는 이미지 대체 표시, 경로 탈출·절대 경로·원격 경로·SVG·폴더 밖 symlink 차단 |
| 레이아웃 | 긴 표·긴 코드가 해당 영역에서 가로 스크롤, 전체 문서 폭 유지 |
| 원문 보존 | 예제 문서의 실행 전후 bytes 일치 |

## 배포용 앱과 실제 화면

테스트 코드를 제외한 최종 Universal 앱을 macOS `open -a` 파일 열기 이벤트로 실행해 `시작하기.md`를 열었습니다. 앱 제목, 상태 표시, 툴바, 목차, 한국어 Mermaid가 실제 화면에 나타나는 것을 확인했습니다.

- `Artifacts/MDView-app-screen.png`: 최종 앱의 화면 영역을 macOS 화면 캡처로 저장
- `Artifacts/MDView-light.png`, `MDView-dark.png`, `MDView-mermaid.png`: 실행 중 WKWebView의 실제 렌더링 스냅샷
- `Artifacts/MDView-Finder-icon.png`: NSWorkspace가 앱에서 읽은 아이콘

컴퓨터 조작 도구는 `failed to write kernel assets` 초기화 오류로 사용할 수 없었습니다. 따라서 Finder에서 마우스로 아이콘을 잡아 옮기는 전체 제스처는 자동화하지 못했습니다. 파일 URL pasteboard와 드롭 수신 경로는 통합 시험으로 검증했으며, Finder와 같은 macOS 파일 열기 이벤트는 배포용 앱에서 실행했습니다. 외부 링크 확인 후 실제 브라우저를 여는 작업은 불필요한 외부 접근을 피하기 위해 실행하지 않았습니다.

## 확인된 빌드 경고

이 Mac의 Swift 도구 모음에 포함된 `libswiftCompatibilityPacks.a`에 x86_64가 없어 링커가 해당 정적 라이브러리를 무시한다는 경고가 있습니다. 링크 및 Universal 생성은 성공했고, 생성된 x86_64 테스트 앱은 Rosetta에서 41개 시험을 모두 통과했습니다. macOS 13·실제 Intel 하드웨어 호환성을 별도로 인증한 것은 아닙니다.

## 전달물 및 재현

`releases/v1.0.0/`의 설치 ZIP은 앞서 검증한 완성품과 동일하며 `.app`, 예제 Markdown, 한국어 README, 제3자 라이선스, 당시 검증 요약을 포함합니다. 저장소 루트 LICENSE가 직접 작성 코드의 이용 조건과 아이콘·제3자 제외 범위를 명시합니다. GitHub 업로드용 저장소에는 Swift/JavaScript 소스, 고정된 lockfile, 오프라인 번들, 사용자 원본 아이콘과 생성 아이콘, 빌드·패키징 스크립트, 테스트와 결과·화면을 포함합니다. `node_modules`, 컴파일 캐시, 임시 테스트 fixture, 기존 사용자 프로젝트·문서·비밀값은 포함하지 않습니다.

앱은 문서를 수정하지 않으며 자동 설치·기본 연결 변경·커밋·푸시·원격 게시는 수행하지 않았습니다. 기본 앱 빌드는 오프라인으로 재현할 수 있습니다. 자세한 명령은 README를 참고하세요.

## GitHub 저장소 포장 검증

앱 동작은 변경하지 않았습니다. Swift 소스, 렌더러, 오프라인 리소스, 사용자 아이콘과
기존 설치 ZIP은 원본과 바이트 단위로 비교했습니다. 위 41/41 수치는 기존 실제 앱
시험 결과이며 이번 문서·포장 작업에서 새로운 앱 시험으로 중복 계산하지 않습니다.

최종 저장소 ZIP의 필수 파일·README 상대 링크, 설치 ZIP의 SHA-256·압축 무결성·
앱 ad-hoc 서명·Universal 아키텍처를 확인하고, 저장소 ZIP을 풀어 포함된 소스만으로
오프라인 재빌드가 통과했습니다. 정리한 패키징 스크립트도 실행해 설치 ZIP 생성과
체크섬·압축 무결성을 확인했습니다. [포장 검증과 파일 목록](Artifacts/repository-checks.txt)을 참고하세요.
