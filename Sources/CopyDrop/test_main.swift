import AppKit

// 임시 테스트용 단순한 메뉴바 앱
class SimpleAppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🔥 Simple App 시작!")
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "📋"
            print("✅ 메뉴바 아이템 생성 완료")
        } else {
            print("❌ 메뉴바 아이템 생성 실패")
        }
    }
}

// 테스트 실행
func testRun() {
    let app = NSApplication.shared
    let delegate = SimpleAppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    
    print("🚀 테스트 앱 시작")
    app.run()
}

// testRun()  // 필요시 이 줄의 주석을 해제하고 Main.main() 주석 처리