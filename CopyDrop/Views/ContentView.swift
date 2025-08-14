//
//  ContentView.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import SwiftUI
import SwiftData
import AppKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var errorHandler: ErrorHandler
    @State private var clipboardService: ClipboardSyncService
    @State private var syncManager: SyncManager
    @State private var encryptionTester: EncryptionTester
    @State private var systemTester: SystemTester
    @State private var showingSettings: Bool = false
    @State private var showingEncryptionTest: Bool = false
    @State private var showingErrorLog: Bool = false
    @State private var showingSystemTest: Bool = false
    @State private var serverURL = AppConstants.Network.defaultServerURL
    @State private var syncMode: SyncMode = .server
    
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) 
    private var clipboardItems: [ClipboardItem]
    
    enum SyncMode: String, CaseIterable {
        case server = "서버"
        case client = "클라이언트"
    }
    
    init() {
        let errorHandler = ErrorHandler()
        _errorHandler = State(wrappedValue: errorHandler)
        _clipboardService = State(wrappedValue: ClipboardSyncService(errorHandler: errorHandler))
        _syncManager = State(wrappedValue: SyncManager(errorHandler: errorHandler))
        _encryptionTester = State(wrappedValue: EncryptionTester(errorHandler: errorHandler))
        _systemTester = State(wrappedValue: SystemTester())
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 16) {
                // 동기화 모드 선택
                HStack {
                    Text("동기화 모드:")
                        .font(.headline)
                    
                    Picker("동기화 모드", selection: $syncMode) {
                        ForEach(SyncMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // 통합 동기화 상태
                StatusIndicatorView(
                    isConnected: syncManager.isServerRunning || syncManager.isClientConnected,
                    status: syncManager.connectionStatus,
                    lastUpdate: syncManager.lastSyncTime
                )
                
                // 추가 정보
                if syncManager.isServerRunning {
                    StatusIndicatorView(
                        isConnected: syncManager.syncedDevicesCount > 0,
                        status: "연결된 디바이스: \(syncManager.syncedDevicesCount)개",
                        lastUpdate: nil
                    )
                }
                
                // 클립보드 히스토리 리스트
                List {
                    ForEach(clipboardItems) { item in
                        ClipboardItemView(item: item) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.content, forType: .string)
                        }
                    }
                    .onDelete(perform: deleteClipboardItems)
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("CopyDrop")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: testClipboard) {
                        Label("클립보드 테스트", systemImage: "testtube.2")
                    }
                    
                    Button(action: { showingEncryptionTest.toggle() }) {
                        Label("암호화 테스트", systemImage: "lock.shield")
                    }
                    
                    Button(action: { showingSystemTest.toggle() }) {
                        Label("시스템 테스트", systemImage: "checkmark.seal")
                    }
                    
                    Button(action: { showingErrorLog.toggle() }) {
                        Label("오류 로그", systemImage: "exclamationmark.triangle")
                    }
                    
                    Button(action: { showingSettings.toggle() }) {
                        Label("설정", systemImage: "gear")
                    }
                    
                    Button(action: toggleSync) {
                        Label(
                            (syncManager.isServerRunning || syncManager.isClientConnected) ? "동기화 중지" : "동기화 시작",
                            systemImage: (syncManager.isServerRunning || syncManager.isClientConnected) ? "stop.circle" : "play.circle"
                        )
                    }
                    
                    Button(action: { syncManager.syncClipboard() }) {
                        Label("수동 동기화", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(!(syncManager.isServerRunning || syncManager.isClientConnected))
                }
            }
        } detail: {
            if let selectedItem = clipboardItems.first {
                VStack(alignment: .leading, spacing: 16) {
                    Text("최근 클립보드")
                        .font(.title2)
                        .bold()
                    
                    ScrollView {
                        Text(selectedItem.content)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("소스: \(selectedItem.source)")
                            Text("시간: \(selectedItem.timestamp.formatted())")
                            Text("해시: \(selectedItem.hash.prefix(16))...")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("클립보드에 복사") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(selectedItem.content, forType: .string)
                        }
                    }
                }
                .padding()
            } else {
                Text("클립보드 히스토리가 없습니다")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            clipboardService.setModelContext(modelContext)
            syncManager.setModelContext(modelContext)
            systemTester.setModelContext(modelContext)
        }
        .onDisappear {
            syncManager.stopSync()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                serverURL: $serverURL,
                showingErrorLog: $showingErrorLog,
                syncManager: syncManager,
                errorHandler: errorHandler
            )
        }
        .sheet(isPresented: $showingEncryptionTest) {
            EncryptionTestView(encryptionTester: encryptionTester)
        }
        .sheet(isPresented: $showingErrorLog) {
            ErrorLogView(errorHandler: errorHandler)
        }
        .sheet(isPresented: $showingSystemTest) {
            SystemTestView(systemTester: systemTester)
        }
        .alert("오류", isPresented: $errorHandler.showingError, presenting: errorHandler.currentError) { error in
            Button("다시 시도") {
                toggleSync()
            }
            Button("취소", role: .cancel) { }
        } message: { error in
            Text(error.localizedDescription + "\n\n" + (error.recoverySuggestion ?? ""))
        }
    }
    
    private func toggleSync() {
        if syncManager.isServerRunning || syncManager.isClientConnected {
            syncManager.stopSync()
        } else {
            switch syncMode {
            case .server:
                syncManager.startAsServer()
            case .client:
                syncManager.startAsClient(serverURL: serverURL)
            }
        }
    }
    
    private func deleteClipboardItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(clipboardItems[index])
            }
        }
    }
    
    private func testClipboard() {
        let testTexts = [
            "테스트 클립보드 내용 #1 - \(Date().formatted(.dateTime.hour().minute().second()))",
            "🎉 이모지 테스트 내용 #2",
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
            "한글 테스트 - 안녕하세요 CopyDrop! 🚀",
            "다국어 테스트: Hello 你好 こんにちは 안녕하세요 🌍",
            "코드 테스트: func hello() { print(\"Hello World\") }"
        ]
        
        let randomText = testTexts.randomElement() ?? "기본 테스트 내용"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(randomText, forType: .string)
        
        // 수동 동기화 트리거
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            syncManager.syncClipboard()
        }
    }
}



