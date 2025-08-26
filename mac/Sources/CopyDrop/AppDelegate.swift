import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    var pinDisplayWindow: NSWindow?
    var clipboardHubWindow: NSWindow?
    var pinAuthManager = PinAuthManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🎯 AppDelegate.applicationDidFinishLaunching 호출됨")
        
        // 개발 중에는 중복 실행 방지 로직 건너뛰기
        print("🔄 앱 초기화 진행...")
        
        setupMenuBar()
        setupAppStateObservers()
        
        // 푸시 알림 권한 요청
        NotificationManager.shared.requestNotificationPermission()
        
        // 서비스 시작
        ClipboardManager.shared.start()
        BluetoothManager.shared.pinAuthManager = PinAuthManager.shared
        BluetoothManager.shared.start()
        
        print("✅ CopyDrop 초기화 완료")
    }
    
    private func setupAppStateObservers() {
        // 앱이 활성화될 때 (포그라운드 전환)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("📱 앱 포그라운드 전환 감지")
            ClipboardManager.shared.onAppForeground()
        }
        
        // 앱이 비활성화될 때 (백그라운드 전환)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("📱 앱 백그라운드 전환 감지")
        }
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
        // 메뉴바 클릭 시 스마트 폴링 재시작 (사용자 활동 감지)
        ClipboardManager.shared.forceCheckClipboard()
        
        // Maccy 스타일: 클릭 시 클립보드 메뉴 표시
        showClipboardMenu()
    }
    
    private func showClipboardMenu() {
        let menu = NSMenu()
        
        // 클립보드 히스토리 항목들 (최대 10개)
        let history = ClipboardManager.shared.history.prefix(10)
        print("🍎 메뉴 표시 - 히스토리 항목 수: \(ClipboardManager.shared.history.count)")
        
        if history.isEmpty {
            // 빈 상태
            print("📭 히스토리가 비어있음")
            let emptyItem = NSMenuItem(title: "클립보드 기록이 없습니다", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            print("📋 히스토리 항목 \(history.count)개 표시")
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
        
        // 메뉴 너비 고정 (50글자 + "..." 기준으로 계산)
        let sampleText = String(repeating: "A", count: 50) + "..."  // 최대 길이 텍스트
        let font = NSFont.menuFont(ofSize: 0)  // 기본 메뉴 폰트
        let textSize = sampleText.size(withAttributes: [.font: font])
        let menuWidth = textSize.width + 60  // 아이콘 + 패딩 여백
        
        menu.minimumWidth = menuWidth
        print("🎨 메뉴 너비 설정: \(menuWidth)pt")
        
        // 메뉴 표시 (statusItem.button 위치에서)
        guard let button = statusItem?.button else { return }
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }
    
    private func createClipboardMenuItem(item: ClipboardItem, index: Int) -> NSMenuItem {
        let title: String
        var menuImage: NSImage?
        
        // 콘텐츠 타입에 따른 제목 및 아이콘 설정
        switch item.type {
        case .image:
            title = item.preview
            // 이미지 미리보기 생성 (24x24 크기)
            if let nsImage = item.nsImage {
                menuImage = createThumbnail(from: nsImage, size: NSSize(width: 24, height: 24))
            }
            
        case .text:
            // 미리보기 텍스트 생성 (최대 50글자)
            let preview = item.content.replacingOccurrences(of: "\n", with: " ")
                                     .replacingOccurrences(of: "\t", with: " ")
                                     .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let truncated = preview.count > 50 ? String(preview.prefix(50)) + "..." : preview
            title = truncated.isEmpty ? "(빈 내용)" : truncated
            
            // 소스 표시 (원격에서 온 경우)
            if item.source == .remote {
                menuImage = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "원격")
                menuImage?.size = NSSize(width: 12, height: 12)
            }
        }
        
        // 키보드 단축키 (1-9, 0)
        let keyEquivalent = index < 9 ? String(index + 1) : (index == 9 ? "0" : "")
        
        let menuItem = NSMenuItem(title: title, action: #selector(clipboardMenuItemSelected(_:)), keyEquivalent: keyEquivalent)
        menuItem.target = self
        menuItem.representedObject = item
        menuItem.image = menuImage
        
        // 10MB 이상 이미지일 때 빨간색 텍스트로 표시
        if item.type == .image, 
           let imageData = item.imageData,
           imageData.count > 10 * 1024 * 1024 {
            let attributedTitle = NSMutableAttributedString(string: title)
            
            // "WiFi 권장" 부분만 빨간색으로 설정
            if let range = title.range(of: "(큰 용량, WiFi 권장)") {
                let nsRange = NSRange(range, in: title)
                attributedTitle.addAttribute(.foregroundColor, value: NSColor.systemRed, range: nsRange)
            }
            
            menuItem.attributedTitle = attributedTitle
        }
        
        return menuItem
    }
    
    /**
     * 이미지에서 썸네일 생성
     */
    private func createThumbnail(from image: NSImage, size: NSSize) -> NSImage {
        let thumbnail = NSImage(size: size)
        thumbnail.lockFocus()
        
        // 비율 유지하면서 크기 조정
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        
        var drawRect: NSRect
        if aspectRatio > 1 {
            // 가로가 더 긴 경우
            let newHeight = size.width / aspectRatio
            drawRect = NSRect(x: 0, y: (size.height - newHeight) / 2, width: size.width, height: newHeight)
        } else {
            // 세로가 더 긴 경우
            let newWidth = size.height * aspectRatio
            drawRect = NSRect(x: (size.width - newWidth) / 2, y: 0, width: newWidth, height: size.height)
        }
        
        image.draw(in: drawRect)
        thumbnail.unlockFocus()
        
        return thumbnail
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
        
        // Pin 연결
        let pinConnectItem = NSMenuItem(title: "Pin으로 연결...", action: #selector(showPinConnection), keyEquivalent: "p")
        pinConnectItem.target = self
        menu.addItem(pinConnectItem)
        
        // 클립보드 허브
        let clipboardHubItem = NSMenuItem(title: "클립보드 허브...", action: #selector(showClipboardHub), keyEquivalent: "h")
        clipboardHubItem.target = self
        menu.addItem(clipboardHubItem)
        
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
        
        // 클립보드에 복사 (타입에 따라 다르게 처리)
        NSPasteboard.general.clearContents()
        
        switch item.type {
        case .image:
            if let imageData = item.imageData, let image = NSImage(data: imageData) {
                NSPasteboard.general.writeObjects([image])
                print("🖼️ 이미지가 클립보드에 복사됨: \(item.preview)")
            } else {
                print("❌ 이미지 데이터를 찾을 수 없음")
            }
            
        case .text:
            NSPasteboard.general.setString(item.content, forType: .string)
            print("📝 텍스트가 클립보드에 복사됨: \(item.content.prefix(30))...")
        }
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
    
    @objc func showClipboardHub() {
        // 클립보드 허브 창이 이미 열려있으면 앞으로 가져오기
        if let existingWindow = clipboardHubWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // 클립보드 허브 뷰 생성
        let clipboardHubView = ClipboardHubView(pinAuthManager: pinAuthManager)
        
        let hostingController = NSHostingController(rootView: clipboardHubView)
        
        clipboardHubWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        clipboardHubWindow?.contentViewController = hostingController
        clipboardHubWindow?.title = "클립보드 허브"
        clipboardHubWindow?.delegate = self
        clipboardHubWindow?.center()
        clipboardHubWindow?.setFrameAutosaveName("ClipboardHubWindow")
        clipboardHubWindow?.makeKeyAndOrderFront(nil)
        
        print("📋 클립보드 허브 창 열림")
    }
    
    @objc func showPinConnection() {
        // 블루투스 서버가 실행 중이 아니면 시작
        if !BluetoothManager.shared.isServerRunning {
            BluetoothManager.shared.startServer()
        }
        
        // 새 Pin 생성
        let _ = pinAuthManager.generateNewPin()
        print("🔐 Pin 연결 시작")
        
        // Pin 표시 창이 이미 열려있으면 앞으로 가져오기
        if let existingWindow = pinDisplayWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // Pin 표시 뷰 생성
        let pinDisplayView = PinDisplayView(pinAuthManager: pinAuthManager) { [weak self] in
            self?.closePinDisplay()
        }
        
        let hostingController = NSHostingController(rootView: pinDisplayView)
        
        // 새 창 생성
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "CopyDrop Pin 연결"
        window.contentViewController = hostingController
        window.center()
        window.level = .floating
        window.isReleasedWhenClosed = false
        
        // 창 델리게이트 설정
        window.delegate = self
        
        pinDisplayWindow = window
        window.makeKeyAndOrderFront(nil)
        
        // 앱을 활성화
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func closePinDisplay() {
        pinDisplayWindow?.close()
        pinDisplayWindow = nil
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
        print("🔄 CopyDrop 종료 시작 - 리소스 정리 중...")
        
        // 모든 창 닫기
        if let settingsWindow = settingsWindow {
            settingsWindow.close()
            self.settingsWindow = nil
        }
        
        if let pinDisplayWindow = pinDisplayWindow {
            pinDisplayWindow.close()
            self.pinDisplayWindow = nil
        }
        
        if let clipboardHubWindow = clipboardHubWindow {
            clipboardHubWindow.close()
            self.clipboardHubWindow = nil
        }
        
        // 서비스 정지
        ClipboardManager.shared.stop()
        BluetoothManager.shared.stop()
        
        // NotificationCenter 옵저버 제거
        NotificationCenter.default.removeObserver(self)
        
        // 메뉴바 아이템 제거
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        
        print("✅ CopyDrop 종료 완료")
    }
    
    deinit {
        print("🗑️ AppDelegate deinit 호출됨")
        // 혹시 남아있는 리소스 정리
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window == pinDisplayWindow {
                pinDisplayWindow = nil
            } else if window == settingsWindow {
                settingsWindow = nil
            }
        }
    }
}