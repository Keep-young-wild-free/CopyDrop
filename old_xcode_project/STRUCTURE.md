# CopyDrop 프로젝트 구조

## 📁 개선된 디렉토리 구조

```
CopyDrop/
├── 📱 App Entry
│   ├── CopyDropApp.swift              # 앱 진입점
│   └── Item.swift                     # 기존 템플릿 (호환성)
│
├── 📊 Models/
│   └── ClipboardItem.swift            # 클립보드 데이터 모델 (SwiftData)
│
├── 🎨 Views/
│   ├── ContentView.swift              # 메인 뷰
│   └── Components/
│       ├── StatusIndicatorView.swift  # 연결 상태 표시
│       └── ClipboardItemView.swift    # 클립보드 아이템 뷰
│
├── ⚙️ Services/
│   ├── ClipboardSyncService.swift     # 핵심 동기화 서비스
│   ├── WebSocketServer.swift          # 네트워크 서버
│   ├── SecurityManager.swift          # 보안 및 암호화
│   ├── ErrorHandler.swift             # 에러 처리 시스템
│   └── ClipboardSyncService+Testing.swift # 테스트 지원
│
├── 🛠️ Utils/
│   ├── Logger.swift                   # 통합 로깅 시스템
│   └── NetworkUtils.swift             # 네트워크 유틸리티
│
├── 🔧 Extensions/
│   └── Foundation+Extensions.swift    # Foundation 확장
│
├── 📋 Constants/
│   └── AppConstants.swift             # 앱 전역 상수
│
└── 🎨 Assets.xcassets/                # 리소스
    ├── AppIcon.appiconset/
    └── AccentColor.colorset/
```

## 🔄 구조 개선 사항

### ✅ 이전 문제점들
- ❌ Views가 루트에 흩어져 있음
- ❌ 하드코딩된 상수들
- ❌ Utils와 Services가 혼재
- ❌ 불필요한 프로토타입 파일들
- ❌ Extensions 부재

### ✅ 개선된 점들
- ✅ **명확한 폴더 분리**: Views, Services, Utils, Models 등 역할별 분리
- ✅ **상수 중앙화**: AppConstants로 모든 설정값 관리
- ✅ **재사용 가능한 컴포넌트**: StatusIndicatorView, ClipboardItemView 분리
- ✅ **확장성 고려**: Extensions 폴더로 기능 확장
- ✅ **유틸리티 분리**: Logger, NetworkUtils 등 독립적 관리
- ✅ **테스트 지원**: 전용 테스트 헬퍼 파일

## 📝 파일별 역할

### 🎯 Core Services
- **ClipboardSyncService**: 클립보드 모니터링, 동기화, 암호화/복호화
- **WebSocketServer**: 네트워크 통신, 클라이언트 관리
- **SecurityManager**: 키 관리, 내용 필터링, 보안 정책
- **ErrorHandler**: 에러 수집, 자동 복구, 로그 관리

### 🎨 UI Components
- **ContentView**: 메인 인터페이스 (설정, 히스토리, 상태)
- **StatusIndicatorView**: 연결 상태 시각화
- **ClipboardItemView**: 클립보드 항목 표시

### 🛠️ Supporting Files
- **AppConstants**: 네트워크, 보안, UI 등 모든 상수 관리
- **Logger**: 파일, 콘솔, OS 로깅 통합
- **NetworkUtils**: IP 주소, 포트 관리, 연결 검증
- **Foundation+Extensions**: 공통 확장 기능

## 🎯 장점

1. **유지보수성**: 명확한 역할 분리로 수정 영향 범위 최소화
2. **확장성**: 새 기능 추가 시 적절한 위치 명확
3. **테스트 용이성**: 각 컴포넌트 독립적 테스트 가능
4. **가독성**: 파일 찾기 쉽고 코드 의도 명확
5. **재사용성**: 컴포넌트 단위로 다른 프로젝트에서 재사용 가능

## 🚀 다음 단계

- [ ] iOS/iPadOS 대응을 위한 플랫폼별 Views 추가
- [ ] 네트워크 발견을 위한 Bonjour Service 추가
- [ ] 이미지/파일 지원을 위한 Media Services 추가
- [ ] 클라우드 동기화를 위한 Backend Services 추가
