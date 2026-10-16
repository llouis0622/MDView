# MDView

문서에 집중하는 시간. 원문을 변경하지 않는 macOS용 오프라인 Markdown 뷰어입니다.

**[설치 ZIP 다운로드 — macOS Universal](releases/v1.0.0/MDView-1.0.0-macOS-universal.zip)** · [SHA-256](releases/v1.0.0/SHA256SUMS)

**macOS 13+ · Apple Silicon / Intel Universal · ad-hoc 서명 · Apple 공증 없음**

## 설치 및 첫 실행

1. 위 **설치 ZIP 다운로드** 링크에서 파일을 받은 뒤 압축을 풀어 주세요. GitHub 파일 화면에서는 **Download raw file** 버튼을 사용하세요.
2. `MDView.app`을 원하는 위치에 두세요. 필요하면 사용자가 직접 응용 프로그램 폴더로 옮길 수 있습니다.
3. 앱을 열고 **열기…** 또는 **⌘O**로 Markdown 문서를 선택하세요. 동봉한 `시작하기.md`로 바로 확인할 수 있습니다.
4. 인터넷에서 받은 앱이라는 이유로 차단되면, 한 번 실행을 시도한 뒤 **시스템 설정 → 개인정보 보호 및 보안 → 그래도 열기**에서 허용하세요. macOS 버전에 따라 Finder에서 앱을 Control-클릭하고 **열기**를 선택하는 방법도 제공됩니다.

이 배포본은 **ad-hoc 서명**되어 있습니다. Apple Developer ID 서명 및 Apple 공증은 받지 않았습니다. 시스템 보안 기능을 전체적으로 끄거나 터미널에서 격리 속성을 일괄 제거할 필요는 없습니다.

- 대상: **Universal 2 — Apple Silicon arm64 및 Intel x86_64**
- 최소 시스템: **macOS 13 Ventura**
- 실제 실행 검증: **macOS 27.0.1 / Apple Silicon**. Intel x86_64 바이너리도 같은 Mac의 기존 Rosetta에서 통합 시험을 통과했습니다. 실제 Intel 하드웨어와 macOS 13에서는 실행하지 않았습니다.
- 계정, 로그인, 서버, 네트워크 연결이 필요하지 않습니다.
- 자동 설치, 기본 연결 앱 변경, 커밋·푸시는 수행하지 않았습니다.

[실제 실행 화면](Artifacts/MDView-app-screen.png) · [검증 결과와 한계](VALIDATION.md) · [변경 기록](CHANGELOG.md)

## 사용법

| 작업 | 방법 |
| --- | --- |
| 문서 열기 | ⌘O / 상단 열기 / 창 본문에 한 파일 드래그 앤 드롭 |
| Finder에서 열기 | 문서 Control-클릭 → 연결 프로그램 → MDView (목록에 없으면 기타에서 앱 선택) |
| 다시 읽기 | ⌘R — 외부 편집기로 변경한 문서를 다시 불러옵니다 |
| 목차 | 왼쪽 제목 클릭, ⌘\\로 표시·숨기기 |
| 검색 | ⌘F, ⌘G 또는 Enter로 다음 결과, ⇧⌘G로 이전 결과 |
| 검색 지우기 | 검색창에서 Esc |
| 글자 크기 | A− / A+ 또는 ⌘− / ⌘+, ⌘0으로 기본값 |
| 테마 | 시스템 / 라이트 / 다크 선택 |
| 원문 위치 | 파일 메뉴 → Finder에서 보기 |

글자 크기와 테마는 다음 실행에도 유지됩니다. 새 문서는 목차·검색·스크롤이 초기화됩니다. 취소하거나 파일을 읽지 못하면 현재 문서를 유지합니다. 여러 파일은 한 번에 하나씩 열어 주세요.

## 지원 범위와 제한

- `.md`, `.markdown`, `.mdown`, `.mkd`, `.txt`; UTF-8 또는 BOM이 있는 UTF-16.
- 제목, 목록, 체크리스트, 인용, 강조, 링크, 표, 코드 블록. 긴 표·코드는 각각 가로 스크롤됩니다.
- 코드 블록은 고정폭으로 표시합니다. 프로그래밍 언어별 구문 색상은 적용하지 않습니다.
- Mermaid flowchart, sequence 등 번들에 포함된 도식을 오프라인으로 렌더링합니다. 도식은 테마와 관계없이 흰색 바탕으로 표시합니다.
- 문서당 Mermaid 20개, 도식당 12,000자·200개 간선까지. 문서의 Mermaid 설정 지시문과 frontmatter, 잘못된 도식은 원문으로 표시합니다. 렌더러의 지원 범위를 벗어난 도식도 원문을 보존해 표시합니다.
- 문서 최대 **8 MiB**. **1 MiB 초과**는 안정성을 위해 Markdown 원문 보기로 전환합니다.
- 검색은 일반 본문과 코드의 텍스트를 대상으로 하며 도식 내부 글자는 제외합니다. 한 번에 최대 3,000개 결과를 강조합니다.
- 문서 내 제목 앵커와 문서 폴더 내부 Markdown 링크를 지원합니다. 폴더 밖 문서는 ⌘O로 직접 여세요.
- 상대 이미지는 문서 폴더와 하위 폴더의 PNG/JPEG/GIF/WebP/HEIC/TIFF/BMP만 지원합니다. 이미지당 최대 12 MiB, 4천만 픽셀, 16,000px 한 변 제한. 2,400px 이내 정적 PNG로 변환하므로 애니메이션은 첫 프레임만 표시합니다.
- 원문 HTML, SVG 파일, iframe, 스크립트, 원격 이미지·폰트·미디어는 실행하거나 자동으로 불러오지 않습니다. 일부 HTML 기반 Markdown 확장은 문자 그대로 표시됩니다.
- 외부 HTTP(S)·메일 링크는 확인 후 기본 앱에서 엽니다. 확인 전에는 네트워크 연결을 하지 않습니다.

