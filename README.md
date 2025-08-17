# CopyDrop

크로스플랫폼 블루투스 클립보드 동기화 솔루션입니다. Mac과 Android 기기 간 클립보드 내용을 Bluetooth Low Energy(BLE)로 실시간 동기화합니다.

## 🌟 주요 기능

- **🔄 실시간 동기화**: Mac ↔ Android 클립보드 즉시 동기화
- **📶 BLE 통신**: 안정적이고 저전력 Bluetooth Low Energy 사용
- **🎯 Maccy 스타일**: Mac에서 익숙한 메뉴바 클립보드 히스토리
- **🛡️ 스마트 필터링**: 민감한 정보 및 대용량 데이터 자동 차단
- **⚡ 자동 연결**: 기기 발견 시 자동 연결 및 재연결
- **🔧 고급 설정**: 세밀한 동기화 제어 및 보안 설정

## 🏗️ 프로젝트 구조

```
CopyDrop/
├── README.md                          # 전체 프로젝트 가이드
├── docs/                              # 공통 문서
│   └── PROTOCOL.md                    # BLE 통신 프로토콜 명세
├── mac/                               # Mac 앱 (Swift Package Manager)
│   ├── Package.swift
│   ├── Sources/CopyDrop/
│   └── README.md
└── android/                           # Android 앱 (Gradle)
    ├── app/
    ├── build.gradle.kts
    └── README.md
```

## 🚀 시작하기

### Mac 앱

```bash
cd mac
swift run
```

**주요 기능:**
- 메뉴바 📋 아이콘 클릭으로 클립보드 히스토리 접근
- BLE Peripheral 서버로 Android 연결 대기
- Maccy 스타일 드롭다운 메뉴 (1-9, 0 단축키)

### Android 앱

```bash
cd android
./gradlew assembleDebug
./gradlew installDebug
```

**주요 기능:**
- Mac "CopyDropService" 자동 검색 및 연결
- 클립보드 변경 자동 감지 및 전송
- 연결 상태 실시간 표시

## 📱 사용법

### 1단계: Mac 앱 시작
1. 메뉴바에 📋 아이콘 확인
2. 아이콘 클릭 → "블루투스 서버 시작" (⌘B)
3. 블루투스 권한 허용

### 2단계: Android 앱 연결
1. Android 앱 실행
2. 권한 허용 (블루투스, 위치)
3. "기기 검색" 버튼 클릭
4. 자동 연결 완료 대기

### 3단계: 클립보드 동기화
- **Mac → Android**: Mac에서 복사 → Android 클립보드에 자동 적용
- **Android → Mac**: Android에서 복사 → Mac 클립보드에 자동 적용

## 🔧 시스템 요구사항

### Mac
- **macOS 13.0** 이상
- **Swift Package Manager** 지원
- **Bluetooth Low Energy** 지원

### Android
- **Android 6.0 (API 23)** 이상
- **Bluetooth Low Energy** 지원
- **위치 권한** (BLE 스캔 요구사항)

## 📡 기술 사양

### BLE 프로토콜
- **Service UUID**: `00001101-0000-1000-8000-00805F9B34FB`
- **Characteristic UUID**: `00002101-0000-1000-8000-00805F9B34FB`  
- **Service Name**: `CopyDropService`

### 역할 분담
- **Mac**: BLE Peripheral (서버) - 광고 및 연결 대기
- **Android**: BLE Central (클라이언트) - 스캔 및 연결 요청

### 데이터 형식
```json
{
  "content": "클립보드 텍스트",
  "timestamp": "2024-01-01T12:00:00Z", 
  "deviceId": "mac-MacBook-Pro",
  "messageId": "uuid"
}
```

자세한 내용은 [`docs/PROTOCOL.md`](docs/PROTOCOL.md) 참조

## 🛡️ 보안 기능

### 콘텐츠 필터링 (Mac)
- **길이 제한**: 1,000~50,000 글자 설정 가능
- **키워드 차단**: 사용자 정의 차단 키워드
- **민감 정보 감지**: 패스워드, API 키 패턴 자동 감지

### 중복 방지
- **Device ID**: 자신이 보낸 메시지 필터링
- **Message ID**: 중복 메시지 방지

## 🔧 개발 및 기여

### 개발 환경
- **Mac**: Xcode 15.0+, Swift 5.9+
- **Android**: Android Studio, Kotlin

### 주요 라이브러리
- **Mac**: Core Bluetooth, SwiftUI, AppKit
- **Android**: Android BLE, Material Design 3, Gson

### 기여하기
1. Fork 프로젝트
2. Feature 브랜치 생성
3. 변경사항 커밋  
4. Pull Request 생성

## 📄 라이선스

MIT License - 자세한 내용은 `LICENSE` 파일 참조

## ❓ 문제 해결

### 자주 묻는 질문

**Q: Mac 메뉴바 아이콘이 보이지 않습니다**
A: 시스템 설정 > 개인정보 보호 및 보안 > 접근성에서 앱 권한 확인

**Q: Android에서 기기를 찾을 수 없습니다**
A: 
1. Mac에서 블루투스 서버가 시작되었는지 확인
2. Android 위치 권한 허용 확인
3. 두 기기 모두 블루투스 활성화 확인

**Q: 클립보드가 동기화되지 않습니다**
A:
1. 연결 상태 확인 (Mac 메뉴, Android 상태 표시)
2. Mac 설정에서 "자동 동기화" 활성화 확인
3. 콘텐츠 필터링 설정 확인

**Q: 연결이 자주 끊어집니다**
A: 
1. 두 기기가 가까운 거리에 있는지 확인
2. 다른 BLE 기기와의 간섭 확인
3. 앱 백그라운드 실행 권한 확인

### 로그 확인
- **Mac**: 터미널에서 `swift run` 실행 시 콘솔 로그 확인
- **Android**: Android Studio Logcat에서 "CopyDrop" 태그 필터링

---

**CopyDrop**으로 Mac과 Android 간 매끄러운 클립보드 동기화를 경험하세요! 🚀