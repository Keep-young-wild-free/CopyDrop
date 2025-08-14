//
//  SyncManager.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import Foundation
import SwiftData

/// 전체 동기화 시스템을 관리하는 통합 매니저
@MainActor
@Observable 
class SyncManager {
    // MARK: - Status Properties
    var isServerRunning: Bool { webSocketServer.isRunning }
    var isClientConnected: Bool { webSocketClient.isConnected }
    var isClipboardMonitoring: Bool { clipboardMonitor.isMonitoring }
    var connectionStatus: String {
        if isServerRunning && isClientConnected {
            return "서버 실행 중 + 클라이언트 연결됨"
        } else if isServerRunning {
            return "서버 실행 중 (연결 대기)"
        } else if isClientConnected {
            return "클라이언트로 연결됨"
        } else {
            return "동기화 중지됨"
        }
    }
    
    var syncedDevicesCount: Int { webSocketServer.connectedClients.count }
    var lastSyncTime: Date?
    
    // MARK: - Components
    private let webSocketServer: WebSocketServer
    private let webSocketClient: WebSocketClient
    private let clipboardMonitor: ClipboardMonitor
    private let errorHandler: ErrorHandler
    private let logger = Logger.shared
    
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    init(errorHandler: ErrorHandler? = nil) {
        self.errorHandler = errorHandler ?? ErrorHandler()
        self.webSocketServer = WebSocketServer(errorHandler: self.errorHandler)
        self.webSocketClient = WebSocketClient(errorHandler: self.errorHandler)
        self.clipboardMonitor = ClipboardMonitor(errorHandler: self.errorHandler)
        setupMessageHandlers()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        clipboardMonitor.setModelContext(context)
    }
    
    // MARK: - Public Interface
    
    /// 서버 모드로 동기화 시작
    func startAsServer() {
        logger.log("서버 모드로 동기화 시작")
        
        webSocketServer.startServer()
        startClipboardMonitoring()
    }
    
    /// 클라이언트 모드로 동기화 시작
    func startAsClient(serverURL: String) {
        guard let url = URL(string: serverURL),
              NetworkUtils.isValidWebSocketURL(serverURL) else {
            errorHandler.handle(.networkConnectionFailed("잘못된 서버 URL"))
            return
        }
        
        logger.log("클라이언트 모드로 동기화 시작: \(serverURL)")
        
        webSocketClient.connect(to: url)
        startClipboardMonitoring()
    }
    
    /// 동기화 중지
    func stopSync() {
        logger.log("동기화 중지")
        
        webSocketServer.stopServer()
        webSocketClient.disconnect()
        clipboardMonitor.stopMonitoring()
    }
    
    /// 수동으로 클립보드 내용 동기화
    func syncClipboard() {
        guard let content = getCurrentClipboardContent(), !content.isEmpty else {
            return
        }
        
        // 보안 필터링
        let filterResult = SecurityManager.shared.filterClipboardContent(content)
        guard filterResult.allowed else {
            if let reason = filterResult.reason {
                errorHandler.handle(.contentFiltered(reason))
            }
            return
        }
        
        // 속도 제한 확인
        let deviceInfo = DeviceInfo.current()
        guard SecurityManager.shared.checkRateLimit(for: deviceInfo.id) else {
            errorHandler.handle(.rateLimitExceeded)
            return
        }
        
        broadcastClipboardContent(content)
    }
    
    // MARK: - Private Methods
    
    private func setupMessageHandlers() {
        // WebSocket 서버 메시지 핸들러는 이미 내장됨 (브로드캐스트)
        
        // WebSocket 클라이언트 메시지 핸들러
        webSocketClient.onMessageReceived = { [weak self] data in
            self?.handleReceivedMessage(data)
        }
    }
    
    private func startClipboardMonitoring() {
        guard !clipboardMonitor.isMonitoring else { return }
        
        clipboardMonitor.startMonitoring()
        
        // 클립보드 변경 시 자동 동기화를 위한 타이머 설정
        setupClipboardSyncTimer()
    }
    
