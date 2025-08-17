# Android 앱 테스트 가이드

## 🚀 방법 1: Android Studio (권장)

### 1단계: Android Studio 설치
1. [Android Studio 다운로드](https://developer.android.com/studio)
2. 설치 후 Android SDK 설정

### 2단계: 프로젝트 열기
```bash
# Android Studio에서 열기
cd /Users/brio/Downloads/000\ Git\ Project/Mac_CopyDrop/android
```
**File → Open** → `android` 폴더 선택

### 3단계: 기기 준비
**실제 Android 기기 (권장):**
1. 개발자 옵션 활성화:
   - 설정 → 폰 정보 → 빌드 번호 7번 터치
2. USB 디버깅 활성화:
   - 설정 → 개발자 옵션 → USB 디버깅 ON
3. USB로 컴퓨터에 연결

**또는 에뮬레이터:**
- Android Studio → AVD Manager → Create Virtual Device
- API 23+ (Android 6.0+) 선택

### 4단계: 앱 실행
1. Android Studio에서 **Run** 버튼 (▶️) 클릭
2. 또는 `⌃R` (Ctrl+R)

---

## 🛠️ 방법 2: 명령어 빌드

### Gradle로 APK 빌드
```bash
cd android

# 디버그 빌드
./gradlew assembleDebug

# APK 위치
ls app/build/outputs/apk/debug/app-debug.apk
```

### 기기에 설치
```bash
# ADB 설치 확인
adb devices

# APK 설치
adb install app/build/outputs/apk/debug/app-debug.apk
```

---

## 🔍 테스트 시나리오

### 준비 작업
1. **Mac 앱 실행**: `cd mac && swift run`
2. **블루투스 서버 시작**: Mac 메뉴바 → 블루투스 서버 시작
3. **Android 앱 설치 및 실행**

### 테스트 케이스

#### 1. 연결 테스트
- [ ] Android 앱에서 "기기 검색" 클릭
- [ ] "CopyDropService" 자동 발견 및 연결
- [ ] 상태가 "연결됨"으로 변경
- [ ] Mac 메뉴에서 연결된 기기 확인

#### 2. Mac → Android 동기화
- [ ] Mac에서 텍스트 복사 (`⌘C`)
- [ ] Android 클립보드에 자동 반영 확인
- [ ] Android 앱에서 "수신: ..." 메시지 확인

#### 3. Android → Mac 동기화  
- [ ] Android에서 텍스트 복사
- [ ] Mac 클립보드에 자동 반영 확인
- [ ] Mac 콘솔에 수신 로그 확인
- [ ] Android 앱에서 "전송: ..." 메시지 확인

#### 4. 재연결 테스트
- [ ] 블루투스 껐다 켜기
- [ ] 앱 재시작 후 자동 재연결
- [ ] 거리 멀어짐/가까워짐 테스트

---

## 🐛 문제 해결

### Android Studio 문제
```bash
# Gradle 캐시 정리
./gradlew clean

# Android Studio 캐시 정리
File → Invalidate Caches and Restart
```

### 권한 문제
1. **위치 권한**: 설정 → 앱 → CopyDrop → 권한 → 위치 허용
2. **블루투스 권한**: Android 12+ 기기에서 자동 요청

### 연결 문제
1. **Mac 서버 상태**: 메뉴바에서 "블루투스 서버 시작" 확인
2. **같은 공간**: 두 기기가 가까운 거리에 있는지 확인
3. **블루투스 활성화**: 양쪽 모두 블루투스 ON

### 로그 확인
**Android:**
```bash
# Android Studio Logcat 또는
adb logcat | grep CopyDrop
```

**Mac:**
```bash
# 터미널에서 실행 시 콘솔 로그 확인
cd mac && swift run
```

---

## 📊 예상 동작

### 정상 로그 (Android)
```
BluetoothService: BLE 스캔 시작
BluetoothService: 기기 발견: CopyDropService
BluetoothService: CopyDropService 발견!
BluetoothService: 기기 연결 시도
BluetoothService: GATT 연결됨
BluetoothService: CopyDropService 연결 완료
ClipboardService: 클립보드 모니터링 시작
```

### 정상 로그 (Mac)
```
✅ 메뉴바 설정 완료
✅ CopyDrop 초기화 완료
Core Bluetooth 서버 시작 중...
BLE 서비스 등록 및 광고 시작
시뮬레이션: 기기 연결됨 - Galaxy S24
```