#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./Scripts/build.sh
mkdir -p dist
stage=$(mktemp -d "$PWD/dist/package.XXXXXX")
trap 'rm -rf "$stage"' EXIT
folder="$stage/MDView-1.0.0"
mkdir -p "$folder"
cp -R build/MDView.app "$folder/"
cp LICENSE THIRD_PARTY_NOTICES.md VALIDATION.md "$folder/"
cp Examples/시작하기.md "$folder/"
cat > "$folder/설치안내.txt" <<'GUIDE'
MDView 1.0 — macOS 13 이상 / Apple Silicon·Intel Universal

MDView.app을 원하는 위치에 두고 실행하세요. 필요하면 직접 응용 프로그램
폴더로 옮기세요. 자동 설치나 기본 연결 변경은 하지 않습니다.
⌘O 또는 창에 Markdown 파일을 놓아 문서를 엽니다. 동봉한 시작하기.md로
기능을 확인할 수 있습니다. 사용법은 앱 도움말 메뉴에서도 볼 수 있습니다.

이 앱은 ad-hoc 서명이며 Developer ID 서명·Apple 공증이 없습니다.
차단되면 한 번 실행을 시도한 뒤 시스템 설정 → 개인정보 보호 및 보안 →
그래도 열기에서 허용하세요. 시스템 보안을 전체적으로 끄지 마세요.

문서 원문을 수정하지 않습니다. 렌더링은 오프라인으로 동작하며 원문 HTML과
스크립트, 원격 이미지·폰트는 실행하거나 자동으로 불러오지 않습니다.
외부 링크는 확인 후 기본 앱에서 엽니다.
GUIDE
ditto -c -k --sequesterRsrc --keepParent "$folder" dist/MDView-1.0.0-macOS-universal.zip
(cd dist && shasum -a 256 MDView-1.0.0-macOS-universal.zip > SHA256SUMS)
echo 'Installer and checksum are in dist/. Review before copying to releases/ or GitHub Releases.'
