//
//  ErrorHandler.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Error Types
enum CopyDropError: LocalizedError {
    case networkConnectionFailed(String)
    case encryptionFailed
    case decryptionFailed
    case invalidKey
    case keychainError(String)
    case serverStartFailed(String)
    case clipboardAccessDenied
    case contentFiltered(String)
    case rateLimitExceeded
    case invalidMessage
    case deviceNotTrusted
    
    var errorDescription: String? {
        switch self {
        case .networkConnectionFailed(let details):
            return "네트워크 연결 실패: \(details)"
        case .encryptionFailed:
            return "데이터 암호화에 실패했습니다"
        case .decryptionFailed:
            return "데이터 복호화에 실패했습니다"
        case .invalidKey:
            return "잘못된 암호화 키입니다"
        case .keychainError(let details):
            return "키체인 오류: \(details)"
        case .serverStartFailed(let details):
            return "서버 시작 실패: \(details)"
        case .clipboardAccessDenied:
            return "클립보드 접근 권한이 없습니다"
        case .contentFiltered(let reason):
            return "내용이 필터링되었습니다: \(reason)"
        case .rateLimitExceeded:
            return "너무 빠른 동기화 요청입니다"
        case .invalidMessage:
            return "잘못된 메시지 형식입니다"
        case .deviceNotTrusted:
            return "신뢰할 수 없는 디바이스입니다"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkConnectionFailed:
            return "네트워크 연결을 확인하고 다시 시도하세요"
        case .encryptionFailed, .decryptionFailed:
            return "암호화 키를 확인하고 다시 시도하세요"
        case .invalidKey:
            return "설정에서 새로운 키를 생성하거나 가져오세요"
        case .keychainError:
            return "시스템 키체인 설정을 확인하세요"
        case .serverStartFailed:
            return "포트가 사용 중이지 않은지 확인하고 다시 시도하세요"
        case .clipboardAccessDenied:
            return "시스템 설정에서 클립보드 접근 권한을 허용하세요"
        case .contentFiltered:
            return "동기화할 내용을 검토하세요"
        case .rateLimitExceeded:
            return "잠시 후 다시 시도하세요"
        case .invalidMessage:
            return "메시지 형식을 확인하세요"
        case .deviceNotTrusted:
            return "디바이스를 다시 인증하세요"
        }
    }
}

// MARK: - Error Handler
@MainActor
@Observable
class ErrorHandler {
    var currentError: CopyDropError?
    var showingError = false
    var errorHistory: [ErrorLogEntry] = []
    
    func handle(_ error: CopyDropError) {
        Logger.shared.log("오류 발생: \(error.localizedDescription)", level: .error)
        
        currentError = error
        showingError = true
        
        // 에러 히스토리에 추가
        let entry = ErrorLogEntry(
            error: error,
            timestamp: Date(),
            context: getCurrentContext()
        )
        errorHistory.append(entry)
        
        // 히스토리 크기 제한 (최대 100개)
        if errorHistory.count > AppConstants.Storage.maxErrorLogEntries {
            errorHistory.removeFirst(errorHistory.count - AppConstants.Storage.maxErrorLogEntries)
        }
        
        // 자동 복구 시도
        attemptAutoRecovery(for: error)
    }
    
    func clearError() {
        currentError = nil
        showingError = false
    }
    
    private func getCurrentContext() -> String {
        // 현재 앱 상태나 작업 컨텍스트를 반환
        return "일반 작업"
    }
    
    private func attemptAutoRecovery(for error: CopyDropError) {
        switch error {
        case .networkConnectionFailed:
            // 3초 후 자동 재연결 시도
            Task {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                // 재연결 로직 실행
                NotificationCenter.default.post(name: .attemptReconnection, object: nil)
            }
            
        case .rateLimitExceeded:
            // 에러 자동 숨김 (1초 후)
            Task {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                clearError()
            }
            
        default:
            break
        }
    }
    
    func exportErrorLog() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        
        var log = "CopyDrop 오류 로그\n"
        log += "생성일: \(dateFormatter.string(from: Date()))\n\n"
        
        for entry in errorHistory.suffix(50) { // 최근 50개만
            log += "[\(dateFormatter.string(from: entry.timestamp))] "
            log += "\(entry.error.localizedDescription)\n"
            if let suggestion = entry.error.recoverySuggestion {
                log += "  해결방법: \(suggestion)\n"
            }
            log += "  컨텍스트: \(entry.context)\n\n"
        }
        
        return log
    }
}

// MARK: - Error Log Entry
struct ErrorLogEntry: Identifiable {
    let id = UUID()
    let error: CopyDropError
    let timestamp: Date
    let context: String
}

// MARK: - Notification Names
extension Notification.Name {
    static let attemptReconnection = Notification.Name("attemptReconnection")
}

// MARK: - Error Alert View
struct ErrorAlertView: View {
    @Binding var isPresented: Bool
    let error: CopyDropError?
    let onRetry: (() -> Void)?
    
    var body: some View {
        if let error = error {
            Alert(
                title: Text("오류"),
                message: Text(error.localizedDescription + "\n\n" + (error.recoverySuggestion ?? "")),
                primaryButton: onRetry != nil ? .default(Text("다시 시도"), action: {
                    onRetry?()
                    isPresented = false
                }) : .default(Text("확인"), action: {
                    isPresented = false
                }),
                secondaryButton: .cancel(Text("취소"), action: {
                    isPresented = false
                })
            )
        } else {
            EmptyView()
        }
    }
}

// MARK: - Logger
class Logger {
    static let shared = Logger()
    private let dateFormatter: DateFormatter
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    func log(_ message: String, level: LogLevel = .info) {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] [\(level.rawValue)] \(message)"
        
        print(logMessage)
        
        // 필요시 파일에 로그 저장
        if level == .error {
            saveToFile(logMessage)
        }
    }
    
    private func saveToFile(_ message: String) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let logFileURL = documentsPath.appendingPathComponent("CopyDrop.log")
        
        do {
            let data = (message + "\n").data(using: .utf8)!
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try data.write(to: logFileURL)
            }
        } catch {
            print("로그 파일 저장 실패: \(error)")
        }
    }
}

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}
