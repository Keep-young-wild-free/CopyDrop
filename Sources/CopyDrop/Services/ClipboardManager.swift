import AppKit
import Crypto

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var history: [ClipboardItem] = []
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var lastContent: String = ""
    private let settings = AppSettings.shared
    
    private init() {}
    
    func start() {
        // 초기 상태 저장
        lastChangeCount = NSPasteboard.general.changeCount
        lastContent = NSPasteboard.general.string(forType: .string) ?? ""
        
        // 설정에 따른 간격으로 클립보드 체크
        timer = Timer.scheduledTimer(withTimeInterval: settings.syncDelay, repeats: true) { _ in
            self.checkClipboard()
        }
        
        print("클립보드 감시 시작 (간격: \(settings.syncDelay)초)")
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        print("클립보드 감시 중지")
    }
    
    private func checkClipboard() {
        // 자동 동기화가 비활성화되어 있으면 중단
        guard settings.isAutoSyncEnabled else { return }
        
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        
        // changeCount가 변경되었는지 확인
        guard currentChangeCount != lastChangeCount else { return }
        
        guard let newContent = pasteboard.string(forType: .string),
              !newContent.isEmpty,
              newContent != lastContent else {
            lastChangeCount = currentChangeCount
            return
        }
        
        // 콘텐츠 필터링 검사
        if settings.shouldFilterContent(newContent) {
            print("콘텐츠 필터링으로 인해 동기화 차단: \(newContent.prefix(30))...")
            lastChangeCount = currentChangeCount
            lastContent = newContent
            return
        }
        
        lastChangeCount = currentChangeCount
        lastContent = newContent
        
        // 새로운 클립보드 아이템 생성
        let newItem = ClipboardItem(
            content: newContent,
            timestamp: Date(),
            source: .local
        )
        
        DispatchQueue.main.async {
            // 히스토리 저장이 활성화된 경우에만 저장
            if self.settings.isHistoryEnabled {
                // 중복 제거 (같은 내용이 연속으로 나오는 경우)
                if let lastItem = self.history.first,
                   lastItem.content == newContent {
                    return
                }
                
                self.history.insert(newItem, at: 0)
                
                // 설정된 최대 개수까지만 유지
                if self.history.count > self.settings.maxHistoryCount {
                    self.history = Array(self.history.prefix(self.settings.maxHistoryCount))
                }
            }
            
            print("새 클립보드 아이템: \(newContent.prefix(30))...")
        }
        
        // 블루투스로 다른 기기에 전송
        BluetoothManager.shared.sendToConnectedDevices(content: newContent)
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
}