//
//  WebSocketClient.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import Foundation
import Network

/// WebSocket 클라이언트 (다른 디바이스의 서버에 연결)
@MainActor
@Observable
class WebSocketClient {
    var isConnected: Bool = false
    var connectionStatus: String = "연결 안됨"
    var lastMessageTime: Date?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private let logger = Logger.shared
    private let errorHandler: ErrorHandler
    
    // 메시지 핸들러
    var onMessageReceived: ((Data) -> Void)?
    
    init(errorHandler: ErrorHandler? = nil) {
        self.errorHandler = errorHandler ?? ErrorHandler()
        self.urlSession = URLSession(configuration: .default)
    }
    
    // MARK: - Connection Management
    
    func connect(to url: URL) {
        guard !isConnected else {
            logger.logNetwork("이미 연결된 상태입니다")
            return
        }
        
        logger.logNetwork("WebSocket 클라이언트 연결 시작: \(url)")
        connectionStatus = "연결 시도 중..."
        
        webSocketTask?.cancel()
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // 연결 상태 확인을 위한 핑 전송
        sendPing()
        
        // 메시지 수신 시작
        receiveMessage()
    }
    
    func disconnect() {
        guard isConnected else { return }
        
        logger.logNetwork("WebSocket 클라이언트 연결 해제")
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        isConnected = false
        connectionStatus = "연결 해제됨"
    }
    
    // MARK: - Message Handling
    
    func sendMessage(_ data: Data) {
        guard isConnected, let webSocketTask = webSocketTask else {
            logger.logNetwork("WebSocket이 연결되지 않음", level: .warning)
            return
        }
        
        webSocketTask.send(.data(data)) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.logger.logNetwork("메시지 전송 실패: \(error)", level: .error)
                    self?.handleConnectionError()
                } else {
                    self?.logger.logNetwork("메시지 전송 성공 (\(data.count) bytes)")
                }
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let message):
                    self.handleMessage(message)
                    self.receiveMessage() // 다음 메시지 대기
                    
                case .failure(let error):
                    self.logger.logNetwork("메시지 수신 실패: \(error)", level: .error)
                    self.handleConnectionError()
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        lastMessageTime = Date()
        
        switch message {
        case .data(let data):
            logger.logNetwork("데이터 메시지 수신 (\(data.count) bytes)")
            onMessageReceived?(data)
            
        case .string(let text):
            logger.logNetwork("텍스트 메시지 수신: \(text.prefix(50))")
            if let data = text.data(using: .utf8) {
                onMessageReceived?(data)
            }
            
        @unknown default:
            logger.logNetwork("알 수 없는 메시지 타입", level: .warning)
        }
    }
    
    private func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.logger.logNetwork("Ping 실패: \(error)", level: .error)
                    self?.handleConnectionError()
                } else {
                    self?.isConnected = true
                    self?.connectionStatus = "연결됨"
                    self?.logger.logNetwork("WebSocket 연결 성공")
                    
                    // 주기적 핑 시작
                    self?.schedulePing()
                }
            }
        }
    }
    
    private func schedulePing() {
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Network.pingInterval) { [weak self] in
            guard let self = self, self.isConnected else { return }
            
            self.webSocketTask?.sendPing { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.logger.logNetwork("정기 Ping 실패: \(error)", level: .warning)
                        self.handleConnectionError()
                    } else {
                        self.schedulePing() // 다음 핑 예약
                    }
                }
            }
        }
    }
    
    private func handleConnectionError() {
        isConnected = false
        connectionStatus = "연결 오류"
        
        // 자동 재연결 시도
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Network.reconnectDelay) { [weak self] in
            guard let self = self, let originalURL = self.webSocketTask?.originalRequest?.url else { return }
            
            self.logger.logNetwork("자동 재연결 시도")
            self.connect(to: originalURL)
        }
    }
}
