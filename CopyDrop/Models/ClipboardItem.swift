//
//  ClipboardItem.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import Foundation
import SwiftData

@Model
final class ClipboardItem {
    var id: UUID
    var content: String
    var timestamp: Date
    var source: String
    var hash: String
    var isLocal: Bool
    
    init(content: String, source: String = "local", isLocal: Bool = true) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.source = source
        self.hash = ClipboardItem.sha256(content)
        self.isLocal = isLocal
    }
    
    static func sha256(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        
        var hash = [UInt8](repeating: 0, count: Int(32))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        
        return "sha256:" + hash.map { String(format: "%02x", $0) }.joined()
    }
}

// POC 호환 메시지 구조체
struct CopyDropMessage: Codable {
    let t: Int64           // 타임스탬프 (milliseconds)
    let from: String       // 디바이스 식별자 
    let type: String       // 메시지 타입 ("text")
    let payload: String    // 클립보드 내용
    let hash: String       // SHA-256 해시
    
    init(content: String, deviceId: String) {
        self.t = Int64(Date().timeIntervalSince1970 * 1000)
        self.from = deviceId
        self.type = "text"
        self.payload = content
        self.hash = ClipboardItem.sha256(content)
    }
}

// CommonCrypto를 위한 import (macOS)
import CommonCrypto
