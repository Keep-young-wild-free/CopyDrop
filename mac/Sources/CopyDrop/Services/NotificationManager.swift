import Foundation
import UserNotifications
import AppKit

class NotificationManager: NSObject {
    static let shared = NotificationManager()
    
    private let settings = AppSettings.shared
    // Swift Package 환경에서는 UserNotifications 사용 불가
    private var isSwiftPackageMode: Bool {
        return Bundle.main.bundleIdentifier == nil || Bundle.main.bundleIdentifier?.isEmpty == true
    }
    
    private override init() {
        super.init()
        setupNotificationCenter()
    }
    
    private func setupNotificationCenter() {
        if isSwiftPackageMode {
            print("📦 Swift Package 모드 - osascript 알림만 사용")
        } else {
            print("🍎 앱 번들 모드 - UserNotifications 사용 가능")
            // 실제 앱 번들에서만 UserNotifications 설정
        }
    }
    
    // MARK: - 권한 요청
    
    func requestNotificationPermission() {
        if isSwiftPackageMode {
            print("📦 Swift Package 모드 - osascript 알림 사용")
            print("✅ osascript 알림 시스템 준비됨")
        } else {
            print("🔔 앱 번들 모드 - UserNotifications 권한 요청")
            requestUserNotificationPermission()
        }
    }
    
    private func requestUserNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        
        center.requestAuthorization(options: options) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ 알림 권한 허용됨")
                } else if let error = error {
                    print("❌ 알림 권한 실패: \(error)")
                } else {
                    print("⚠️ 알림 권한 거부됨")
                }
            }
        }
        
        center.delegate = NotificationDelegate.shared
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
        
        if isSwiftPackageMode {
            // Swift Package 환경에서는 osascript만 사용
            sendOSAScriptNotification(title: title, body: body)
        } else {
            // 앱 번들 환경에서는 UserNotifications 사용
            sendModernNotification(identifier: identifier, title: title, body: body, sound: sound ?? .default)
        }
    }
    
    private func sendModernNotification(identifier: String, title: String, body: String, sound: UNNotificationSound) {
        print("🔔 현대적인 UserNotifications로 알림 전송: [\(title)] \(body)")
        
        let center = UNUserNotificationCenter.current()
        
        // 알림 콘텐츠 생성
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.categoryIdentifier = "COPYDROP_CATEGORY"
        
        // 즉시 전송 트리거
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        // 알림 요청 생성
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        // 알림 전송
        center.add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 현대적인 알림 전송 실패: \(error)")
                    // 실패시 대체 방법 사용
                    self.sendOSAScriptNotification(title: title, body: body)
                } else {
                    print("✅ 현대적인 UserNotifications 알림 전송 성공")
                }
            }
        }
    }
    
    private func sendOSAScriptNotification(title: String, body: String) {
        let safeTitle = escapeForAppleScript(title)
        let safeBody = escapeForAppleScript(body)
        
        let script = "display notification \"\(safeBody)\" with title \"\(safeTitle)\""
        
        DispatchQueue.global(qos: .background).async {
            let process = Process()
            process.launchPath = "/usr/bin/osascript"
            process.arguments = ["-e", script]
            
            do {
                try process.run()
                process.waitUntilExit()
                print("✅ 대체 osascript 알림 전송 완료")
            } catch {
                print("❌ osascript 알림 실패: \(error.localizedDescription)")
            }
        }
    }
    
    func activateAppAndShowMenu() {
        // 앱을 포그라운드로 가져오기
        NSApp.activate(ignoringOtherApps: true)
        
        // 메뉴바 아이콘 강조 효과
        if let statusItem = (NSApp.delegate as? AppDelegate)?.statusItem {
            statusItem.button?.highlight(true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                statusItem.button?.highlight(false)
            }
            
            // 클립보드 메뉴 자동 표시
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.statusBarButtonClicked(statusItem.button!)
                }
            }
        }
        
        print("🚀 앱 활성화 및 메뉴 표시 완료")
    }
    
    private func escapeForAppleScript(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}

// MARK: - UserNotifications Delegate (앱 번들용)

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    // 앱이 포그라운드에 있을 때도 알림 표시
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🔔 포그라운드에서 알림 표시: \(notification.request.content.title)")
        
        // 포그라운드에서도 알림 표시
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
    
    // 사용자가 알림을 클릭했을 때
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("🔔 푸시 알림 클릭됨: \(response.notification.request.identifier)")
        
        // 알림 클릭 시 앱 활성화 및 메뉴 표시
        NotificationManager.shared.activateAppAndShowMenu()
        
        // 처리 완료
        completionHandler()
    }
}

// MARK: - osascript 기반 알림 시스템
// Swift Package Manager 환경에서는 UserNotifications 대신 osascript 사용