## 소스에서 빌드

macOS와 Xcode Command Line Tools가 필요합니다. 테스트에 사용한 도구는 Apple Swift 6.4입니다.

```sh
cd MDView
./Scripts/build.sh
open build/MDView.app
```

`Resources/viewer.js`에 필요한 라이브러리가 이미 포함되어 있으므로 기본 앱 빌드는 **오프라인으로 가능**하며 npm 설치가 필요하지 않습니다. 산출물은 `build/MDView.app`입니다. arm64와 x86_64를 각각 컴파일한 뒤 합치고 ad-hoc 서명합니다.

렌더러 소스를 수정할 때만 Node.js와 npm을 사용합니다.

```sh
npm ci --ignore-scripts --no-fund --no-audit
npm run bundle
./Scripts/build.sh
```

아이콘 재생성:

```sh
xcrun swift -module-cache-path build/module-cache Scripts/icon.swift Resources/LLouis.png Resources/AppIcon.iconset Resources/AppIcon.icns
```

자동 통합 시험은 생성한 예제와 임시 fixture만 사용합니다. GUI 세션에서 실행하세요. 파일 열기 패널이 잠시 표시되었다가 자동 취소됩니다.

```sh
TEST_ARCH="$(uname -m)" ./Scripts/build.sh test
./build/MDView.app/Contents/MacOS/MDView --self-test "$PWD"
cat Artifacts/test-results.txt
./Scripts/build.sh  # 배포용으로 다시 빌드
```

## 설치 ZIP 만들기

```sh
./Scripts/package.sh
(cd dist && shasum -a 256 -c SHA256SUMS)
```

결과는 `dist/MDView-1.0.0-macOS-universal.zip`과 `dist/SHA256SUMS`입니다.
`dist/`는 Git에서 제외됩니다. 검증한 파일만 `releases/v1.0.0/`에 복사하세요.
현재 포함된 설치 ZIP은 앞서 검증한 완성품과 **바이트 단위로 동일**하며 파일명만
저장소 버전 표기에 맞췄습니다. 재빌드한 ZIP의 해시는 달라질 수 있습니다.

## GitHub에 올리기

이 폴더의 **내용을 저장소 루트**로 사용하세요. 로컬 `.git` 이력이나 remote는
포함하지 않았으며 원격 저장소 생성·push·공개 게시는 수행하지 않았습니다.
GitHub의 빈 저장소에 파일을 업로드하거나, 필요할 때 직접 아래 명령으로 시작할 수 있습니다.

```sh
git init
git add .
git commit -m "feat: add offline native MDView reader for macOS"
```

설치 파일은 `releases/v1.0.0/`에 함께 보관합니다. 나중에 GitHub Release를 만들면
ZIP과 `SHA256SUMS`를 Release assets로 옮기고 README의 다운로드 링크를 그 주소로
바꿀 수 있습니다. Release URL이나 원격 저장소 주소는 미리 가정하지 않았습니다.

포함된 설치 파일 확인:

```sh
(cd releases/v1.0.0 && shasum -a 256 -c SHA256SUMS)
```

## 구조

- `Sources/`: AppKit 창·메뉴·파일 처리·WKWebView 격리
- `Web/viewer.js`: Markdown 렌더링·목차·검색·Mermaid
- `Resources/`: 오프라인 번들, CSS, HTML, 앱 정보, 사용자 지정 아이콘
- `Tests/Integration.swift`: 실제 AppKit/WebKit 통합 시험
- `Examples/시작하기.md`: 기능 확인용 한국어 예제
- `Artifacts/`: 실제 실행 결과와 검증 화면
- `releases/v1.0.0/`: 검증된 설치 ZIP과 SHA-256

렌더러는 HTML을 끈 markdown-it과 DOMPurify를 사용하고, Mermaid도 strict 모드와 SVG 정제를 적용합니다. CSP와 WebKit 콘텐츠 차단 규칙으로 웹 네트워크를 차단하며, 비영구 웹 데이터 저장소와 로컬 전용 URL scheme을 사용합니다. 상대 이미지는 정규화·심볼릭 링크 검사 후 PNG로 다시 인코딩해 제공합니다. 사용자 문서에 쓰는 코드는 없습니다.

## 라이선스

직접 작성한 MDView 코드·스크립트·문서는 [LICENSE](LICENSE)에 명시한 범위에서 MIT로
제공합니다. 의존성 버전과 무결성은 `package-lock.json`에 고정되어 있으며, 오프라인
번들의 제3자 라이선스는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)에 있습니다.

사용자 제공 아이콘 `Resources/LLouis.png`와 그 파생 아이콘·화면 속 그림의 권리는
원 권리자에게 있습니다. 프로젝트 MIT 라이선스는 그 그림에 적용되지 않으며,
별도의 사용권을 부여하거나 저작권을 주장하지 않습니다.
