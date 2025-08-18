import Foundation
import UserNotifications

class NotificationManager: NSObject {
    static let shared = NotificationManager()
    
    private let settings = AppSettings.shared
    
    private override init() {
        super.init()
    }
    
    // MARK: - 권한 요청
    
    func requestNotificationPermission() {
        print("🔔 알림 시스템 초기화 (osascript 모드)")
        // Swift Package Manager에서는 UserNotifications가 Bundle ID 없이 작동하지 않음
        // 대신 osascript 사용
    }
    
    // MARK: - 알림 전송
    
    func sendLocalCopyNotification(content: String) {
        guard settings.isNotificationsEnabled && settings.isLocalCopyNotificationEnabled else { return }
        
        let preview = content.prefix(50)
        let title = "Clipboard Copied"
        let body = preview.isEmpty ? "Empty content copied" : String(preview)
        
        sendNotification(
            identifier: "local-copy-\(Date().timeIntervalSince1970)",
            title: title,
            body: body,
            sound: .default
        )
    }
    
    func sendRemoteReceiveNotification(content: String, fromDevice: String) {
        guard settings.isNotificationsEnabled && settings.isRemoteReceiveNotificationEnabled else { return }
        
        let preview = content.prefix(50)
        let title = "Received from Android"
        let body = preview.isEmpty ? "Empty content received" : String(preview)
        
        sendNotification(
            identifier: "remote-receive-\(Date().timeIntervalSince1970)",
            title: title,
            body: body,
            sound: .default
        )
    }
    
    func sendAirdropReceiveNotification(content: String) {
        guard settings.isNotificationsEnabled && settings.isAirdropReceiveNotificationEnabled else { return }
        
        let preview = content.prefix(50)
        let title = "Received from AirDrop"
        let body = preview.isEmpty ? "Empty content received" : String(preview)
        
        sendNotification(
            identifier: "airdrop-receive-\(Date().timeIntervalSince1970)",
            title: title,
            body: body,
            sound: .default
        )
    }
    
    // MARK: - Private 메서드
    
    private func sendNotification(identifier: String, title: String, body: String, sound: UNNotificationSound?) {
        // 콘솔 로그 표시
        print("🔔 알림: [\(title)] \(body)")
        
        // 가장 간단하고 안전한 방법
        let safeTitle = "CopyDrop Notification"
        let safeBody = "Content copied to clipboard"
        
        let script = "display notification \"\(safeBody)\" with title \"\(safeTitle)\""
        
        DispatchQueue.global(qos: .background).async {
            let process = Process()
            process.launchPath = "/usr/bin/osascript"
            process.arguments = ["-e", script]
            
            do {
                try process.run()
                process.waitUntilExit()
                DispatchQueue.main.async {
                    print("✅ 시스템 알림 전송 완료")
                }
            } catch {
                DispatchQueue.main.async {
                    print("❌ 시스템 알림 실패: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - osascript 기반 알림 시스템
// Swift Package Manager 환경에서는 UserNotifications 대신 osascript 사용