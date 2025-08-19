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
        
        // 클립보드 내용 읽기 시도 (이미지 우선, 텍스트 차순)
        var clipboardItem: ClipboardItem?
        
        // 1. 이미지 확인
        if let imageData = getImageFromPasteboard(pasteboard) {
            print("🖼️ 이미지 클립보드 감지 - 크기: \(imageData.count / 1024) KB")
            // 고유한 content 생성 (타임스탬프 + 데이터 해시)
            let timestamp = Date()
            let dataHash = imageData.hashValue
            let content = "Image_\(timestamp.timeIntervalSince1970)_\(dataHash)"
            
            clipboardItem = ClipboardItem(
                content: content,
                timestamp: timestamp,
                source: .local,
                type: .image,
                imageData: imageData
            )
        }
        // 2. 텍스트 확인
        else if let textContent = pasteboard.string(forType: .string), !textContent.isEmpty {
            print("📄 텍스트 클립보드 감지")
            guard textContent != lastContent else {
                print("⚠️ 클립보드 텍스트 무시 - 이전과 동일")
                lastChangeCount = currentChangeCount
                return
            }
            clipboardItem = ClipboardItem(
                content: textContent,
                timestamp: Date(),
                source: .local,
                type: .text
            )
            lastContent = textContent
        }
        else {
            print("⚠️ 클립보드 내용 무시 - 지원하지 않는 형식이거나 비어있음")
            lastChangeCount = currentChangeCount
            return
        }
        
        guard let newItem = clipboardItem else { return }
        
        print("✅ 새로운 클립보드 내용 확인: \(newItem.preview)")
        
        // 텍스트인 경우에만 콘텐츠 필터링 검사
        if newItem.type == .text && settings.shouldFilterContent(newItem.content) {
            print("콘텐츠 필터링으로 인해 동기화 차단: \(newItem.content.prefix(30))...")
            lastChangeCount = currentChangeCount
            return
        }
        
        lastChangeCount = currentChangeCount
        
        // AirDrop 수신 감지 (텍스트인 경우에만)
        let isFromAirDrop = newItem.type == .text ? detectAirDropContent(newItem.content) : false
        
        // AirDrop인 경우 소스 업데이트
        let finalItem = isFromAirDrop ? ClipboardItem(
            content: newItem.content,
            timestamp: newItem.timestamp,
            source: .remote,
            type: newItem.type,
            imageData: newItem.imageData
        ) : newItem
        
        // AirDrop 수신 알림
        if isFromAirDrop {
            NotificationManager.shared.sendAirdropReceiveNotification(content: finalItem.content)
        } else {
            // 로컬 복사 푸시 알림 전송
            NotificationManager.shared.sendLocalCopyNotification(content: finalItem.content)
        }
        
        DispatchQueue.main.async {
            print("📝 히스토리 저장 시도: \(finalItem.preview)")
            
            // 히스토리 저장이 활성화된 경우에만 저장
            if self.settings.isHistoryEnabled {
                print("✅ 히스토리 저장 활성화됨")
                
                // 중복 제거 (같은 내용이 연속으로 나오는 경우)
                if let lastItem = self.history.first {
                    let isDuplicate: Bool
                    
                    if finalItem.type == .image && lastItem.type == .image {
                        // 이미지의 경우 실제 데이터를 비교
                        isDuplicate = finalItem.imageData == lastItem.imageData
                    } else {
                        // 텍스트의 경우 내용을 비교
                        isDuplicate = lastItem.content == finalItem.content && lastItem.type == finalItem.type
                    }
                    
                    if isDuplicate {
                        print("⚠️ 중복 내용 - 히스토리에 추가하지 않음")
                        return
                    }
                }
                
                self.history.insert(finalItem, at: 0)
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
        
        // 블루투스로 다른 기기에 전송 (로컬 복사이고 텍스트인 경우에만)
        if !isFromAirDrop && finalItem.type == .text {
            BluetoothManager.shared.sendToConnectedDevices(content: finalItem.content)
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
     * 앱 포그라운드 전환 시 스마트 폴링 재시작 및 Android 동기화 요청
     */
    func onAppForeground() {
        if isSmartPollingStopped {
            print("🔄 앱 포그라운드 전환 - 스마트 폴링 재시작")
            resumeSmartPolling()
        }
        
        // Android에게 클립보드 동기화 요청
        BluetoothManager.shared.requestSyncFromAndroid()
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
    
    // MARK: - 이미지 클립보드 처리
    
    /**
     * 클립보드에서 이미지 데이터 추출
     */
    private func getImageFromPasteboard(_ pasteboard: NSPasteboard) -> Data? {
        // 지원하는 이미지 타입들
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .tiff, .png, .pdf, .fileURL
        ]
        
        for type in imageTypes {
            if let data = pasteboard.data(forType: type) {
                // TIFF 데이터인 경우 PNG로 변환
                if type == .tiff {
                    if let image = NSImage(data: data),
                       let pngData = convertImageToPNG(image) {
                        print("✅ TIFF 이미지를 PNG로 변환 성공")
                        return pngData
                    }
                }
                // PNG, PDF 등은 그대로 사용
                else if type == .png || type == .pdf {
                    print("✅ \(type.rawValue) 이미지 데이터 추출 성공")
                    return data
                }
                // 파일 URL인 경우 이미지 파일인지 확인
                else if type == .fileURL,
                        let url = URL(dataRepresentation: data, relativeTo: nil),
                        isImageFile(url: url) {
                    do {
                        let imageData = try Data(contentsOf: url)
                        print("✅ 이미지 파일에서 데이터 추출 성공: \(url.lastPathComponent)")
                        return imageData
                    } catch {
                        print("❌ 이미지 파일 읽기 실패: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        return nil
    }
    
    /**
     * NSImage를 PNG 데이터로 변환
     */
    private func convertImageToPNG(_ image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmapImage.representation(using: .png, properties: [:])
    }
    
    /**
     * URL이 이미지 파일인지 확인
     */
    private func isImageFile(url: URL) -> Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "webp"]
        let fileExtension = url.pathExtension.lowercased()
        return imageExtensions.contains(fileExtension)
    }
}