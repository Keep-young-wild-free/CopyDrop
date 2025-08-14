//
//  AppConstants.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import Foundation

struct AppConstants {
    
    // MARK: - Network
    struct Network {
        static let defaultPort: UInt16 = 8787
        static let defaultServerURL = "ws://localhost:8787/ws"
        static let reconnectDelay: TimeInterval = 2.0
        static let pingInterval: TimeInterval = 30.0
        static let connectionTimeout: TimeInterval = 10.0
    }
    
    // MARK: - Clipboard
    struct Clipboard {
        static let monitorInterval: TimeInterval = 0.5
        static let maxContentSize = 10 * 1024 // 10KB
        static let minSyncInterval: TimeInterval = 0.1 // 100ms
    }
    
    // MARK: - Security
    struct Security {
        static let encryptionKeySize = 32 // bytes
        static let ivSize = 12 // bytes for AES-GCM
        static let tagSize = 16 // bytes for AES-GCM
        static let keychainService = "com.copydrop.encryption"
        static let keychainAccount = "encryption-key"
        static let authTokenValidityMinutes = 5
    }
    
    // MARK: - UI
    struct UI {
        static let settingsWindowWidth: CGFloat = 500
        static let settingsWindowHeight: CGFloat = 600
        static let qrCodeWindowWidth: CGFloat = 350
        static let qrCodeWindowHeight: CGFloat = 400
        static let navigationColumnWidth: CGFloat = 200
        static let statusIndicatorSize: CGFloat = 12
    }
    
    // MARK: - Storage
    struct Storage {
        static let deviceIdKey = "CopyDropDeviceId"
        static let maxErrorLogEntries = 100
        static let maxClipboardHistoryAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    }
    
    // MARK: - Sensitive Patterns
    struct SensitivePatterns {
        static let passwordKeywords = [
            "password:", "pass:", "pwd:", "token:", "key:", "secret:",
            "api_key:", "비밀번호:", "암호:", "패스워드:"
        ]
        
        static let creditCardPattern = "\\b(?:\\d{4}[\\s-]?){3}\\d{4}\\b"
        static let ssnPattern = "\\b\\d{3}-\\d{2}-\\d{4}\\b"
        static let emailPattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
    }
    
    // MARK: - Message Types
    struct MessageTypes {
        static let text = "text"
        static let image = "image"
        static let file = "file"
        static let ping = "ping"
        static let pong = "pong"
        static let auth = "auth"
    }
    
    // MARK: - Error Messages
    struct ErrorMessages {
        static let networkUnavailable = "네트워크에 연결할 수 없습니다"
        static let invalidURL = "잘못된 URL 형식입니다"
        static let encryptionFailed = "데이터 암호화에 실패했습니다"
        static let decryptionFailed = "데이터 복호화에 실패했습니다"
        static let keychainError = "키체인 접근 중 오류가 발생했습니다"
        static let contentTooLarge = "내용이 너무 큽니다 (최대 10KB)"
        static let contentFiltered = "민감한 정보가 포함되어 있을 수 있습니다"
    }
}
