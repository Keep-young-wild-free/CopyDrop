# CopyDrop Mac App

macOS용 BLE Peripheral 서버 앱입니다.

## 🚀 빌드 및 실행

```bash
cd mac
swift run
```

## 📋 주요 기능

- **Maccy 스타일 메뉴바 UI**: 클립보드 히스토리 빠른 접근
- **BLE Peripheral 서버**: Android 기기 연결 대기
- **클립보드 모니터링**: 복사 내용 자동 감지 및 전송
- **고급 설정**: 필터링, 히스토리 관리, 보안 설정

## 🔧 설정

### 블루투스 권한
첫 실행 시 블루투스 권한 허용 필요

### 주요 설정값
- **서비스 UUID**: `00001101-0000-1000-8000-00805F9B34FB`
- **특성 UUID**: `00002101-0000-1000-8000-00805F9B34FB`
- **서비스명**: `CopyDropService`

자세한 통신 프로토콜은 `../docs/PROTOCOL.md` 참조