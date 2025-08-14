//
//  WebSocketServer.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//  표준 WebSocket 프로토콜 구현으로 안드로이드 앱과 호환
//

import Foundation
import Network
import CryptoKit
import CommonCrypto

@MainActor
@Observable
class WebSocketServer: NSObject {
    // MARK: - Properties
    var isRunning: Bool = false
    var serverPort: UInt16 = AppConstants.Network.defaultPort
    var connectedClients: [WebSocketConnection] = []
    var serverStatus: String = "서버 중지됨"
    
    private var listener: NWListener?
    private var broadcastListener: NWListener?
    private var bonjourService: NetService?
    private var encryptionKey: SymmetricKey
    private let errorHandler: ErrorHandler
    private let broadcastPort: UInt16 = 8787
    
    // MARK: - Initialization
    init(errorHandler: ErrorHandler? = nil) {
        self.errorHandler = errorHandler ?? ErrorHandler()
        // 키체인에서 암호화 키 가져오기
        self.encryptionKey = SecurityManager.shared.getEncryptionKey() ?? SecurityManager.shared.generateAndStoreEncryptionKey() ?? SymmetricKey(size: .bits256)
        super.init()
    }
    
    // MARK: - Public Methods
    func startServer() {
        do {
            let parameters = NWParameters(tls: nil, tcp: NWProtocolTCP.Options())
            parameters.allowLocalEndpointReuse = true
            parameters.includePeerToPeer = true
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: serverPort))
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.serverStatus = "서버 실행 중 (포트: \(self?.serverPort ?? 0))"
                        print("WebSocket 서버가 포트 \(self?.serverPort ?? 0)에서 시작되었습니다")
                        
                    case .failed(let error):
                        self?.isRunning = false
                        self?.serverStatus = "서버 오류: \(error.localizedDescription)"
                        print("서버 오류: \(error)")
                        
