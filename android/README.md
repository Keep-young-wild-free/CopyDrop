# CopyDrop Android App

Mac CopyDrop과 BLE로 연결하여 클립보드를 동기화하는 Android 앱입니다.

## 🚀 빌드 및 실행

```bash
cd android
./gradlew assembleDebug
./gradlew installDebug
```

또는 Android Studio에서 프로젝트 열기

## 📱 주요 기능

- **BLE 스캔**: Mac의 "CopyDropService" 자동 검색
- **자동 연결**: 발견된 Mac 서비스에 자동 연결
- **양방향 동기화**: Android ↔ Mac 클립보드 실시간 동기화
- **권한 관리**: BLE 및 위치 권한 자동 요청
- **상태 표시**: 연결 상태 및 클립보드 동기화 상태 표시

## 🔧 요구사항

- **Android 6.0 (API 23)** 이상
- **Bluetooth Low Energy (BLE)** 지원 기기
- **위치 권한**: BLE 스캔에 필요 (Android 요구사항)

## 📋 사용법

1. **앱 실행**: 권한 허용 (블루투스, 위치)
2. **Mac 준비**: Mac CopyDrop에서 "블루투스 서버 시작"
3. **기기 검색**: Android 앱에서 "기기 검색" 버튼 클릭
4. **자동 연결**: CopyDropService 발견 시 자동 연결
5. **동기화 시작**: 연결 완료 후 클립보드 자동 동기화

## 🛡️ 권한

### 필수 권한
- `BLUETOOTH` / `BLUETOOTH_ADMIN`: BLE 통신
- `ACCESS_FINE_LOCATION`: BLE 기기 스캔
- `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT`: Android 12+ BLE

### 자동 요청
앱에서 필요한 모든 권한을 자동으로 요청합니다.

## 📡 통신 프로토콜

자세한 내용은 `../docs/PROTOCOL.md` 참조

### 핵심 설정
- **Service UUID**: `00001101-0000-1000-8000-00805F9B34FB`
- **Characteristic UUID**: `00002101-0000-1000-8000-00805F9B34FB`
- **Device ID**: `android-{MODEL}`

## 🔧 개발 노트

- **Gson**: JSON 메시지 파싱
- **Material Design 3**: 현대적인 UI
- **Coroutines 준비**: 비동기 처리 (향후 확장)