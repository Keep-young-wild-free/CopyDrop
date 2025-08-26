import Foundation
import AppKit

/**
 * Mac용 사용자 친화적인 에러 핸들링
 */
class ErrorHandler {
    static let shared = ErrorHandler()
    
    private init() {}
    
    /**
     * 에러 타입 정의
     */
    enum CopyDropError {
        case bluetoothNotAvailable
        case bluetoothNotAuthorized
        case connectionTimeout
        case deviceNotFound
        case pinExpired
        case invalidPin
        case encryptionFailed
        case clipboardAccessFailed
        case dataTooLarge(size: String)
        case networkError(String)
        case unknown(String)
        
        var title: String {
            switch self {
            case .bluetoothNotAvailable:
                return "블루투스 사용 불가"
            case .bluetoothNotAuthorized:
                return "블루투스 권한 필요"
            case .connectionTimeout:
                return "연결 시간 초과"
            case .deviceNotFound:
                return "Android 기기를 찾을 수 없음"
            case .pinExpired:
                return "PIN 만료"
            case .invalidPin:
                return "잘못된 PIN"
            case .encryptionFailed:
                return "암호화 실패"
            case .clipboardAccessFailed:
                return "클립보드 접근 실패"
            case .dataTooLarge:
                return "데이터 크기 초과"
            case .networkError:
                return "네트워크 오류"
            case .unknown:
                return "예상치 못한 오류"
            }
        }
        
        var message: String {
            switch self {
            case .bluetoothNotAvailable:
                return "블루투스가 꺼져있거나 사용할 수 없습니다. 시스템 설정에서 블루투스를 켜주세요."
            case .bluetoothNotAuthorized:
                return "CopyDrop이 블루투스를 사용하려면 권한이 필요합니다. 시스템 설정 > 개인정보 보호 및 보안 > 블루투스에서 권한을 허용해주세요."
            case .connectionTimeout:
                return "Android 기기와의 연결 시간이 초과되었습니다. Android 앱이 실행 중인지 확인하고 다시 시도해주세요."
            case .deviceNotFound:
                return "CopyDrop이 실행 중인 Android 기기를 찾을 수 없습니다. Android 앱에서 '기기 검색'을 눌러주세요."
            case .pinExpired:
                return "PIN이 만료되었습니다. 새로운 PIN을 생성해주세요."
            case .invalidPin:
                return "입력된 PIN이 올바르지 않습니다."
            case .encryptionFailed:
                return "데이터 암호화에 실패했습니다. 다시 시도해주세요."
            case .clipboardAccessFailed:
                return "클립보드에 접근할 수 없습니다. 시스템 설정에서 접근성 권한을 확인해주세요."
            case .dataTooLarge(let size):
                return "데이터가 너무 큽니다 (\(size)). Wi-Fi 환경에서 더 빠르게 전송할 수 있습니다."
            case .networkError(let details):
                return "네트워크 오류가 발생했습니다: \(details)"
            case .unknown(let details):
                return "알 수 없는 오류가 발생했습니다: \(details)"
            }
        }
        
        var actionText: String? {
            switch self {
            case .bluetoothNotAvailable:
                return "시스템 설정 열기"
            case .bluetoothNotAuthorized:
                return "개인정보 보호 설정 열기"
            case .connectionTimeout:
                return "다시 시도"
            case .deviceNotFound:
                return "다시 검색"
            case .pinExpired:
                return "새 PIN 생성"
            case .clipboardAccessFailed:
                return "접근성 설정 열기"
            default:
                return "다시 시도"
            }
        }
    }
    
    /**
     * 에러 대화상자 표시
     */
    func showError(_ error: CopyDropError, completion: ((Bool) -> Void)? = nil) {
        print("❌ 에러 발생: \(error.title) - \(error.message)")
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = error.title
            alert.informativeText = error.message
            alert.alertStyle = .warning
            
            // 기본 버튼
            alert.addButton(withTitle: "확인")
            
            // 액션 버튼 (있는 경우)
            if let actionText = error.actionText {
                alert.addButton(withTitle: actionText)
            }
            
            let response = alert.runModal()
            
            // 액션 버튼이 클릭된 경우 (두 번째 버튼)
            if response == .alertSecondButtonReturn {
                self.performAction(for: error)
                completion?(true)
            } else {
                completion?(false)
            }
        }
    }
    
    /**
     * 간단한 정보 메시지 표시
     */
    func showInfo(_ message: String) {
        print("ℹ️ 정보: \(message)")
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "정보"
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "확인")
            alert.runModal()
        }
    }
    
    /**
     * 성공 메시지 표시
     */
    func showSuccess(_ message: String) {
        print("✅ 성공: \(message)")
        
        // 알림으로 표시 (대화상자보다 덜 방해적)
        NotificationManager.shared.sendLocalCopyNotification(content: "✅ \(message)")
    }
    
    /**
     * 확인 대화상자 표시
     */
    func showConfirmation(title: String, message: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "확인")
            alert.addButton(withTitle: "취소")
            
            let response = alert.runModal()
            completion(response == .alertFirstButtonReturn)
        }
    }
    
    /**
     * 에러별 액션 수행
     */
    private func performAction(for error: CopyDropError) {
        switch error {
        case .bluetoothNotAvailable:
            openBluetoothSettings()
        case .bluetoothNotAuthorized:
            openPrivacySettings()
        case .clipboardAccessFailed:
            openAccessibilitySettings()
        default:
            break
        }
    }
    
    /**
     * 블루투스 설정 열기
     */
    private func openBluetoothSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.bluetooth")!)
    }
    
    /**
     * 개인정보 보호 설정 열기
     */
    private func openPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")!)
    }
    
    /**
     * 접근성 설정 열기
     */
    private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    
    /**
     * Exception으로부터 CopyDropError 생성
     */
    static func fromError(_ error: Error) -> CopyDropError {
        let description = error.localizedDescription.lowercased()
        
        switch true {
        case description.contains("bluetooth"):
            return .bluetoothNotAvailable
        case description.contains("timeout"):
            return .connectionTimeout
        case description.contains("connection"):
            return .deviceNotFound
        case description.contains("encryption"):
            return .encryptionFailed
        default:
            return .unknown(error.localizedDescription)
        }
    }
}