import SwiftUI

struct AdvancedSettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @State private var newKeyword = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // 상단 바 with 닫기 버튼
            HStack {
                Text("CopyDrop 고급 설정")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("닫기") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerDescription
                
                syncSettingsSection
                Divider()
                
                filteringSettingsSection
                Divider()
                
                historySettingsSection
                Divider()
                
                securitySettingsSection
                Divider()
                
                resetSection
            }
            .padding(24)
        }
        }
        .frame(width: 500, height: 600)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var headerDescription: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("클립보드 동기화 및 보안 설정을 관리합니다")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 동기화 설정
    private var syncSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("동기화 설정", systemImage: "arrow.triangle.2.circlepath")
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("자동 동기화 활성화", isOn: $settings.isAutoSyncEnabled)
                    .toggleStyle(.switch)
                
                if settings.isAutoSyncEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("동기화 지연 시간: \(String(format: "%.1f", settings.syncDelay))초")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(value: $settings.syncDelay, in: 0.1...2.0, step: 0.1) {
                            Text("지연 시간")
                        }
                        .frame(maxWidth: 300)
                    }
                    .padding(.leading, 20)
                }
            }
        }
    }
    
    // MARK: - 필터링 설정
    private var filteringSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("콘텐츠 필터링", systemImage: "shield.lefthalf.filled")
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("민감한 콘텐츠 필터링", isOn: $settings.isContentFilteringEnabled)
                    .toggleStyle(.switch)
                
                if settings.isContentFilteringEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        // 최대 길이 설정
                        VStack(alignment: .leading, spacing: 8) {
                            Text("최대 콘텐츠 길이: \(settings.maxContentLength) 글자")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Slider(value: Binding(
                                get: { Double(settings.maxContentLength) },
                                set: { settings.maxContentLength = Int($0) }
                            ), in: 1000...50000, step: 1000) {
                                Text("최대 길이")
                            }
                            .frame(maxWidth: 300)
                        }
                        
                        // 차단 키워드
                        VStack(alignment: .leading, spacing: 8) {
                            Text("차단 키워드")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            // 키워드 추가
                            HStack {
                                TextField("새 키워드 추가...", text: $newKeyword)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button("추가") {
                                    addKeyword()
                                }
                                .disabled(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            
                            // 기존 키워드 목록
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 120))
                            ], spacing: 8) {
                                ForEach(settings.blockedKeywords, id: \.self) { keyword in
                                    keywordTag(keyword)
                                }
                            }
                        }
                    }
                    .padding(.leading, 20)
                }
            }
        }
    }
    
    // MARK: - 히스토리 설정
    private var historySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("히스토리 관리", systemImage: "clock.arrow.circlepath")
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("클립보드 히스토리 저장", isOn: $settings.isHistoryEnabled)
                    .toggleStyle(.switch)
                
                if settings.isHistoryEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("최대 보관 개수: \(settings.maxHistoryCount)개")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(value: Binding(
                            get: { Double(settings.maxHistoryCount) },
                            set: { settings.maxHistoryCount = Int($0) }
                        ), in: 10...200, step: 10) {
                            Text("보관 개수")
                        }
                        .frame(maxWidth: 300)
                    }
                    .padding(.leading, 20)
                }
            }
        }
    }
    
    // MARK: - 보안 설정
    private var securitySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("보안 설정", systemImage: "lock.shield")
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("데이터 암호화", isOn: $settings.isEncryptionEnabled)
                    .toggleStyle(.switch)
                
                Toggle("동기화 시 확인 요청", isOn: $settings.requiresConfirmation)
                    .toggleStyle(.switch)
            }
        }
    }
    
    // MARK: - 초기화 섹션
    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("초기화", systemImage: "arrow.counterclockwise")
            
            Button("설정 초기화") {
                resetSettings()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
    
    // MARK: - Helper Views
    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundColor(.blue)
                .font(.title3)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
    
    private func keywordTag(_ keyword: String) -> some View {
        HStack(spacing: 4) {
            Text(keyword)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            
            Button(action: {
                removeKeyword(keyword)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    private func addKeyword() {
        let trimmed = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !settings.blockedKeywords.contains(trimmed) {
            settings.blockedKeywords.append(trimmed)
            newKeyword = ""
        }
    }
    
    private func removeKeyword(_ keyword: String) {
        settings.blockedKeywords.removeAll { $0 == keyword }
    }
    
    private func resetSettings() {
        settings.resetToDefaults()
    }
}