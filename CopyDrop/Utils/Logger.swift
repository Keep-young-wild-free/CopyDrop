//
//  Logger.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import Foundation
import os.log

/// 로그 레벨 정의
enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO" 
    case warning = "WARNING"
    case error = "ERROR"
    case security = "SECURITY"
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .security: return .fault
        }
    }
}

/// 통합 로깅 시스템
class Logger {
    static let shared = Logger()
    
    private let dateFormatter: DateFormatter
    private let fileLogger: FileLogger
    private let osLogger = os.Logger(subsystem: "com.copydrop.app", category: "general")
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        fileLogger = FileLogger()
    }
    
    func log(_ message: String, level: LogLevel = .info, category: String = "general") {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(category)] \(message)"
        
        // Console output
        print(logMessage)
        
        // OS unified logging
        switch level {
        case .debug:
            osLogger.debug("\(message, privacy: .public)")
        case .info:
            osLogger.info("\(message, privacy: .public)")
        case .warning:
            osLogger.warning("\(message, privacy: .public)")
        case .error:
            osLogger.error("\(message, privacy: .public)")
        }
        
        // File logging for errors
        if level == .error {
            fileLogger.write(logMessage)
        }
    }
    
    func logNetwork(_ message: String, level: LogLevel = .info) {
        log(message, level: level, category: "network")
    }
    
    func logSecurity(_ message: String, level: LogLevel = .info) {
        log(message, level: level, category: "security")
    }
    
    func logClipboard(_ message: String, level: LogLevel = .info) {
        log(message, level: level, category: "clipboard")
    }
}



/// 파일 로깅 구현
private class FileLogger {
    private let logFileURL: URL
    private let maxFileSize: Int = 5 * 1024 * 1024 // 5MB
    private let queue = DispatchQueue(label: "file-logger", qos: .utility)
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = documentsPath.appendingPathComponent("CopyDrop.log")
    }
    
    func write(_ message: String) {
        queue.async { [weak self] in
            self?.writeToFile(message)
        }
    }
    
    private func writeToFile(_ message: String) {
        let data = (message + "\n").data(using: .utf8)!
        
        do {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                // 파일 크기 확인 및 로테이션
                let attributes = try FileManager.default.attributesOfItem(atPath: logFileURL.path)
                let fileSize = attributes[.size] as? Int ?? 0
                
                if fileSize > maxFileSize {
                    rotateLogFile()
                }
                
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
    
    private func rotateLogFile() {
        let backupURL = logFileURL.appendingPathExtension("old")
        
        do {
            // 기존 백업 파일 삭제
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try FileManager.default.removeItem(at: backupURL)
            }
            
            // 현재 로그 파일을 백업으로 이동
            try FileManager.default.moveItem(at: logFileURL, to: backupURL)
        } catch {
            print("로그 파일 로테이션 실패: \(error)")
        }
    }
}