// MARK: - Settings View
struct SettingsView: View {
    @Binding var serverURL: String
    @Binding var showingErrorLog: Bool
    let syncManager: SyncManager
    let errorHandler: ErrorHandler
    @Environment(\.dismiss) private var dismiss
    @State private var showingQRCode = false
    @State private var qrCodeContent = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("연결 설정") {
                    TextField("서버 URL", text: $serverURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if let localIP = NetworkUtils.getLocalIPAddress() {
                        HStack {
                            Text("로컬 IP: \(localIP)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("복사") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString("ws://\(localIP):8787/ws", forType: .string)
                            }
                            .font(.caption)
                        }
                    }
                }
                
                Section("동기화 상태") {
                    HStack {
                        Text("서버 상태")
                        Spacer()
                        Text(syncManager.isServerRunning ? "실행중" : "중지됨")
                            .foregroundColor(syncManager.isServerRunning ? .green : .red)
                    }
                    
                    HStack {
                        Text("클라이언트 상태")
                        Spacer()
                        Text(syncManager.isClientConnected ? "연결됨" : "연결 안됨")
                            .foregroundColor(syncManager.isClientConnected ? .green : .red)
                    }
                    
                    if syncManager.isServerRunning {
                        HStack {
                            Text("연결된 디바이스")
                            Spacer()
                            Text("\(syncManager.syncedDevicesCount)개")
                        }
                    }
                }
                
                Section("보안") {
                    Button("암호화 키 QR 코드 표시") {
                        if let qrKey = SecurityManager.shared.exportKeyForQRCode() {
                            qrCodeContent = qrKey
                            showingQRCode = true
                        }
                    }
                    
                    Button("새 암호화 키 생성") {
                        _ = SecurityManager.shared.generateAndStoreEncryptionKey()
                    }
                    .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("오류 로그")
                        .font(.headline)
                        .padding(.bottom, 4)
                    HStack {
                        Text("최근 오류")
                        Spacer()
                        Text("\(errorHandler.errorHistory.count)개")
                            .foregroundColor(errorHandler.errorHistory.isEmpty ? .green : .orange)
                    }
                    
                    if !errorHandler.errorHistory.isEmpty {
                        Button("오류 로그 보기") {
                            showingErrorLog = true
                        }
                        
                        Button("오류 로그 내보내기") {
                            let log = errorHandler.exportErrorLog()
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(log, forType: .string)
                        }
                    }
                }
                
                Section("정보") {
                    Text("CopyDrop을 사용하면 여러 기기 간에 클립보드를 안전하게 동기화할 수 있습니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("설정")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .frame(width: AppConstants.UI.settingsWindowWidth, height: AppConstants.UI.settingsWindowHeight)
        .sheet(isPresented: $showingQRCode) {
            QRCodeView(content: qrCodeContent)
        }
    }
}

// MARK: - QR Code View
struct QRCodeView: View {
    let content: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("암호화 키 QR 코드")
                .font(.title2)
                .bold()
            
            Text("다른 디바이스에서 이 QR 코드를 스캔하여 암호화 키를 공유하세요")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            // QR 코드 이미지 (실제 구현에서는 Core Image 사용)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .frame(width: 200, height: 200)
                .overlay(
                    Text("QR Code\n\(content.prefix(16))...")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                )
                .border(Color.black, width: 1)
            
            Button("복사") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(content, forType: .string)
            }
            
            Button("닫기") {
                dismiss()
            }
        }
        .padding()
        .frame(width: AppConstants.UI.qrCodeWindowWidth, height: AppConstants.UI.qrCodeWindowHeight)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ClipboardItem.self, inMemory: true)
}
