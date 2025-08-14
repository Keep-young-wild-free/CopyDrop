# 📥 CopyDrop 다운로드 및 실행 가이드

## 🎯 3가지 방법으로 CopyDrop 사용하기

### 방법 1: 현재 프로젝트 직접 실행 (가장 빠름) ⚡

현재 위치: `/Users/sey_yeah.311kakao.com/Downloads/0000 Git Project/CopyDrop`

```bash
# 1. Xcode로 프로젝트 열기
open CopyDrop.xcodeproj

# 2. Xcode에서 실행
# - Scheme: "CopyDrop" 선택
# - Destination: "My Mac" 선택  
# - ⌘ + R 누르기 (빌드 & 실행)
```

### 방법 2: Git 저장소로 공유 (추천) 🌐

#### A. Git 저장소 생성 및 업로드

```bash
# 현재 디렉토리에서 Git 초기화
cd "/Users/sey_yeah.311kakao.com/Downloads/0000 Git Project/CopyDrop"
git init

# 파일들 추가
git add .
git commit -m "feat: CopyDrop v1.0 - 완전한 클립보드 동기화 앱

- 실시간 클립보드 동기화 (WebSocket)
- AES-256-GCM 엔드투엔드 암호화
- 다중 디바이스 지원 (서버/클라이언트 모드)
- 자동 에러 복구 및 로깅
- 내장 시스템 테스트 도구
- 23개 파일, 3,731줄의 최적화된 Swift 코드"

# GitHub에 업로드 (선택사항)
# git remote add origin https://github.com/username/CopyDrop.git
# git branch -M main
# git push -u origin main
```

#### B. 다른 사람이 다운로드하는 방법

```bash
# Git clone으로 다운로드
git clone https://github.com/username/CopyDrop.git
cd CopyDrop

# Xcode로 열고 실행
open CopyDrop.xcodeproj
```

### 방법 3: ZIP 파일로 배포 📦

```bash
# 현재 프로젝트를 ZIP으로 압축
cd "/Users/sey_yeah.311kakao.com/Downloads/0000 Git Project"
zip -r CopyDrop-v1.0.zip CopyDrop \
    -x "CopyDrop/build/*" \
    -x "CopyDrop/.DS_Store" \
    -x "CopyDrop/DerivedData/*"

# ZIP 파일이 생성됨: CopyDrop-v1.0.zip
```

**다운로드받은 사람의 실행 방법:**
```bash
# ZIP 압축 해제
unzip CopyDrop-v1.0.zip
cd CopyDrop

# Xcode로 열고 실행
open CopyDrop.xcodeproj
```

## 🔧 시스템 요구사항

### 필수 조건
- **macOS**: 14.0 이상 (Sonoma 이상)
- **Xcode**: 15.0 이상
- **Swift**: 5.9 이상
- **메모리**: 최소 4GB RAM
- **저장공간**: 최소 500MB

### 확인 방법
```bash
# macOS 버전 확인
sw_vers

# Xcode 설치 확인
xcode-select -p
xcodebuild -version

# Swift 버전 확인
swift --version
```

## 🚀 첫 실행 가이드

### 1단계: 프로젝트 열기
```bash
open CopyDrop.xcodeproj
```

### 2단계: 빌드 설정 확인
- **Product > Scheme > CopyDrop** 선택
- **Product > Destination > My Mac** 선택
- **Signing & Capabilities**에서 개발자 계정 설정

### 3단계: 빌드 및 실행
- **⌘ + B** (빌드만)
- **⌘ + R** (빌드 후 실행)

### 4단계: 권한 허용
첫 실행 시 다음 권한 요청에 **"허용"** 클릭:
- 📋 **클립보드 접근 권한**
- 🌐 **네트워크 연결 권한**
- 🔒 **키체인 접근 권한**

## 🧪 실행 후 확인사항

### 즉시 테스트
1. **시스템 테스트**: 툴바 → "시스템 테스트" → "모든 테스트 실행"
2. **암호화 테스트**: 툴바 → "암호화 테스트" → 키 생성/암호화 확인
3. **클립보드 테스트**: 툴바 → "클립보드 테스트" → 자동 동기화 확인

### 동기화 설정
1. **서버 모드**: 첫 번째 Mac에서 "서버" 선택 → "동기화 시작"
2. **클라이언트 모드**: 다른 디바이스에서 "클라이언트" 선택 → 서버 URL 입력 → "동기화 시작"
3. **키 공유**: 설정 → "암호화 키 QR 코드 표시" → 다른 디바이스에서 스캔

## 📦 배포용 빌드 생성

### Release 빌드 (최적화됨)
```bash
# 터미널에서 Release 빌드 생성
xcodebuild -project CopyDrop.xcodeproj \
           -scheme CopyDrop \
           -configuration Release \
           -derivedDataPath ./build \
           -destination "platform=macOS,arch=x86_64" \
           build

# 빌드된 앱 위치
ls -la build/Build/Products/Release/CopyDrop.app
```

### 앱 번들 배포
```bash
# 앱을 Applications 폴더로 복사
cp -R build/Build/Products/Release/CopyDrop.app /Applications/

# 또는 DMG 이미지 생성 (선택사항)
hdiutil create -volname "CopyDrop" \
               -srcfolder build/Build/Products/Release/CopyDrop.app \
               -ov -format UDZO \
               CopyDrop-v1.0.dmg
```

## 🔒 보안 설정

### 개발자 서명 (배포용)
```bash
# 개발자 인증서로 서명
codesign --deep --force --verify --verbose \
         --sign "Developer ID Application: Your Name" \
         build/Build/Products/Release/CopyDrop.app

# 공증 (Notarization) - App Store 배포용
xcrun notarytool submit CopyDrop-v1.0.dmg \
                       --keychain-profile "notarytool" \
                       --wait
```

### Gatekeeper 허용
사용자가 다운로드 후 실행 시 "개발자를 확인할 수 없음" 오류가 나면:
```bash
# 시스템 환경설정 → 보안 및 개인정보 보호 → "확인 없이 열기" 클릭
# 또는 터미널에서:
xattr -dr com.apple.quarantine /Applications/CopyDrop.app
```

## 🌐 네트워크 설정

### 방화벽 설정
```bash
# 포트 8080 허용 (서버 모드용)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add CopyDrop
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp CopyDrop
```

### WiFi 설정
- 모든 디바이스가 **같은 WiFi 네트워크**에 연결되어야 함
- 서버 Mac의 IP 주소: 설정에서 확인 가능
- 클라이언트 연결 URL: `ws://192.168.x.x:8080/ws`

## 📋 체크리스트

### 배포 전 확인
- [ ] 모든 테스트 통과 확인
- [ ] Release 빌드 정상 작동
- [ ] 권한 요청 정상 작동
- [ ] 네트워크 동기화 테스트
- [ ] 암호화/복호화 검증
- [ ] 에러 처리 확인

### 사용자 가이드
- [ ] README.md 업데이트
- [ ] 스크린샷 추가
- [ ] 사용법 비디오 제작 (선택)
- [ ] 문제해결 FAQ 작성

## 🎯 추천 배포 순서

1. **GitHub 저장소 생성** (무료, 버전 관리)
2. **Release 빌드 생성** (최적화)
3. **ZIP/DMG 배포** (쉬운 설치)
4. **사용자 가이드 제공** (원활한 사용)

**이제 완벽하게 다운로드하고 실행할 수 있습니다!** 🚀
