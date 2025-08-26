import Foundation
import os.log

/**
 * Mac용 구조화된 로깅 시스템
 */
class Logger {
    static let shared = Logger()
    
    /**
     * 로그 카테고리
     */
    enum Category: String, CaseIterable {
        case bluetooth = "BLE"
        case crypto = "CRYPTO"
        case clipboard = "CLIPBOARD"
        case ui = "UI"
        case network = "NETWORK"
        case auth = "AUTH"
        case performance = "PERF"
        case lifecycle = "LIFECYCLE"
        
        var osLog: OSLog {
            return OSLog(subsystem: "com.copydrop.mac", category: self.rawValue)
        }
    }
    
    /**
     * 로그 레벨
     */
    enum Level {
        case debug
        case info
        case warning
        case error
        case fault
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .error  // warning은 error로 매핑
            case .error: return .error
            case .fault: return .fault
            }
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    private init() {}
    
    /**
     * 구조화된 로그 출력
     */
    func log(
        level: Level,
        category: Category,
        message: String,
        metadata: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let threadName = Thread.current.name ?? "main"
        
        // 메타데이터 문자열 생성
        let metadataStr = metadata.isEmpty ? "" : 
            metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        
        // 로그 메시지 포맷팅
        var formattedMessage = "[\(timestamp)] [\(level)] [\(category.rawValue)] [\(threadName)] \(message)"
        
        if !metadataStr.isEmpty {
            formattedMessage += " | \(metadataStr)"
        }
        
        // 개발 모드에서는 파일/함수/라인 정보 추가
        #if DEBUG
        formattedMessage += " (\(fileName):\(line) \(function))"
        #endif
        
        // OSLog 출력
        os_log("%{public}@", log: category.osLog, type: level.osLogType, formattedMessage)
        
        // 콘솔에도 출력 (Swift Package 개발 시 유용)
        print(formattedMessage)
    }
    
    // 편의 메서드들
    func debug(_ category: Category, _ message: String, metadata: [String: Any] = [:]) {
        log(level: .debug, category: category, message: message, metadata: metadata)
    }
    
    func info(_ category: Category, _ message: String, metadata: [String: Any] = [:]) {
        log(level: .info, category: category, message: message, metadata: metadata)
    }
    
    func warning(_ category: Category, _ message: String, metadata: [String: Any] = [:]) {
        log(level: .warning, category: category, message: message, metadata: metadata)
    }
    
    func error(_ category: Category, _ message: String, metadata: [String: Any] = [:]) {
        log(level: .error, category: category, message: message, metadata: metadata)
    }
    
    func fault(_ category: Category, _ message: String, metadata: [String: Any] = [:]) {
        log(level: .fault, category: category, message: message, metadata: metadata)
    }
    
    // 특화된 로깅 메서드들
    
    /**
     * 블루투스 연결 상태 로깅
     */
    func logBluetoothConnection(deviceId: String, isConnected: Bool, connectionType: String = "BLE") {
        let metadata: [String: Any] = [
            "device_id": deviceId,
            "connected": isConnected,
            "connection_type": connectionType
        ]
        
        let message = isConnected ? 
            "블루투스 연결 성공: \(deviceId)" : 
            "블루투스 연결 해제: \(deviceId)"
        
        info(.bluetooth, message, metadata: metadata)
    }
    
    /**
     * 데이터 전송 로깅
     */
    func logDataTransfer(direction: String, size: Int, type: String, encrypted: Bool = false) {
        let metadata: [String: Any] = [
            "direction": direction,
            "size_bytes": size,
            "size_kb": size / 1024,
            "type": type,
            "encrypted": encrypted,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        let encryptedText = encrypted ? " (암호화됨)" : ""
        let message = "\(direction) 데이터 전송: \(size / 1024)KB \(type)\(encryptedText)"
        
        info(.network, message, metadata: metadata)
    }
    
    /**
     * PIN 인증 로깅
     */
    func logPinAuthentication(success: Bool, pin: String? = nil, deviceId: String? = nil) {
        let metadata: [String: Any] = [
            "success": success,
            "pin_length": pin?.count ?? 0,
            "device_id": deviceId ?? "unknown",
            "session_created": success
        ]
        
        let message = success ? 
            "PIN 인증 성공" : 
            "PIN 인증 실패"
        
        if success {
            info(.auth, message, metadata: metadata)
        } else {
            warning(.auth, message, metadata: metadata)
        }
    }
    
    /**
     * 성능 측정 로깅
     */
    func logPerformance(operation: String, duration: TimeInterval, success: Bool = true) {
        let metadata: [String: Any] = [
            "operation": operation,
            "duration_ms": Int(duration * 1000),
            "duration_s": duration,
            "success": success
        ]
        
        let message = "\(operation) 완료: \(String(format: "%.2f", duration * 1000))ms"
        
        switch true {
        case !success:
            warning(.performance, "\(message) (실패)", metadata: metadata)
        case duration > 5.0:
            warning(.performance, "\(message) (느림)", metadata: metadata)
        default:
            debug(.performance, message, metadata: metadata)
        }
    }
    
    /**
     * UI 이벤트 로깅
     */
    func logUserAction(action: String, component: String, metadata: [String: Any] = [:]) {
        let enrichedMetadata = metadata.merging([
            "component": component,
            "action": action,
            "user_timestamp": Date().timeIntervalSince1970
        ]) { current, _ in current }
        
        debug(.ui, "사용자 액션: \(action) (컴포넌트: \(component))", metadata: enrichedMetadata)
    }
    
    /**
     * 클립보드 이벤트 로깅
     */
    func logClipboardEvent(event: String, contentType: String, size: Int, source: String = "local") {
        let metadata: [String: Any] = [
            "event": event,
            "content_type": contentType,
            "size_bytes": size,
            "size_kb": size / 1024,
            "source": source
        ]
        
        info(.clipboard, "클립보드 \(event): \(contentType) (\(size / 1024)KB)", metadata: metadata)
    }
    
    /**
     * 암호화 작업 로깅
     */
    func logCryptoOperation(operation: String, success: Bool, dataSize: Int, algorithm: String = "AES-256") {
        let metadata: [String: Any] = [
            "operation": operation,
            "success": success,
            "data_size": dataSize,
            "algorithm": algorithm
        ]
        
        let message = "\(operation) \(success ? "성공" : "실패"): \(dataSize) bytes (\(algorithm))"
        
        if success {
            debug(.crypto, message, metadata: metadata)
        } else {
            error(.crypto, message, metadata: metadata)
        }
    }
    
    /**
     * 앱 생명주기 로깅
     */
    func logLifecycle(component: String, event: String, metadata: [String: Any] = [:]) {
        let enrichedMetadata = metadata.merging([
            "component": component,
            "lifecycle_event": event
        ]) { current, _ in current }
        
        info(.lifecycle, "\(component): \(event)", metadata: enrichedMetadata)
    }
    
    /**
     * 에러와 함께 로깅
     */
    func logError(_ category: Category, _ message: String, error: Error, context: [String: Any] = [:]) {
        let errorMetadata = context.merging([
            "error_type": String(describing: type(of: error)),
            "error_description": error.localizedDescription,
            "error_code": (error as NSError).code
        ]) { current, _ in current }
        
        self.error(category, message, metadata: errorMetadata)
    }
}

/**
 * 성능 측정을 위한 유틸리티
 */
extension Logger {
    func measurePerformance<T>(operation: String, _ block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            let result = try block()
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logPerformance(operation: operation, duration: duration, success: true)
            return result
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logPerformance(operation: operation, duration: duration, success: false)
            throw error
        }
    }
}