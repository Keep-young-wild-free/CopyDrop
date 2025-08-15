//
//  SecurityManager.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import Foundation
import Security
import CryptoKit

class SecurityManager {
    static let shared = SecurityManager()
    
    private let serviceName = AppConstants.Security.keychainService
    private let accountName = AppConstants.Security.keychainAccount
    private var lastClipboardUpdateTimes: [String: Date] = [:] // [deviceId: lastUpdateTime]
    
    private init() {}
    
    // MARK: - Key Management
    
    /// 새로운 암호화 키를 생성하고 키체인에 저장
    func generateAndStoreEncryptionKey() -> SymmetricKey? {
        let keyData = SymmetricKey(size: .bits256)
        let data = keyData.withUnsafeBytes { Data($0) }
        
        Logger.shared.logSecurity("새 암호화 키 생성 시도")
        
        if storeKeyInKeychain(data) {
            return keyData
        }
        return nil
    }
    
    /// 키체인에서 암호화 키를 가져오기
    func getEncryptionKey() -> SymmetricKey? {
        guard let keyData = getKeyFromKeychain() else {
            return nil
        }
        return SymmetricKey(data: keyData)
    }
    
    /// 키체인에서 암호화 키 삭제
    func deleteEncryptionKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    /// QR 코드용 키 내보내기 (Base64 형태)
    func exportKeyForQRCode() -> String? {
        guard let keyData = getKeyFromKeychain() else {
            return nil
        }
        return keyData.base64EncodedString()
    }
    
    /// QR 코드에서 키 가져오기
    func importKeyFromQRCode(_ base64Key: String) -> Bool {
        guard let keyData = Data(base64Encoded: base64Key),
              keyData.count == 32 else {
            return false
        }
        
        // 기존 키 삭제
        _ = deleteEncryptionKey()
        
        // 새 키 저장
        return storeKeyInKeychain(keyData)
    }
    
    // MARK: - Keychain Operations
    
    private func storeKeyInKeychain(_ keyData: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // 기존 항목 삭제
        SecItemDelete(query as CFDictionary)
        
        // 새 항목 추가
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func getKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }
    
    // MARK: - Device Authentication
    
    /// 새 디바이스 연결을 위한 인증 토큰 생성
    func generateAuthToken() -> String {
        let tokenData = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        return tokenData.base64EncodedString()
    }
    
    /// 연결 요청 검증
    func validateConnectionRequest(_ request: [String: Any]) -> Bool {
        guard let deviceId = request["deviceId"] as? String,
              let timestamp = request["timestamp"] as? Int64,
              let signature = request["signature"] as? String else {
            return false
        }
        
        // 타임스탬프 검증 (5분 이내)
        let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
        if abs(currentTime - timestamp) > 300000 { // 5분
            return false
        }
        
        // 디바이스 ID 검증 (간단한 형태)
        if deviceId.isEmpty || deviceId.count < 8 {
            return false
        }
        
        return true
    }
    
    // MARK: - Content Filtering
    
    /// 클립보드 내용 필터링 (민감한 정보 차단)
    func filterClipboardContent(_ content: String) -> (allowed: Bool, reason: String?) {
        // 빈 내용 차단
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (false, "빈 내용")
        }
        
        // 너무 긴 내용 차단
        if content.count > AppConstants.Clipboard.maxContentSize {
            return (false, AppConstants.ErrorMessages.contentTooLarge)
        }
        
        // 패스워드 패턴 검사
        let passwordPatterns = AppConstants.SensitivePatterns.passwordKeywords
        
        let lowercaseContent = content.lowercased()
        for pattern in passwordPatterns {
            if lowercaseContent.contains(pattern) {
                return (false, "민감한 정보가 포함되어 있을 수 있습니다")
            }
        }
        
        // 신용카드 번호 패턴 검사
        if content.range(of: AppConstants.SensitivePatterns.creditCardPattern, options: .regularExpression) != nil {
            return (false, "신용카드 번호가 포함되어 있을 수 있습니다")
        }
        
        return (true, nil)
    }
    
    // MARK: - Encryption (POC Compatible AES-256-GCM)
    
    /// POC와 동일한 AES-256-GCM 암호화
    /// 반환 데이터: IV(12바이트) + 암호문 + 태그(16바이트)
    func encrypt(data: Data) -> Data? {
        guard let key = getEncryptionKey() else {
            Logger.shared.logSecurity("암호화 키를 찾을 수 없습니다")
            return nil
        }
        
        // 12바이트 IV 생성
        let iv = Data((0..<12).map { _ in UInt8.random(in: 0...255) })
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key, nonce: AES.GCM.Nonce(data: iv))
            // POC 형식: IV + 암호문 + 태그
            return iv + sealedBox.ciphertext + sealedBox.tag
        } catch {
            Logger.shared.logSecurity("암호화 실패: \(error)")
            return nil
        }
    }
    
    /// POC와 동일한 AES-256-GCM 복호화
    func decrypt(data: Data) -> Data? {
        guard data.count >= 12 + 16 else {
            Logger.shared.logSecurity("데이터가 너무 짧습니다")
            return nil
        }
        
        guard let key = getEncryptionKey() else {
            Logger.shared.logSecurity("복호화 키를 찾을 수 없습니다")
            return nil
        }
        
        // POC 형식 파싱: IV(12) + 암호문 + 태그(16)
        let iv = data.prefix(12)
        let ciphertext = data.dropFirst(12).dropLast(16)
        let tag = data.suffix(16)
        
        do {
            let sealedBox = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: iv),
                ciphertext: ciphertext,
                tag: tag
            )
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            Logger.shared.logSecurity("복호화 실패: \(error)")
            return nil
        }
    }
    
    // MARK: - Rate Limiting
    
    private var lastSyncTimes: [String: Date] = [:]
    private let minSyncInterval: TimeInterval = 0.1 // 100ms
    
    /// 동기화 속도 제한 검사
    func checkRateLimit(for deviceId: String) -> Bool {
        let now = Date()
        
        if let lastTime = lastSyncTimes[deviceId] {
            if now.timeIntervalSince(lastTime) < minSyncInterval {
                return false
            }
        }
        
        lastSyncTimes[deviceId] = now
        
        // 오래된 엔트리 정리 (1시간 이상 된 것)
        lastSyncTimes = lastSyncTimes.filter { now.timeIntervalSince($0.value) < 3600 }
        
        return true
    }
}

// MARK: - DeviceInfo Helper
struct DeviceInfo {
    let id: String
    let name: String
    let type: String
    
    static func current() -> DeviceInfo {
        let id = getDeviceId()
        let name = Host.current().localizedName ?? "Unknown"
        let type = "macOS"
        
        return DeviceInfo(id: id, name: name, type: type)
    }
    
    private static func getDeviceId() -> String {
        // macOS에서 고유한 디바이스 ID 생성
        if let uuid = getStoredDeviceId() {
            return uuid
        }
        
        let newUUID = UUID().uuidString
        storeDeviceId(newUUID)
        return newUUID
    }
    
    private static func getStoredDeviceId() -> String? {
        return UserDefaults.standard.string(forKey: "CopyDropDeviceId")
    }
    
    private static func storeDeviceId(_ id: String) {
        UserDefaults.standard.set(id, forKey: "CopyDropDeviceId")
    }
}
