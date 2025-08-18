import AppKit
import Crypto

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var history: [ClipboardItem] = []
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var lastContent: String = ""
    private let settings = AppSettings.shared
    
    // 스마트 폴링 관련 변수들
    private var noChangeCount = 0  // 연속으로 변경이 없었던 횟수
    private var isSmartPollingStopped = false  // 스마트 폴링 중단 상태
    private let MAX_NO_CHANGE_COUNT = 3  // 3번 연속 변경 없으면 폴링 중단
    
    private init() {}
    
    func start() {
        // 초기 상태 저장
        lastChangeCount = NSPasteboard.general.changeCount
        lastContent = NSPasteboard.general.string(forType: .string) ?? ""
        
        // 스마트 폴링 초기화
        noChangeCount = 0
        isSmartPollingStopped = false
        
        // 설정에 따른 간격으로 클립보드 체크
        timer = Timer.scheduledTimer(withTimeInterval: settings.syncDelay, repeats: true) { _ in
            self.checkClipboard()
        }
        
        print("클립보드 스마트 폴링 시작 (간격: \(settings.syncDelay)초, \(MAX_NO_CHANGE_COUNT)회 무변경 시 중단)")
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        print("클립보드 감시 중지")
    }
    
    private func checkClipboard() {
        // 자동 동기화가 비활성화되어 있으면 중단
        guard settings.isAutoSyncEnabled else { 
            if !isSmartPollingStopped {
                print("⚠️ 자동 동기화가 비활성화됨")
            }
            return 
        }
        
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        
        // 디버깅을 위한 상세 로그
        if !isSmartPollingStopped {
            print("🔍 폴링 체크 - changeCount: \(lastChangeCount) → \(currentChangeCount), 조용한모드: \(isSmartPollingStopped)")
        }
        
        // changeCount가 변경되었는지 확인
        guard currentChangeCount != lastChangeCount else { 
            // 변경 없음 - 카운터 증가
            noChangeCount += 1
            
            // 조용한 모드가 아닐 때만 로깅
            if !isSmartPollingStopped {
                print("📋 클립보드 변경 없음 (\(noChangeCount)/\(MAX_NO_CHANGE_COUNT))")
            }
            
            if noChangeCount >= MAX_NO_CHANGE_COUNT && !isSmartPollingStopped {
                isSmartPollingStopped = true
                print("🔇 스마트 폴링 조용한 모드 (로깅 최소화, 복사 감지는 계속)")
            }
            return 
        }
        
        // 변경 감지됨 - 스마트 폴링 카운터 리셋
        noChangeCount = 0
        isSmartPollingStopped = false
        print("🔍 클립보드 변경 감지됨 (changeCount: \(lastChangeCount) → \(currentChangeCount)) - 스마트 폴링 카운터 리셋")
        
        // 클립보드 내용 읽기 시도
        let newContent = pasteboard.string(forType: .string)
        print("📄 클립보드 내용 읽기 - 성공: \(newContent != nil), 비어있음: \(newContent?.isEmpty ?? true)")
        
        guard let content = newContent, !content.isEmpty, content != lastContent else {
            print("⚠️ 클립보드 내용 무시 - 비어있거나 이전과 동일")
            lastChangeCount = currentChangeCount
            return
        }
        
        print("✅ 새로운 클립보드 내용 확인: \(content.prefix(30))...")
        
        // 콘텐츠 필터링 검사
        if settings.shouldFilterContent(content) {
            print("콘텐츠 필터링으로 인해 동기화 차단: \(content.prefix(30))...")
            lastChangeCount = currentChangeCount
            lastContent = content
            return
        }
        
        lastChangeCount = currentChangeCount
        lastContent = content
        
        // AirDrop 수신 감지 (특정 패턴으로 감지)
        let isFromAirDrop = detectAirDropContent(content)
        
        // 새로운 클립보드 아이템 생성
        let newItem = ClipboardItem(
            content: content,
            timestamp: Date(),
            source: isFromAirDrop ? .remote : .local
        )
        
        // AirDrop 수신 알림
        if isFromAirDrop {
            NotificationManager.shared.sendAirdropReceiveNotification(content: content)
        } else {
            // 로컬 복사 푸시 알림 전송
            NotificationManager.shared.sendLocalCopyNotification(content: content)
        }
        
        DispatchQueue.main.async {
            print("📝 히스토리 저장 시도: \(content.prefix(30))...")
            
            // 히스토리 저장이 활성화된 경우에만 저장
            if self.settings.isHistoryEnabled {
                print("✅ 히스토리 저장 활성화됨")
                
                // 중복 제거 (같은 내용이 연속으로 나오는 경우)
                if let lastItem = self.history.first,
                   lastItem.content == content {
                    print("⚠️ 중복 내용 - 히스토리에 추가하지 않음")
                    return
                }
                
                self.history.insert(newItem, at: 0)
                print("✅ 히스토리에 추가됨 - 총 \(self.history.count)개 항목")
                
                // 설정된 최대 개수까지만 유지
                if self.history.count > self.settings.maxHistoryCount {
                    self.history = Array(self.history.prefix(self.settings.maxHistoryCount))
                    print("📦 히스토리 크기 제한 적용 - \(self.settings.maxHistoryCount)개로 제한")
                }
            } else {
                print("❌ 히스토리 저장 비활성화됨")
            }
            
            print("🎯 현재 히스토리 항목 수: \(self.history.count)")
        }
        
        // 블루투스로 다른 기기에 전송 (로컬 복사인 경우에만)
        if !isFromAirDrop {
            BluetoothManager.shared.sendToConnectedDevices(content: content)
        }
    }
    
    private func sendToConnectedDevices(_ content: String) {
        // 이 메서드는 더 이상 필요하지 않음 (BluetoothManager로 이동)
    }
    
    func receiveFromRemoteDevice(_ content: String) {
        let remoteItem = ClipboardItem(
            content: content,
            timestamp: Date(),
            source: .remote
        )
        
        DispatchQueue.main.async {
            self.history.insert(remoteItem, at: 0)
            
            // 자동으로 클립보드에 설정
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(content, forType: .string)
            
            // 원격 수신 푸시 알림 전송
            NotificationManager.shared.sendRemoteReceiveNotification(content: content, fromDevice: "Android")
            
            print("원격에서 수신: \(content.prefix(30))...")
        }
    }
    
    func clearHistory() {
        DispatchQueue.main.async {
            self.history.removeAll()
            print("클립보드 기록 삭제")
        }
    }
    
    func removeItem(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            self.history.removeAll { $0.id == item.id }
            print("클립보드 항목 삭제: \(item.preview)")
        }
    }
    
    // MARK: - 스마트 폴링 관리
    
    /**
     * 즉시 클립보드 체크 (앱 포그라운드 전환 시 사용)
     */
    func forceCheckClipboard() {
        print("🚀 즉시 클립보드 체크 요청")
        
        // 스마트 폴링이 중단된 경우 재시작
        if isSmartPollingStopped {
            print("🔄 스마트 폴링 재시작 (즉시 체크 요청)")
            resumeSmartPolling()
        }
        
        checkClipboard()
    }
    
    /**
     * 스마트 폴링 재시작
     */
    private func resumeSmartPolling() {
        isSmartPollingStopped = false
        noChangeCount = 0
        print("▶️ 스마트 폴링 활성 모드 재시작됨")
    }
    
    /**
     * 앱 포그라운드 전환 시 스마트 폴링 재시작
     */
    func onAppForeground() {
        if isSmartPollingStopped {
            print("🔄 앱 포그라운드 전환 - 스마트 폴링 재시작")
            resumeSmartPolling()
        }
    }
    
    // MARK: - AirDrop 감지
    
    /**
     * AirDrop으로부터 수신된 콘텐츠인지 감지
     * 실제 AirDrop 감지는 복잡하므로 기본적인 패턴 매칭으로 처리
     */
    private func detectAirDropContent(_ content: String) -> Bool {
        // AirDrop 특징적인 패턴들 (필요에 따라 확장 가능)
        let airdropPatterns = [
            "file://",  // 파일 경로
            ".txt", ".rtf", ".pdf",  // 일반적인 파일 확장자
            "Shared via AirDrop",  // AirDrop 공유 텍스트
        ]
        
        let contentLower = content.lowercased()
        for pattern in airdropPatterns {
            if contentLower.contains(pattern.lowercased()) {
                print("📤 AirDrop 콘텐츠 감지: \(pattern)")
                return true
            }
        }
        
        return false
    }
}