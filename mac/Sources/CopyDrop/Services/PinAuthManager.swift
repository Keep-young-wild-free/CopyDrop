import Foundation
import CryptoKit

/**
 * Pin 기반 인증 관리 클래스 (Mac용)
 * - Pin 생성 및 관리
 * - 세션 토큰 검증
 * - 자동 재연결 지원
 */
class PinAuthManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = PinAuthManager()
    
    // MARK: - Properties
    @Published var currentPin: String?
    @Published var isWaitingForAuth = false
    @Published var connectedDevices: Set<String> = []
    @Published var clipboardHistory: [ClipboardHubEntry] = []
    
    private var pinExpirationTimer: Timer?
    private var activeSessions: [String: SessionInfo] = [:]
    private var deviceClipboardStates: [String: String] = [:] // deviceId -> lastClipboard
    
    // MARK: - Constants
    private let pinLength = 4
    private let pinValiditySeconds = 300 // 5분
    private let sessionValidityHours = 24
    
    // MARK: - Data Structures
    struct SessionInfo {
        let token: String
        let deviceId: String
        let createdAt: Date
        let expiresAt: Date
    }
    
    struct ClipboardHubEntry: Hashable {
        let id: String
        let content: String
        let sourceDevice: String
        let timestamp: Date
        let syncedDevices: Set<String>
        
        init(content: String, sourceDevice: String) {
            self.id = UUID().uuidString
            self.content = content
            self.sourceDevice = sourceDevice
            self.timestamp = Date()
            self.syncedDevices = [sourceDevice]
        }
        
        // Hashable 구현
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: ClipboardHubEntry, rhs: ClipboardHubEntry) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    struct AuthRequest: Codable {
        let pin: String
        let deviceId: String
        let timestamp: TimeInterval
    }
    
    struct AuthResponse: Codable {
        let success: Bool
        let sessionToken: String?
        let error: String?
        let timestamp: TimeInterval
        
        init(success: Bool, sessionToken: String? = nil, error: String? = nil) {
            self.success = success
            self.sessionToken = sessionToken
            self.error = error
            self.timestamp = Date().timeIntervalSince1970 * 1000
        }
    }
    
    struct ReconnectRequest: Codable {
        let sessionToken: String
        let deviceId: String
        let timestamp: TimeInterval
    }
    
    // MARK: - Pin Management
    
    /**
     * 새 Pin 생성
     */
    func generateNewPin() -> String {
        let pin = String(format: "%04d", Int.random(in: 1000...9999))
        
        DispatchQueue.main.async {
            self.currentPin = pin
            self.isWaitingForAuth = true
        }
        
        // Pin 만료 타이머 설정
        pinExpirationTimer?.invalidate()
        pinExpirationTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(pinValiditySeconds), repeats: false) { _ in
            self.expireCurrentPin()
        }
        
        print("🔐 새 Pin 생성: \(pin) (\(pinValiditySeconds)초 유효)")
        return pin
    }
    
    /**
     * Pin 만료 처리
     */
    private func expireCurrentPin() {
        DispatchQueue.main.async {
            self.currentPin = nil
            self.isWaitingForAuth = false
        }
        print("⏰ Pin 만료됨")
    }
    
    /**
     * Pin 검증
     */
    func validatePin(_ inputPin: String) -> Bool {
        guard let currentPin = currentPin else {
            print("❌ Pin 검증 실패: 현재 Pin 없음")
            return false
        }
        
        let isValid = inputPin == currentPin && inputPin.count == pinLength
        print("🔍 Pin 검증 결과: \(isValid) (입력: \(inputPin), 현재: \(currentPin))")
        
        return isValid
    }
    
    // MARK: - Session Management
    
    /**
     * 새 세션 토큰 생성
     */
    private func generateSessionToken() -> String {
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let timestamp = String(Int(Date().timeIntervalSince1970))
        return "\(uuid)_\(timestamp)"
    }
    
    /**
     * 세션 생성
     */
    func createSession(for deviceId: String) -> String {
        let token = generateSessionToken()
        let session = SessionInfo(
            token: token,
            deviceId: deviceId,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(TimeInterval(sessionValidityHours * 3600))
        )
        
        activeSessions[token] = session
        
        DispatchQueue.main.async {
            self.connectedDevices.insert(deviceId)
        }
        
        print("✅ 새 세션 생성: \(deviceId) -> \(token.prefix(8))...")
        return token
    }
    
    /**
     * 세션 토큰 검증
     */
    func validateSessionToken(_ token: String, deviceId: String) -> Bool {
        guard let session = activeSessions[token] else {
            print("❌ 세션 토큰 없음: \(token.prefix(8))...")
            return false
        }
        
        // 만료 확인
        if Date() > session.expiresAt {
            print("⏰ 세션 토큰 만료: \(token.prefix(8))...")
            activeSessions.removeValue(forKey: token)
            return false
        }
        
        // 디바이스 ID 확인
        let isValid = session.deviceId == deviceId
        print("🔍 세션 토큰 검증: \(isValid) (\(deviceId))")
        
        if isValid {
            DispatchQueue.main.async {
                self.connectedDevices.insert(deviceId)
            }
        }
        
        return isValid
    }
    
    /**
     * 세션 제거
     */
    func removeSession(_ token: String) {
        if let session = activeSessions.removeValue(forKey: token) {
            DispatchQueue.main.async {
                self.connectedDevices.remove(session.deviceId)
            }
            print("🗑️ 세션 제거: \(session.deviceId)")
        }
    }
    
    // MARK: - Message Processing
    
    /**
     * 인증 요청 처리
     */
    func processAuthRequest(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let messageDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              messageDict["type"] as? String == "auth_request",
              let authData = messageDict["data"] as? [String: Any] else {
            print("❌ 인증 요청 파싱 실패")
            return nil
        }
        
        guard let pin = authData["pin"] as? String,
              let deviceId = authData["deviceId"] as? String else {
            print("❌ 인증 요청 데이터 누락")
            return createAuthResponseMessage(success: false, error: "Invalid request data")
        }
        
        // Pin 검증
        if validatePin(pin) {
            // Pin 인증 성공 - 세션 생성
            let sessionToken = createSession(for: deviceId)
            
            // Pin 사용 완료 처리
            DispatchQueue.main.async {
                self.currentPin = nil
                self.isWaitingForAuth = false
            }
            pinExpirationTimer?.invalidate()
            
            return createAuthResponseMessage(success: true, sessionToken: sessionToken)
        } else {
            return createAuthResponseMessage(success: false, error: "Invalid PIN")
        }
    }
    
    /**
     * 재연결 요청 처리
     */
    func processReconnectRequest(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let messageDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              messageDict["type"] as? String == "reconnect_request",
              let reconnectData = messageDict["data"] as? [String: Any] else {
            print("❌ 재연결 요청 파싱 실패")
            return nil
        }
        
        guard let sessionToken = reconnectData["sessionToken"] as? String,
              let deviceId = reconnectData["deviceId"] as? String else {
            print("❌ 재연결 요청 데이터 누락")
            return createAuthResponseMessage(success: false, error: "Invalid reconnect data")
        }
        
        // 세션 토큰 검증
        if validateSessionToken(sessionToken, deviceId: deviceId) {
            return createAuthResponseMessage(success: true, sessionToken: sessionToken)
        } else {
            return createAuthResponseMessage(success: false, error: "Invalid or expired session")
        }
    }
    
    /**
     * 인증 응답 메시지 생성
     */
    private func createAuthResponseMessage(success: Bool, sessionToken: String? = nil, error: String? = nil) -> String {
        let authResponse = AuthResponse(success: success, sessionToken: sessionToken, error: error)
        
        let message: [String: Any] = [
            "type": "auth_response",
            "data": [
                "success": authResponse.success,
                "sessionToken": authResponse.sessionToken ?? NSNull(),
                "error": authResponse.error ?? NSNull(),
                "timestamp": authResponse.timestamp
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ 인증 응답 JSON 생성 실패")
            return "{\"type\":\"auth_response\",\"data\":{\"success\":false,\"error\":\"JSON serialization failed\"}}"
        }
        
        return jsonString
    }
    
    // MARK: - Cleanup
    
    /**
     * 만료된 세션 정리
     */
    func cleanupExpiredSessions() {
        let now = Date()
        let expiredTokens = activeSessions.compactMap { (token, session) in
            now > session.expiresAt ? token : nil
        }
        
        for token in expiredTokens {
            removeSession(token)
        }
        
        if !expiredTokens.isEmpty {
            print("🧹 만료된 세션 \(expiredTokens.count)개 정리됨")
        }
    }
    
    // MARK: - Clipboard Hub Functions
    
    /**
     * 새 클립보드 항목을 허브에 추가
     */
    func addClipboardEntry(content: String, from sourceDevice: String) {
        // 중복 방지 - 마지막 항목과 동일하면 무시
        if let lastEntry = clipboardHistory.first, lastEntry.content == content {
            return
        }
        
        let entry = ClipboardHubEntry(content: content, sourceDevice: sourceDevice)
        
        DispatchQueue.main.async {
            self.clipboardHistory.insert(entry, at: 0)
            
            // 최대 100개 항목만 유지
            if self.clipboardHistory.count > 100 {
                self.clipboardHistory = Array(self.clipboardHistory.prefix(100))
            }
        }
        
        print("📋 클립보드 허브에 새 항목 추가: \(sourceDevice) -> \(content.prefix(30))...")
    }
    
    /**
     * 연결된 모든 디바이스에 클립보드 동기화
     */
    func broadcastClipboard(content: String, from sourceDevice: String, completion: @escaping (Set<String>) -> Void) {
        let targetDevices = connectedDevices.filter { $0 != sourceDevice }
        
        if targetDevices.isEmpty {
            completion([])
            return
        }
        
        // 클립보드 허브에 추가
        addClipboardEntry(content: content, from: sourceDevice)
        
        // 모든 연결된 디바이스에 브로드캐스트할 준비
        let syncedDevices: Set<String> = [sourceDevice]
        
        print("📡 클립보드 브로드캐스트 준비: \(sourceDevice) -> \(targetDevices.joined(separator: ", "))")
        print("📝 내용: \(content.prefix(50))...")
        
        completion(syncedDevices)
    }
    
    /**
     * 디바이스별 마지막 클립보드 상태 추적
     */
    func updateDeviceClipboard(_ content: String, for deviceId: String) {
        deviceClipboardStates[deviceId] = content
    }
    
    /**
     * 특정 디바이스의 클립보드 상태가 변경되었는지 확인
     */
    func hasClipboardChanged(_ content: String, for deviceId: String) -> Bool {
        return deviceClipboardStates[deviceId] != content
    }
    
    /**
     * 연결된 디바이스 목록 반환 (자신 제외)
     */
    func getOtherConnectedDevices(excluding deviceId: String) -> Set<String> {
        return connectedDevices.filter { $0 != deviceId }
    }
    
    /**
     * 활성 세션 토큰 반환 (암호화용)
     */
    func getActiveSessionToken() -> String? {
        return activeSessions.first?.value.token
    }
    
    /**
     * 활성 세션 정보 반환 (복호화용)
     */
    func getActiveSession() -> SessionInfo? {
        return activeSessions.first?.value
    }
    
    deinit {
        pinExpirationTimer?.invalidate()
    }
}