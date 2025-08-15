import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @State private var showAdvancedSettings = false
    
    var body: some View {
        VStack(spacing: 24) {
            headerView
            
            Divider()
            
            quickSettingsSection
            
            Divider()
            
            appInfoSection
            
            Spacer()
            
            footerButtons
        }
        .padding(30)
        .frame(width: 350, height: 450)
        .sheet(isPresented: $showAdvancedSettings) {
            AdvancedSettingsView()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("CopyDrop 설정")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Text("클립보드 동기화 설정")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var quickSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("빠른 설정")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Toggle("자동 동기화", isOn: $settings.isAutoSyncEnabled)
                        .toggleStyle(.switch)
                }
                
                HStack {
                    Toggle("콘텐츠 필터링", isOn: $settings.isContentFilteringEnabled)
                        .toggleStyle(.switch)
                }
                
                HStack {
                    Toggle("히스토리 저장", isOn: $settings.isHistoryEnabled)
                        .toggleStyle(.switch)
                }
                
                HStack {
                    Toggle("암호화", isOn: $settings.isEncryptionEnabled)
                        .toggleStyle(.switch)
                }
            }
        }
    }
    
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("앱 정보")
                .font(.headline)
            
            VStack(spacing: 8) {
                infoRow("버전", "1.0.0")
                infoRow("개발자", "CopyDrop Team")
                infoRow("지원", "macOS 13.0+")
                infoRow("라이선스", "MIT License")
            }
        }
    }
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
    
    private var footerButtons: some View {
        VStack(spacing: 12) {
            Button("고급 설정...") {
                showAdvancedSettings = true
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            
            HStack(spacing: 12) {
                Button("도움말") {
                    if let url = URL(string: "https://github.com/yourusername/CopyDrop/blob/main/README.md") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                
                Button("피드백") {
                    if let url = URL(string: "https://github.com/yourusername/CopyDrop/issues/new") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
            
            Text("설정은 자동으로 저장됩니다")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}