    private func setupClipboardSyncTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // 동기화가 활성화된 경우에만 자동 동기화
            if self.isServerRunning || self.isClientConnected {
                self.checkAndSyncClipboard()
            }
        }
    }
    
    private var lastSyncedContent: String = ""
    
    private func checkAndSyncClipboard() {
        guard let content = getCurrentClipboardContent(),
              !content.isEmpty,
              content != lastSyncedContent else {
            return
        }
        
        // 보안 필터링
        let filterResult = SecurityManager.shared.filterClipboardContent(content)
        guard filterResult.allowed else {
            return
        }
        
        lastSyncedContent = content
        broadcastClipboardContent(content)
    }
    
    private func broadcastClipboardContent(_ content: String) {
        let message = createClipboardMessage(content: content)
        
        guard let messageData = try? JSONSerialization.data(withJSONObject: message) else {
            logger.log("메시지 시리얼라이즈 실패", level: .error)
            return
        }
        
        // 암호화
        guard let encryptedData = encryptMessage(messageData) else {
            errorHandler.handle(.encryptionFailed)
            return
        }
        
        // 서버 모드: 연결된 클라이언트들에게 브로드캐스트
        if isServerRunning {
            webSocketServer.broadcastMessage(encryptedData)
        }
        
        // 클라이언트 모드: 서버에게 전송
        if isClientConnected {
            webSocketClient.sendMessage(encryptedData)
        }
        
        lastSyncTime = Date()
        logger.log("클립보드 내용 동기화됨: \(content.clipboardPreview)")
    }
    
    private func handleReceivedMessage(_ data: Data) {
        // 복호화
        guard let decryptedData = decryptMessage(data) else {
            errorHandler.handle(.decryptionFailed)
            return
        }
        
        // JSON 파싱
        guard let json = try? JSONSerialization.jsonObject(with: decryptedData) as? [String: Any],
              let payload = json["payload"] as? String,
              let hash = json["hash"] as? String else {
            errorHandler.handle(.invalidMessage)
            return
        }
        
        // 루프 방지: 자신이 보낸 메시지는 무시
        guard payload != lastSyncedContent else {
            return
        }
        
        // 클립보드에 설정
        setClipboardContent(payload)
        lastSyncedContent = payload
        lastSyncTime = Date()
        
        // 데이터베이스에 저장
        saveReceivedClipboardItem(content: payload, source: json["from"] as? String ?? "remote")
        
        logger.log("원격 클립보드 내용 수신: \(payload.clipboardPreview)")
    }
    
    private func createClipboardMessage(content: String) -> [String: Any] {
        let deviceInfo = DeviceInfo.current()
        
        return [
            "t": Int(Date().timeIntervalSince1970 * 1000),
            "from": deviceInfo.name,
            "deviceId": deviceInfo.id,
            "type": AppConstants.MessageTypes.text,
            "payload": content,
            "hash": ClipboardItem.sha256(content)
        ]
    }
    
    private func encryptMessage(_ data: Data) -> Data? {
        guard let key = SecurityManager.shared.getEncryptionKey() else {
            return nil
        }
        
        // 임시로 ClipboardSyncService의 암호화 사용
        let service = ClipboardSyncService(errorHandler: errorHandler)
        return service.testEncryptData(data)
    }
    
    private func decryptMessage(_ data: Data) -> Data? {
        // 임시로 ClipboardSyncService의 복호화 사용
        let service = ClipboardSyncService(errorHandler: errorHandler)
        return service.testDecryptData(data)
    }
    
    private func getCurrentClipboardContent() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }
    
    private func setClipboardContent(_ content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
    
    private func saveReceivedClipboardItem(content: String, source: String) {
        guard let context = modelContext else { return }
        
        let item = ClipboardItem(content: content, source: source, isLocal: false)
        context.insert(item)
        
        do {
            try context.save()
        } catch {
            logger.log("원격 클립보드 아이템 저장 실패: \(error)", level: .error)
        }
    }
}
