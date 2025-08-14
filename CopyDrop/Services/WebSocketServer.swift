//
//  WebSocketServer.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import Foundation
import Network
import CryptoKit

@MainActor
@Observable
class WebSocketServer {
    // MARK: - Properties
    var isRunning: Bool = false
    var serverPort: UInt16 = 8787
    var connectedClients: [NWConnection] = []
    var serverStatus: String = "서버 중지됨"
    
    private var listener: NWListener?
    private var encryptionKey: SymmetricKey
    private let errorHandler: ErrorHandler
    
    // MARK: - Initialization
    init(errorHandler: ErrorHandler? = nil) {
        self.errorHandler = errorHandler ?? ErrorHandler()
        // 키체인에서 암호화 키 가져오기
        self.encryptionKey = SecurityManager.shared.getEncryptionKey() ?? SecurityManager.shared.generateAndStoreEncryptionKey() ?? SymmetricKey(size: .bits256)
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
                self?.handleNewConnection(connection)
            }
            
            listener?.start(queue: .main)
            
        } catch {
            serverStatus = "서버 시작 실패: \(error.localizedDescription)"
            print("서버 시작 실패: \(error)")
        }
    }
    
    func stopServer() {
        listener?.cancel()
        listener = nil
        
        // 모든 클라이언트 연결 종료
        for connection in connectedClients {
            connection.cancel()
        }
        connectedClients.removeAll()
        
        isRunning = false
        serverStatus = "서버 중지됨"
    }
    
    func broadcastMessage(_ data: Data) {
        for connection in connectedClients {
            if connection.state == .ready {
                sendData(data, to: connection)
            }
        }
        
        // 비활성 연결 제거
        connectedClients.removeAll { $0.state != .ready }
    }
    
    // MARK: - Private Methods
    private func handleNewConnection(_ connection: NWConnection) {
        print("새 클라이언트 연결: \(connection.endpoint)")
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("클라이언트 연결 완료")
                DispatchQueue.main.async {
                    self?.connectedClients.append(connection)
                }
                self?.receiveData(from: connection)
                
            case .failed(let error):
                print("클라이언트 연결 실패: \(error)")
                
            case .cancelled:
                print("클라이언트 연결 취소됨")
                DispatchQueue.main.async {
                    self?.connectedClients.removeAll { $0 === connection }
                }
                
            default:
                break
            }
        }
        
        connection.start(queue: .main)
    }
    
    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let error = error {
                print("데이터 수신 오류: \(error)")
                return
            }
            
            if let data = data, !data.isEmpty {
                // 받은 데이터를 다른 클라이언트들에게 브로드캐스트
                DispatchQueue.main.async {
                    self?.broadcastToOthers(data, except: connection)
                }
            }
            
            if !isComplete {
                self?.receiveData(from: connection)
            }
        }
    }
    
    private func sendData(_ data: Data, to connection: NWConnection) {
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("데이터 전송 오류: \(error)")
            }
        })
    }
    
    private func broadcastToOthers(_ data: Data, except excludeConnection: NWConnection) {
        for connection in connectedClients {
            if connection !== excludeConnection && connection.state == .ready {
                sendData(data, to: connection)
            }
        }
    }
    
    // MARK: - Network Discovery
    func getLocalIPAddress() -> String? {
        return NetworkUtils.getLocalIPAddress()
    }
}

// Network discovery를 위한 C 함수들 import
import Darwin.C
