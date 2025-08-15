//
//  ClipboardSyncService.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import Foundation
import SwiftUI
import AppKit
import CryptoKit
import SwiftData

@MainActor
@Observable
class ClipboardSyncService {
    // MARK: - Properties
    var isConnected: Bool = false
    var connectionStatus: String = "연결 안됨"
    var lastSyncTime: Date?
    
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private var clipboardMonitorTimer: Timer?
    private var lastClipboardHash: String?
    private var modelContext: ModelContext?
    private let errorHandler: ErrorHandler
    
    // 암호화 키 (키체인에서 관리)
    private var encryptionKey: SymmetricKey?
    
    // MARK: - Initialization
    init(errorHandler: ErrorHandler? = nil) {
        self.urlSession = URLSession(configuration: .default)
        self.errorHandler = errorHandler ?? ErrorHandler()
        
        // 키체인에서 암호화 키 가져오기
        self.encryptionKey = SecurityManager.shared.getEncryptionKey()
        
        if encryptionKey == nil {
            // 키가 없으면 새로 생성
            self.encryptionKey = SecurityManager.shared.generateAndStoreEncryptionKey()
        }
    }
    
    // MARK: - Public Methods
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func startSync(serverURL: String) {
        guard let url = URL(string: serverURL) else {
            connectionStatus = "잘못된 URL"
            errorHandler.handle(.networkConnectionFailed("잘못된 URL 형식"))
            return
        }
        
        guard encryptionKey != nil else {
            errorHandler.handle(.invalidKey)
            return
        }
        
        connectWebSocket(url: url)
        startClipboardMonitoring()
    }
    
    func stopSync() {
        webSocket?.cancel()
        webSocket = nil
        clipboardMonitorTimer?.invalidate()
        clipboardMonitorTimer = nil
        isConnected = false
        connectionStatus = "연결 중단됨"
    }
    
    // MARK: - Private Methods
    private func connectWebSocket(url: URL) {
        webSocket?.cancel()
        webSocket = urlSession.webSocketTask(with: url)
        webSocket?.resume()
        
        connectionStatus = "연결 시도 중..."
        
        // 첫 메시지 수신 대기
        receiveMessage()
        
        // 연결 상태 확인을 위한 핑 전송
        sendPing()
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let message):
                    if case .data(let data) = message {
                        self.handleReceivedData(data)
                    }
                    self.receiveMessage() // 다음 메시지 대기
                    
                case .failure(let error):
                    print("WebSocket 수신 오류: \(error)")
                    self.handleConnectionError()
                }
            }
        }
    }
    
    private func sendPing() {
        webSocket?.sendPing { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Ping 실패: \(error)")
                    self?.handleConnectionError()
                } else {
                    self?.isConnected = true
                    self?.connectionStatus = "연결됨"
                }
            }
        }
    }
    
    private func handleConnectionError() {
        isConnected = false
        connectionStatus = "연결 실패"
        
        // 2초 후 재연결 시도
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if let webSocket = self.webSocket,
               let url = webSocket.originalRequest?.url {
                self.connectWebSocket(url: url)
            }
        }
    }
    
    private func handleReceivedData(_ data: Data) {
        guard let decryptedData = decryptData(data),
              let json = try? JSONSerialization.jsonObject(with: decryptedData) as? [String: Any],
              let payload = json["payload"] as? String,
              let hash = json["hash"] as? String else {
            return
        }
        
        // 루프 방지: 이미 처리한 해시인지 확인
        if lastClipboardHash != hash {
            setClipboardContent(payload)
            saveClipboardItem(content: payload, source: json["from"] as? String ?? "remote", isLocal: false)
            lastClipboardHash = hash
            lastSyncTime = Date()
        }
    }
    
    private func startClipboardMonitoring() {
        clipboardMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboardChanges()
        }
    }
    
    private func checkClipboardChanges() {
        guard let clipboardContent = NSPasteboard.general.string(forType: .string) else {
            return
        }
        
        // 내용 필터링 검사
        let filterResult = SecurityManager.shared.filterClipboardContent(clipboardContent)
        if !filterResult.allowed {
            if let reason = filterResult.reason {
                errorHandler.handle(.contentFiltered(reason))
            }
            return
        }
        
        let currentHash = ClipboardItem.sha256(clipboardContent)
        
        if currentHash != lastClipboardHash {
            // 속도 제한 검사
            let deviceInfo = DeviceInfo.current()
            if !SecurityManager.shared.checkRateLimit(for: deviceInfo.id) {
                errorHandler.handle(.rateLimitExceeded)
                return
            }
            
            lastClipboardHash = currentHash
            sendClipboardUpdate(content: clipboardContent, hash: currentHash)
            saveClipboardItem(content: clipboardContent, source: "local", isLocal: true)
        }
    }
    
    private func sendClipboardUpdate(content: String, hash: String) {
        let message: [String: Any] = [
            "t": Int(Date().timeIntervalSince1970 * 1000),
            "from": "mac-\(Host.current().localizedName ?? "unknown")",
            "type": "text",
            "payload": content,
            "hash": hash
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let encryptedData = encryptData(jsonData) else {
            return
        }
        
        webSocket?.send(.data(encryptedData)) { error in
            if let error = error {
                print("메시지 전송 실패: \(error)")
            }
        }
    }
    
    private func setClipboardContent(_ content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
    
    private func saveClipboardItem(content: String, source: String, isLocal: Bool) {
        guard let context = modelContext else { return }
        
        let item = ClipboardItem(content: content, source: source, isLocal: isLocal)
        context.insert(item)
        
        do {
            try context.save()
        } catch {
            print("클립보드 아이템 저장 실패: \(error)")
        }
    }
    
    // MARK: - Encryption/Decryption
    internal func encryptData(_ data: Data) -> Data? {
        guard let key = encryptionKey else {
            errorHandler.handle(.invalidKey)
            return nil
        }
        
        let iv = Data((0..<12).map { _ in UInt8.random(in: 0...255) })
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key, nonce: AES.GCM.Nonce(data: iv))
            return iv + sealedBox.ciphertext + sealedBox.tag
        } catch {
            errorHandler.handle(.encryptionFailed)
            Logger.shared.log("암호화 실패: \(error)", level: LogLevel.error)
            return nil
        }
    }
    
    internal func decryptData(_ data: Data) -> Data? {
        guard let key = encryptionKey else {
            errorHandler.handle(.invalidKey)
            return nil
        }
        
        guard data.count >= 12 + 16 else { 
            errorHandler.handle(.invalidMessage)
            return nil 
        }
        
        let iv = data.prefix(12)
        let tag = data.suffix(16)
        let ciphertext = data.dropFirst(12).dropLast(16)
        
        do {
            let nonce = try AES.GCM.Nonce(data: iv)
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            errorHandler.handle(.decryptionFailed)
            Logger.shared.log("복호화 실패: \(error)", level: LogLevel.error)
            return nil
        }
    }
}