                    case .cancelled:
                        self?.isRunning = false
                        self?.serverStatus = "서버 중지됨"
                        
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleNewConnection(connection)
                }
            }
            
            listener?.start(queue: .main)
            
            // 브로드캐스트 리스너 시작
            startBroadcastListener()
            
            // Bonjour 서비스 시작
            startBonjourService()
            
        } catch {
            serverStatus = "서버 시작 실패: \(error.localizedDescription)"
            print("서버 시작 실패: \(error)")
        }
    }
    
    func stopServer() {
        listener?.cancel()
        listener = nil
        
        // 브로드캐스트 리스너 중지
        broadcastListener?.cancel()
        broadcastListener = nil
        
        // Bonjour 서비스 중지
        stopBonjourService()
        
        // 모든 클라이언트 연결 종료
        for client in connectedClients {
            client.connection.cancel()
        }
        connectedClients.removeAll()
        
        isRunning = false
        serverStatus = "서버 중지됨"
    }
    
    func broadcastMessage(_ data: Data) {
        for client in connectedClients {
            if client.connection.state == .ready && client.isConnected {
                sendWebSocketMessage(data, to: client)
            }
        }
        
        // 비활성 연결 제거
        connectedClients.removeAll { !$0.isConnected || $0.connection.state != .ready }
    }
    
    // MARK: - Private Methods
    private func handleNewConnection(_ connection: NWConnection) {
        print("새 클라이언트 연결 시도: \(connection.endpoint)")
        
        let webSocketConnection = WebSocketConnection(connection: connection)
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("TCP 연결 완료, WebSocket 핸드셰이크 대기 중...")
                Task { @MainActor in
                    self?.receiveHandshake(from: webSocketConnection)
                }
                
            case .failed(let error):
                print("클라이언트 연결 실패: \(error)")
                
            case .cancelled:
                print("클라이언트 연결 취소됨")
                DispatchQueue.main.async {
                    self?.connectedClients.removeAll { $0.id == webSocketConnection.id }
                }
                
            default:
                break
            }
        }
        
        connection.start(queue: .main)
    }
    
    private func receiveHandshake(from client: WebSocketConnection) {
        client.connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            if let error = error {
                print("핸드셰이크 수신 오류: \(error)")
                return
            }
            
            guard let data = data, !data.isEmpty,
                  let request = String(data: data, encoding: .utf8) else {
                print("잘못된 핸드셰이크 데이터")
                return
            }
            
            print("수신된 핸드셰이크:\n\(request)")
            
            Task { @MainActor in
                self?.handleWebSocketHandshake(request, for: client)
            }
        }
    }
    
    private func handleWebSocketHandshake(_ request: String, for client: WebSocketConnection) {
        let lines = request.components(separatedBy: "\r\n")
        
        // HTTP 요청 라인 확인
        guard let requestLine = lines.first,
              requestLine.contains("GET") && requestLine.contains("HTTP/1.1") else {
            print("잘못된 HTTP 요청 라인")
            client.connection.cancel()
            return
        }
        
        // WebSocket 키 추출
        var webSocketKey: String?
        var isWebSocketUpgrade = false
        var connectionUpgrade = false
        
        for line in lines {
            let components = line.components(separatedBy: ": ")
            guard components.count == 2 else { continue }
            
            let header = components[0].lowercased()
            let value = components[1]
            
            switch header {
            case "sec-websocket-key":
                webSocketKey = value
            case "upgrade":
                isWebSocketUpgrade = value.lowercased() == "websocket"
            case "connection":
                connectionUpgrade = value.lowercased().contains("upgrade")
            default:
                break
            }
        }
        
        guard let key = webSocketKey, isWebSocketUpgrade, connectionUpgrade else {
            print("WebSocket 핸드셰이크 요구사항 불충족")
            client.connection.cancel()
            return
        }
        
        // WebSocket Accept 키 생성
        let acceptKey = generateWebSocketAcceptKey(from: key)
        
        // HTTP 응답 생성
        let response = """
        HTTP/1.1 101 Switching Protocols\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Accept: \(acceptKey)\r
        \r

        """
        
        guard let responseData = response.data(using: .utf8) else {
            print("응답 데이터 생성 실패")
            client.connection.cancel()
            return
        }
        
        // 핸드셰이크 응답 전송
        client.connection.send(content: responseData, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("핸드셰이크 응답 전송 실패: \(error)")
                client.connection.cancel()
            } else {
                print("WebSocket 핸드셰이크 완료!")
                DispatchQueue.main.async {
                    client.isConnected = true
                    self?.connectedClients.append(client)
                    self?.receiveWebSocketData(from: client)
                }
            }
        })
    }
    
    private func generateWebSocketAcceptKey(from key: String) -> String {
        let websocketGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let combined = key + websocketGUID
        
        guard let data = combined.data(using: .utf8) else {
            return ""
        }
        
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA1(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        
        let hashData = Data(hash)
        return hashData.base64EncodedString()
    }
    
    private func receiveWebSocketData(from client: WebSocketConnection) {
        client.connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let error = error {
                print("WebSocket 데이터 수신 오류: \(error)")
                DispatchQueue.main.async {
                    self?.connectedClients.removeAll { $0.id == client.id }
                }
                return
            }
            
            if let data = data, !data.isEmpty {
                // WebSocket 프레임 파싱
                if let message = self?.parseWebSocketFrame(data) {
                    print("WebSocket 메시지 수신: \(message.count) bytes")
                    
                    // 다른 클라이언트들에게 브로드캐스트
                    DispatchQueue.main.async {
                        self?.broadcastToOthers(message, except: client)
                    }
                }
            }
            
            if !isComplete {
                Task { @MainActor in
                    self?.receiveWebSocketData(from: client)
                }
            } else {
                // 연결 종료
                DispatchQueue.main.async {
                    self?.connectedClients.removeAll { $0.id == client.id }
                }
            }
        }
    }
    
    private func parseWebSocketFrame(_ data: Data) -> Data? {
        guard data.count >= 2 else { return nil }
        
        let bytes = [UInt8](data)
        
        // 첫 번째 바이트: FIN(1) + RSV(3) + Opcode(4)
        let firstByte = bytes[0]
        let opcode = firstByte & 0x0F
        
        // 두 번째 바이트: MASK(1) + Payload Length(7)
        let secondByte = bytes[1]
        let masked = (secondByte & 0x80) != 0
        var payloadLength = UInt64(secondByte & 0x7F)
        
        var index = 2
        
        // 확장된 payload length
        if payloadLength == 126 {
            guard data.count >= index + 2 else { return nil }
            payloadLength = UInt64(bytes[index]) << 8 + UInt64(bytes[index + 1])
            index += 2
        } else if payloadLength == 127 {
            guard data.count >= index + 8 else { return nil }
            payloadLength = 0
            for i in 0..<8 {
                payloadLength = payloadLength << 8 + UInt64(bytes[index + i])
            }
            index += 8
        }
        
        // 마스킹 키
        var maskingKey: [UInt8] = []
        if masked {
            guard data.count >= index + 4 else { return nil }
            maskingKey = Array(bytes[index..<index + 4])
            index += 4
        }
        
        // 페이로드 데이터
        guard data.count >= index + Int(payloadLength) else { return nil }
        var payload = Array(bytes[index..<index + Int(payloadLength)])
        
        // 마스킹 해제
        if masked {
            for i in 0..<payload.count {
                payload[i] ^= maskingKey[i % 4]
            }
        }
        
        // 텍스트 프레임(0x1) 또는 바이너리 프레임(0x2)만 처리
        if opcode == 0x1 || opcode == 0x2 {
            return Data(payload)
        }
        
        return nil
    }
    
    private func sendWebSocketMessage(_ data: Data, to client: WebSocketConnection) {
        let frame = createWebSocketFrame(data: data)
        client.connection.send(content: frame, completion: .contentProcessed { error in
            if let error = error {
                print("WebSocket 메시지 전송 오류: \(error)")
            }
        })
    }
    
    private func createWebSocketFrame(data: Data) -> Data {
        var frame = Data()
        
        // 첫 번째 바이트: FIN=1, Opcode=0x2 (바이너리)
        frame.append(0x82)
        
        // Payload length
        if data.count < 126 {
            frame.append(UInt8(data.count))
        } else if data.count < 65536 {
            frame.append(126)
            frame.append(UInt8(data.count >> 8))
            frame.append(UInt8(data.count & 0xFF))
        } else {
            frame.append(127)
            let length = UInt64(data.count)
            for i in stride(from: 56, through: 0, by: -8) {
                frame.append(UInt8((length >> i) & 0xFF))
            }
        }
        
        // Payload data
        frame.append(data)
        
        return frame
    }
    
    private func broadcastToOthers(_ data: Data, except excludeClient: WebSocketConnection) {
        for client in connectedClients {
            if client.id != excludeClient.id && client.connection.state == .ready && client.isConnected {
                sendWebSocketMessage(data, to: client)
            }
        }
    }
    
    // MARK: - Network Discovery
    func getLocalIPAddress() -> String? {
        return NetworkUtils.getLocalIPAddress()
    }
    
    // MARK: - Broadcast Discovery
    
    /// 브로드캐스트 리스너 시작
    private func startBroadcastListener() {
        do {
            let udpParameters = NWParameters.udp
            udpParameters.allowLocalEndpointReuse = true
            
            broadcastListener = try NWListener(using: udpParameters, on: NWEndpoint.Port(integerLiteral: broadcastPort))
            
            broadcastListener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleBroadcastConnection(connection)
                }
            }
            
            broadcastListener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("브로드캐스트 리스너가 포트 \(self.broadcastPort)에서 시작되었습니다")
                case .failed(let error):
                    print("브로드캐스트 리스너 오류: \(error)")
                case .cancelled:
                    print("브로드캐스트 리스너 중지됨")
                default:
                    break
                }
            }
            
            broadcastListener?.start(queue: DispatchQueue.global(qos: .utility))
            
        } catch {
            print("브로드캐스트 리스너 시작 실패: \(error)")
        }
    }
    
    /// 브로드캐스트 연결 처리
    private func handleBroadcastConnection(_ connection: NWConnection) {
        connection.start(queue: DispatchQueue.global(qos: .utility))
        
        // UDP 메시지 수신
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            guard let data = data,
                  let message = String(data: data, encoding: .utf8) else {
                return
            }
            
            Task { @MainActor in
                self?.processBroadcastMessage(message, connection: connection)
            }
        }
    }
    
    /// 브로드캐스트 메시지 처리
    private func processBroadcastMessage(_ message: String, connection: NWConnection) {
        // JSON 파싱 시도
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        // 디스커버리 요청인지 확인
        guard let type = json["type"] as? String,
              type == "COPYDROP_DISCOVERY_REQUEST" else {
            return
        }
        
        print("브로드캐스트 디스커버리 요청 수신")
        
        // 응답 생성
        let response = createDiscoveryResponse()
        
        // 응답 전송
        if let responseData = response.data(using: .utf8) {
            connection.send(content: responseData, completion: .contentProcessed { error in
                if let error = error {
                    print("브로드캐스트 응답 전송 오류: \(error)")
                } else {
                    print("브로드캐스트 응답 전송 완료")
                }
            })
        }
    }
    
    /// 디스커버리 응답 생성
    private func createDiscoveryResponse() -> String {
        let deviceInfo = DeviceInfo.current()
        
        let response: [String: Any] = [
            "type": "COPYDROP_DISCOVERY_RESPONSE",
            "version": "1.0",
            "deviceId": deviceInfo.id,
            "deviceName": deviceInfo.name,
            "deviceType": deviceInfo.type,
            "ipAddress": getLocalIPAddress() ?? "unknown",
            "port": Int(serverPort),
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: response),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "COPYDROP_DISCOVERY_RESPONSE"
    }
    
    // MARK: - Bonjour Service Discovery
    
    /// Bonjour 서비스 시작
    private func startBonjourService() {
        let deviceInfo = DeviceInfo.current()
        
        // TXT 레코드 생성
        let txtRecord: [String: Data] = [
            "name": deviceInfo.name.data(using: .utf8) ?? Data(),
            "id": deviceInfo.id.data(using: .utf8) ?? Data(),
            "type": deviceInfo.type.data(using: .utf8) ?? Data(),
            "version": (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0").data(using: .utf8) ?? Data(),
            "path": "/ws".data(using: .utf8) ?? Data()
        ]
        
        bonjourService = NetService(
            domain: "local.",
            type: "_copydrop._tcp.",
            name: "\(deviceInfo.name) - CopyDrop",
            port: Int32(serverPort)
        )
        
        bonjourService?.setTXTRecord(NetService.data(fromTXTRecord: txtRecord))
        bonjourService?.delegate = self
        bonjourService?.publish()
        
        print("Bonjour 서비스 시작: _copydrop._tcp.local. 포트 \(serverPort)")
    }
    
    /// Bonjour 서비스 중지
    private func stopBonjourService() {
        bonjourService?.stop()
        bonjourService = nil
        print("Bonjour 서비스 중지됨")
    }
}

// MARK: - WebSocket Connection
class WebSocketConnection {
    let id = UUID()
    let connection: NWConnection
    var isConnected = false
    
    init(connection: NWConnection) {
        self.connection = connection
    }
}

// MARK: - NetService Delegate
extension WebSocketServer: NetServiceDelegate {
    nonisolated func netServiceDidPublish(_ sender: NetService) {
        Task { @MainActor in
            print("Bonjour 서비스 퍼블리시 성공: \(sender.name)")
        }
    }
    
    nonisolated func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        Task { @MainActor in
            print("Bonjour 서비스 퍼블리시 실패: \(errorDict)")
        }
    }
    
    nonisolated func netServiceDidStop(_ sender: NetService) {
        Task { @MainActor in
            print("Bonjour 서비스 중지됨: \(sender.name)")
        }
    }
}

// Network discovery를 위한 C 함수들 import
import Darwin.C