import SwiftUI

/**
 * 클립보드 허브 뷰
 * Mac을 중심으로 모든 연결된 디바이스의 클립보드를 관리합니다
 */
struct ClipboardHubView: View {
    @ObservedObject var pinAuthManager: PinAuthManager
    @State private var searchText = ""
    @State private var selectedEntry: PinAuthManager.ClipboardHubEntry?
    
    var filteredEntries: [PinAuthManager.ClipboardHubEntry] {
        if searchText.isEmpty {
            return pinAuthManager.clipboardHistory
        } else {
            return pinAuthManager.clipboardHistory.filter {
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView
                
                if filteredEntries.isEmpty {
                    emptyStateView
                } else {
                    clipboardListView
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("클립보드 허브")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(pinAuthManager.connectedDevices.count)개 디바이스 연결됨")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
            }
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("클립보드 검색...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            connectedDevicesView
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var connectedDevicesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("연결된 디바이스")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            if pinAuthManager.connectedDevices.isEmpty {
                Text("연결된 디바이스가 없습니다")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(Array(pinAuthManager.connectedDevices), id: \.self) { deviceId in
                        deviceChipView(deviceId)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func deviceChipView(_ deviceId: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            
            Text(deviceId.components(separatedBy: "-").first ?? deviceId)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clipboard")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("클립보드 기록이 없습니다")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("연결된 디바이스에서 복사한 내용이 여기에 표시됩니다")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var clipboardListView: some View {
        List(filteredEntries, id: \.id, selection: $selectedEntry) { entry in
            ClipboardEntryRow(entry: entry)
                .contextMenu {
                    Button("클립보드에 복사") {
                        copyToClipboard(entry.content)
                    }
                    
                    Button("내용 보기") {
                        selectedEntry = entry
                    }
                }
        }
        .listStyle(InsetListStyle())
    }
    
    private func copyToClipboard(_ content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        
        // 시각적 피드백
        withAnimation(.easeInOut(duration: 0.2)) {
            // 복사 완료 표시
        }
    }
}

struct ClipboardEntryRow: View {
    let entry: PinAuthManager.ClipboardHubEntry
    
    private var deviceIcon: String {
        if entry.sourceDevice.contains("android") {
            return "phone"
        } else if entry.sourceDevice.contains("mac") {
            return "desktopcomputer"
        } else {
            return "display"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 디바이스 아이콘
            Image(systemName: deviceIcon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                // 클립보드 내용
                Text(entry.content)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                // 메타데이터
                HStack {
                    Text(entry.sourceDevice.components(separatedBy: "-").first ?? entry.sourceDevice)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatTimestamp(entry.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(entry.content.count) chars")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "MM/dd HH:mm"
        } else {
            formatter.dateFormat = "yyyy/MM/dd"
        }
        return formatter.string(from: date)
    }
}

// MARK: - Preview
struct ClipboardHubView_Previews: PreviewProvider {
    static var previews: some View {
        let pinAuthManager = PinAuthManager.shared
        
        // 샘플 데이터 추가
        pinAuthManager.addClipboardEntry(content: "Hello World", from: "android-device1")
        pinAuthManager.addClipboardEntry(content: "This is a longer text that might span multiple lines in the clipboard view", from: "mac-device1")
        
        return ClipboardHubView(pinAuthManager: pinAuthManager)
            .previewLayout(.sizeThatFits)
            .frame(width: 600, height: 400)
    }
}