# CopyDrop

macOS용 블루투스 기반 클립보드 동기화 앱입니다. Mac과 Android 기기 간 클립보드 내용을 Core Bluetooth(BLE)로 실시간 동기화합니다.

## 🌟 주요 기능

- **Maccy 스타일 UI**: 메뉴바에서 간편한 클립보드 히스토리 접근
- **Core Bluetooth(BLE) 통신**: Mac ↔ Android 기기 간 안전한 무선 연결
- **실시간 클립보드 동기화**: 복사한 내용을 연결된 기기와 즉시 공유
- **스마트 콘텐츠 필터링**: 민감한 정보 및 대용량 데이터 자동 차단
- **클립보드 히스토리**: 최근 클립보드 내용 기록 및 빠른 접근 (1-9, 0 단축키)
- **고급 설정**: 동기화 지연, 필터링 키워드, 보안 설정 등 세밀한 제어

## 🚀 시작하기

### 요구사항

- macOS 13.0 이상
- Swift Package Manager 지원
- 블루투스 Low Energy(BLE) 지원 기기

### 설치 및 실행

```bash
# 프로젝트 클론
git clone https://github.com/yourusername/CopyDrop.git
cd Mac_CopyDrop

# Swift Package Manager로 빌드 및 실행
swift run
```

## 📱 사용법

### 1. 앱 시작
- 메뉴바에 📋 아이콘이 나타남
- 블루투스 권한 허용 요청 승인

### 2. 블루투스 서버 시작
- 메뉴바 아이콘 클릭 → "블루투스 서버 시작" (⌘B)
- 또는 설정에서 블루투스 토글 활성화

### 3. Android 기기 연결
- Android 앱에서 "CopyDropService" 검색 및 연결
- 연결되면 메뉴에서 연결된 기기 확인 가능

### 4. 클립보드 동기화
- Mac에서 텍스트 복사 → Android 클립보드에 자동 동기화
- Android에서 텍스트 복사 → Mac 클립보드에 자동 수신

## 🎯 인터페이스 특징

### Maccy 스타일 메뉴
```
📋 클릭 시:
┌─────────────────────────────────┐
│ 최근 복사한 텍스트...        1  │
│ 두 번째 클립보드 항목...      2  │
│ 세 번째 항목...             3  │
│ ...                            │
├─────────────────────────────────┤
│ 전체 삭제                      │
│ 설정...                    ⌘,  │
│ 블루투스 서버 중지          ⌘B  │
├─────────────────────────────────┤
│ CopyDrop 종료              ⌘Q  │
└─────────────────────────────────┘
```

### 설정 창 기능
- **빠른 설정**: 자동 동기화, 콘텐츠 필터링, 히스토리 저장, 암호화
- **고급 설정**: 동기화 지연 시간, 차단 키워드 관리, 히스토리 개수 등

## 🔐 보안 기능

### 콘텐츠 필터링
- **길이 제한**: 1,000~50,000 글자 범위 설정 가능
- **키워드 차단**: 사용자 정의 차단 키워드 목록
- **민감 정보 감지**: 패스워드, API 키 등 자동 차단

### 암호화 (구현 예정)
- AES-256-GCM 암호화
- 기기별 고유 키 생성

## 🏗️ 아키텍처

### Swift Package Manager 구조
```
Sources/CopyDrop/
├── main.swift                    # 앱 진입점
├── AppDelegate.swift             # 메뉴바 앱 델리게이트
├── Models/
│   ├── ClipboardItem.swift       # 클립보드 아이템 모델
│   └── AppSettings.swift         # 설정 관리
├── Services/
│   ├── ClipboardManager.swift    # 클립보드 모니터링
│   └── BluetoothManager.swift    # Core Bluetooth 통신
└── Views/
    ├── MainView.swift            # 메인 인터페이스
    ├── SettingsView.swift        # 설정 화면
    └── AdvancedSettingsView.swift # 고급 설정
```

### 핵심 컴포넌트

- **AppDelegate**: NSStatusItem 기반 메뉴바 앱 관리
- **ClipboardManager**: NSPasteboard 모니터링 및 히스토리 관리
- **BluetoothManager**: CBPeripheralManager/CBCentralManager 통신
- **AppSettings**: UserDefaults 기반 설정 영속화

## 🔧 개발 및 확장

### 주요 설정값
- **동기화 간격**: 0.1~2.0초 (기본 0.5초)
- **히스토리 최대 개수**: 10~200개 (기본 50개)
- **콘텐츠 최대 길이**: 1,000~50,000글자 (기본 10,000글자)

### 확장 계획
- [ ] Android 앱 완성
- [ ] 이미지/파일 동기화 지원
- [ ] 클라우드 릴레이 서버
- [ ] 다중 기기 동시 연결

## 🤝 기여하기

1. Fork 프로젝트
2. Feature 브랜치 생성
3. 변경사항 커밋
4. Pull Request 생성

## 📄 라이선스

MIT License - 자세한 내용은 `LICENSE` 파일 참조

## ❓ 문제 해결

### 자주 묻는 질문

**Q: 메뉴바 아이콘이 보이지 않습니다**
A: macOS 시스템 설정 > 개인정보 보호 및 보안 > 접근성에서 앱 권한을 확인하세요.

**Q: 블루투스 연결이 안 됩니다**
A: 블루투스가 켜져 있는지 확인하고, 블루투스 권한을 허용했는지 확인하세요.

**Q: 클립보드가 동기화되지 않습니다**
A: 설정에서 "자동 동기화"가 활성화되어 있는지, 콘텐츠 필터링에 걸리지 않았는지 확인하세요.

### 디버깅

콘솔 로그에서 "🎯", "✅", "❌" 이모지로 시작하는 로그를 확인하여 문제를 진단할 수 있습니다.