//
//  ClipboardSyncService+Testing.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import Foundation
import CryptoKit

#if DEBUG
extension ClipboardSyncService {
    // 테스트용 public 메서드들
    
    func testEncryptData(_ data: Data) -> Data? {
        return encryptData(data)
    }
    
    func testDecryptData(_ data: Data) -> Data? {
        return decryptData(data)
    }
    
    func testFilterContent(_ content: String) -> (allowed: Bool, reason: String?) {
        return SecurityManager.shared.filterClipboardContent(content)
    }
    
    func testGenerateMessage(content: String, hash: String) -> [String: Any] {
        return [
            "t": Int(Date().timeIntervalSince1970 * 1000),
            "from": "test-device",
            "type": "text",
            "payload": content,
            "hash": hash
        ]
    }
}
#endif
