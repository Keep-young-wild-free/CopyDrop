import SwiftUI
import AppKit

// 메인 클래스 정의
class Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        
        // App 활성화 정책 설정
        app.setActivationPolicy(.accessory)
        
        print("🚀 CopyDrop 앱 시작 중...")
        
        // 런루프 시작
        app.run()
    }
}

// 프로그램 진입점
Main.main()