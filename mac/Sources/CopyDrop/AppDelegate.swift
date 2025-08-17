import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🎯 AppDelegate.applicationDidFinishLaunching 호출됨")
        
        setupMenuBar()
        
        // 서비스 시작
        ClipboardManager.shared.start()
        BluetoothManager.shared.start()
        
        print("✅ CopyDrop 초기화 완료")
    }
    
    private func setupMenuBar() {
        // 적절한 길이로 설정
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        guard let button = statusItem?.button else { 
            print("❌ StatusItem 버튼 생성 실패")
            return 
        }
        
        print("✅ StatusItem 생성 성공")
        
        // 메뉴바 규격에 맞는 SF Symbol 아이콘 사용
        if let image = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: "CopyDrop") {
            // 16x16 포인트로 크기 조정
            image.size = NSSize(width: 16, height: 16)
            button.image = image
            print("✅ SF Symbol 아이콘 (doc.on.clipboard.fill) 로드 성공")
        } else if let image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "CopyDrop") {
            image.size = NSSize(width: 16, height: 16)
            button.image = image
            print("✅ 대체 SF Symbol 아이콘 (clipboard) 로드 성공")
        } else {
            // 마지막 대안: 간단한 텍스트
            button.title = "📋"
            print("✅ 이모지 아이콘 사용: 📋")
        }
        
        // 템플릿 이미지로 설정하여 다크/라이트 모드 자동 대응
        button.image?.isTemplate = true
        
        // 버튼 가시성 강제 설정
        button.isEnabled = true
        statusItem?.isVisible = true
        button.action = #selector(statusBarButtonClicked(_:))
        button.target = self
        
        // 메뉴는 동적으로 생성 (statusItem.menu = nil로 설정)
        statusItem?.menu = nil
        
        print("✅ 메뉴바 설정 완료")
        print("👀 메뉴바에서 📋 아이콘을 찾아보세요")
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        // Maccy 스타일: 클릭 시 클립보드 메뉴 표시
        showClipboardMenu()
    }
    
    private func showClipboardMenu() {
        let menu = NSMenu()
        
        // 클립보드 히스토리 항목들 (최대 10개)
        let history = ClipboardManager.shared.history.prefix(10)
        
        if history.isEmpty {
            // 빈 상태
            let emptyItem = NSMenuItem(title: "클립보드 기록이 없습니다", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            // 클립보드 항목들
            for (index, item) in history.enumerated() {
                let menuItem = createClipboardMenuItem(item: item, index: index)
                menu.addItem(menuItem)
            }
        }
        
        // 구분선
        menu.addItem(NSMenuItem.separator())
        
        // 하단 옵션들
        addBottomMenuItems(to: menu)
        
        // 메뉴 표시 (statusItem.button 위치에서)
        guard let button = statusItem?.button else { return }
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }
    
    private func createClipboardMenuItem(item: ClipboardItem, index: Int) -> NSMenuItem {
        // 미리보기 텍스트 생성 (최대 50글자)
        let preview = item.content.replacingOccurrences(of: "\n", with: " ")
                                 .replacingOccurrences(of: "\t", with: " ")
                                 .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let truncated = preview.count > 50 ? String(preview.prefix(50)) + "..." : preview
        let title = truncated.isEmpty ? "(빈 내용)" : truncated
        
        // 키보드 단축키 (1-9, 0)
        let keyEquivalent = index < 9 ? String(index + 1) : (index == 9 ? "0" : "")
        
        let menuItem = NSMenuItem(title: title, action: #selector(clipboardMenuItemSelected(_:)), keyEquivalent: keyEquivalent)
        menuItem.target = self
        menuItem.representedObject = item
        
        // 소스 표시 (원격에서 온 경우)
        if item.source == .remote {
            menuItem.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "원격")
            menuItem.image?.size = NSSize(width: 12, height: 12)
        }
        
        return menuItem
    }
    
    private func addBottomMenuItems(to menu: NSMenu) {
        // 전체 삭제
        if !ClipboardManager.shared.history.isEmpty {
            let clearItem = NSMenuItem(title: "전체 삭제", action: #selector(clearClipboardHistory), keyEquivalent: "")
            clearItem.target = self
            menu.addItem(clearItem)
            menu.addItem(NSMenuItem.separator())
        }
        
        // 설정
        let settingsItem = NSMenuItem(title: "설정...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // 블루투스 상태
        let bluetoothStatus = BluetoothManager.shared.isServerRunning ? "블루투스 서버 중지" : "블루투스 서버 시작"
        let bluetoothItem = NSMenuItem(title: bluetoothStatus, action: #selector(toggleBluetoothServer), keyEquivalent: "b")
        bluetoothItem.target = self
        menu.addItem(bluetoothItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 종료
        let quitItem = NSMenuItem(title: "CopyDrop 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }
    
    
    @objc func clipboardMenuItemSelected(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardItem else { return }
        
        // 클립보드에 복사
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)
        
        print("클립보드에 복사됨: \(item.content.prefix(30))...")
    }
    
    @objc func clearClipboardHistory() {
        ClipboardManager.shared.clearHistory()
    }
    
    @objc func toggleBluetoothServer() {
        let bluetoothManager = BluetoothManager.shared
        if bluetoothManager.isServerRunning {
            bluetoothManager.stopServer()
        } else {
            bluetoothManager.startServer()
        }
    }
    
    
    @objc func showSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 250),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "CopyDrop 설정"
            settingsWindow?.contentViewController = hostingController
            settingsWindow?.center()
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        ClipboardManager.shared.stop()
        BluetoothManager.shared.stop()
    }
}