import Foundation
import CryptoKit

/**
 * BLE 통신용 AES 암호화 관리자 (Mac용)
 */
class CryptoManager {
    static let shared = CryptoManager()
    
    private init() {}
    
    /**
     * 데이터 암호화
     */
    func encrypt(_ data: String, sessionToken: String) -> String? {
        guard let dataBytes = data.data(using: .utf8) else {
            print("❌ 데이터 UTF-8 변환 실패")
            return nil
        }
        
        do {
            // 세션 토큰으로부터 AES 키 파생
            let key = deriveKey(from: sessionToken)
            
            // AES-GCM 암호화 (인증 포함)
            let sealedBox = try AES.GCM.seal(dataBytes, using: key)
            
            // 암호화된 데이터를 Base64로 인코딩
            guard let encryptedData = sealedBox.combined else {
                print("❌ 암호화 데이터 결합 실패")
                return nil
            }
            
            let base64Encrypted = encryptedData.base64EncodedString()
            print("🔐 Mac에서 데이터 암호화 성공: \(data.prefix(30))... -> \(encryptedData.count) bytes")
            
            return base64Encrypted
        } catch {
            print("❌ Mac 암호화 실패: \(error)")
            return nil
        }
    }
    
    /**
     * 데이터 복호화
     */
    func decrypt(_ encryptedBase64: String, sessionToken: String) -> String? {
        guard let encryptedData = Data(base64Encoded: encryptedBase64) else {
            print("❌ Base64 디코딩 실패")
            return nil
        }
        
        do {
            // 세션 토큰으로부터 AES 키 파생
            let key = deriveKey(from: sessionToken)
            
            // AES-GCM 복호화
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            
            let decryptedString = String(data: decryptedData, encoding: .utf8)
            print("🔓 Mac에서 데이터 복호화 성공: \(encryptedData.count) bytes -> \(decryptedString?.prefix(30) ?? "nil")...")
            
            return decryptedString
        } catch {
            print("❌ Mac 복호화 실패: \(error)")
            
            // Android CBC 방식과 호환성을 위한 대체 시도
            return tryAndroidCompatibleDecrypt(encryptedBase64, sessionToken: sessionToken)
        }
    }
    
    /**
     * Android AES-CBC 호환 복호화 시도
     */
    private func tryAndroidCompatibleDecrypt(_ encryptedBase64: String, sessionToken: String) -> String? {
        print("🔄 Android 호환성 복호화 시도 중...")
        
        guard let _ = Data(base64Encoded: encryptedBase64) else {
            return nil
        }
        
        // Android에서는 CBC + PKCS5Padding을 사용하므로 CommonCrypto 사용 필요
        // 현재는 macOS CryptoKit으로 제한되어 있으므로 원본 반환
        print("⚠️ Android CBC 호환성은 추후 구현 예정")
        return nil
    }
    
    /**
     * 세션 토큰으로부터 AES 키 파생
     */
    private func deriveKey(from sessionToken: String) -> SymmetricKey {
        let tokenData = Data(sessionToken.utf8)
        let hashedToken = SHA256.hash(data: tokenData)
        return SymmetricKey(data: hashedToken)
    }
    
    /**
     * 암호화 여부 확인
     */
    func isEncrypted(_ data: String) -> Bool {
        // Base64 형식인지 확인 (간단한 휴리스틱)
        let base64Pattern = "^[A-Za-z0-9+/]*={0,2}$"
        let regex = try? NSRegularExpression(pattern: base64Pattern)
        let range = NSRange(location: 0, length: data.count)
        
        return regex?.firstMatch(in: data, range: range) != nil && data.count > 50
    }
}