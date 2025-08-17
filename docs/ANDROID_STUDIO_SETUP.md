# Android Studio 설정 가이드

## 🔧 Run Configuration 설정

### 방법 1: 자동 설정
1. Android Studio에서 **File → Open**
2. `android` 폴더 선택
3. **"Trust Gradle Project"** 클릭
4. Gradle Sync 완료 대기 (하단 상태바 확인)
5. 상단 툴바에 **"app"** 설정 확인

### 방법 2: 수동 설정

#### Step 1: Add Configuration 클릭
1. 상단 툴바에서 **"Add Configuration..."** 클릭
2. 또는 **Run → Edit Configurations...**

#### Step 2: Android App 추가
1. **"+"** 버튼 클릭
2. **"Android App"** 선택

#### Step 3: 설정값 입력
```
Name: app
Module: CopyDrop Android.app
```

#### Step 4: 저장
- **"Apply"** → **"OK"** 클릭

---

## 📱 기기 설정

### 실제 Android 기기 (권장)
1. **개발자 옵션 활성화**:
   - 설정 → 휴대전화 정보 → 빌드 번호 7번 터치
   
2. **USB 디버깅 활성화**:
   - 설정 → 개발자 옵션 → USB 디버깅 ON
   
3. **USB 연결**:
   - Mac과 USB 케이블로 연결
   - "USB 디버깅 허용" 팝업에서 **"허용"** 클릭

### 에뮬레이터 설정
1. **AVD Manager** 클릭 (Android Studio 상단)
2. **"Create Virtual Device"** 클릭
3. **Phone** 카테고리에서 기기 선택 (예: Pixel 6)
4. **System Image** 선택:
   - **API Level 23+** (Android 6.0+) 
   - **Google APIs** 포함 버전 선택
5. **"Next"** → **"Finish"**

---

## 🚀 실행하기

### Step 1: 기기 선택
- 상단 툴바에서 기기 드롭다운 확인
- 연결된 실제 기기 또는 에뮬레이터 선택

### Step 2: 앱 실행
- **Run** 버튼 (▶️) 클릭
- 또는 **Shift + F10** (Windows) / **⌃R** (Mac)

### Step 3: 빌드 확인
```
BUILD SUCCESSFUL in 30s
Installing APK 'app-debug.apk' on 'Device Name'
Installed on 1 device.
```

---

## 🔍 문제 해결

### "Add Configuration" 만 보이는 경우
1. **Gradle Sync** 다시 실행:
   - **File → Sync Project with Gradle Files**
   
2. **프로젝트 구조 확인**:
   - `android/app/build.gradle.kts` 파일 존재 확인
   
3. **Android SDK 설정**:
   - **File → Project Structure → SDK Location**
   - Android SDK path 확인

### Gradle Sync 실패
1. **인터넷 연결** 확인
2. **Android Studio 재시작**
3. **캐시 정리**:
   - **File → Invalidate Caches and Restart**

### 기기 인식 안됨
1. **USB 케이블** 확인 (데이터 전송 가능한 케이블)
2. **USB 연결 모드** 변경:
   - Android 알림 → "파일 전송" 또는 "PTP" 선택
3. **ADB 확인**:
   ```bash
   adb devices
   # 기기가 "device" 상태로 표시되어야 함
   ```

### 권한 오류
1. **위치 권한**: 설정에서 수동 허용
2. **블루투스 권한**: 앱 실행 시 자동 요청
3. **USB 디버깅**: "항상 허용" 체크

---

## ✅ 성공 확인

앱이 성공적으로 실행되면:

1. **CopyDrop 아이콘**이 Android 기기에 나타남
2. **앱 실행** 시 권한 요청 팝업들
3. **"기기 검색"** 버튼이 활성화됨
4. **Android Studio Logcat**에서 로그 확인 가능

---

## 📊 다음 단계

앱이 설치되면:
1. **Mac에서 블루투스 서버 시작**
2. **Android에서 기기 검색**
3. **클립보드 동기화 테스트**

자세한 테스트 방법은 `ANDROID_TESTING.md` 참조