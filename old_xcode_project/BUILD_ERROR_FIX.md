# 🔧 빌드 오류 해결 가이드

## 🚨 현재 문제 상황

### 발생한 오류
```
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

### 원인 분석
- ✅ **Xcode 설치됨**: `/Applications/Xcode.app` 확인됨
- ❌ **경로 설정 오류**: Command Line Tools로 설정되어 있음
- ❌ **SwiftBridging 모듈 충돌**: 중복 정의 오류

## 🛠️ 해결 방법

### 방법 1: Xcode 경로 수정 (권장)

```bash
# 1. 현재 경로 확인
xcode-select -p
# 출력: /Library/Developer/CommandLineTools

# 2. Xcode로 경로 변경 (패스워드 필요)
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# 3. 경로 확인
xcode-select -p
# 출력: /Applications/Xcode.app/Contents/Developer

# 4. 라이센스 동의
sudo xcodebuild -license accept
```

### 방법 2: Xcode에서 직접 실행

1. **Finder에서 실행**:
   ```bash
   open /Applications/Xcode.app
   ```

2. **프로젝트 열기**:
   - File → Open → `CopyDrop.xcodeproj` 선택

3. **빌드 및 실행**:
   - `⌘ + B` (빌드만)
   - `⌘ + R` (빌드 후 실행)

### 방법 3: Xcode 재설치 (최후 수단)

```bash
# App Store에서 Xcode 삭제 후 재설치
# 또는 개발자 포털에서 최신 버전 다운로드
```

## 🎯 단계별 해결 과정

### 1단계: 패스워드 입력으로 경로 수정
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
# 관리자 패스워드 입력 필요
```

### 2단계: 라이센스 동의
```bash
sudo xcodebuild -license accept
```

### 3단계: 빌드 테스트
```bash
xcodebuild -project CopyDrop.xcodeproj -scheme CopyDrop -configuration Debug build
```

### 4단계: Xcode에서 실행
```bash
open CopyDrop.xcodeproj
# ⌘ + R로 실행
```

## 🔍 문제 해결 확인

### 성공 지표
- [ ] `xcode-select -p` 출력: `/Applications/Xcode.app/Contents/Developer`
- [ ] `xcodebuild -version` 정상 실행
- [ ] Xcode에서 빌드 성공
- [ ] 앱 정상 실행

### 실패 시 대안
1. **Xcode 재시작**
2. **Mac 재부팅**
3. **Command Line Tools 재설치**:
   ```bash
   sudo rm -rf /Library/Developer/CommandLineTools
   xcode-select --install
   ```

## 🚀 빠른 해결책

### 즉시 실행 가능한 방법

```bash
# 1. Xcode 앱을 직접 실행
open /Applications/Xcode.app

# 2. Welcome 화면에서 "Open a project or file" 클릭

# 3. CopyDrop.xcodeproj 선택

# 4. ⌘ + R로 빌드 및 실행
```

이 방법은 터미널 명령어 없이도 작동합니다!

## 📱 실행 후 확인사항

### 첫 실행 시
1. **권한 요청 허용**:
   - 클립보드 접근 권한
   - 네트워크 연결 권한
   - 키체인 접근 권한

2. **기능 테스트**:
   - 툴바 → "시스템 테스트" 실행
   - 모든 테스트 통과 확인

3. **동기화 시작**:
   - "서버" 모드 선택
   - "동기화 시작" 클릭

## 💡 추가 팁

### Xcode 최적화
- **Clean Build Folder**: `⌘ + Shift + K`
- **Rebuild**: `⌘ + Shift + B`
- **Reset Package Cache**: File → Packages → Reset Package Caches

### 성능 향상
- **Simulator 대신 실제 Mac에서 실행**
- **Release 모드로 빌드**: Edit Scheme → Run → Release

**결론**: 가장 쉬운 방법은 직접 Xcode.app을 열어서 프로젝트를 실행하는 것입니다! 🎯
