//
//  ClipboardItemView.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import SwiftUI

struct ClipboardItemView: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 내용 미리보기
            HStack {
                Text(item.content.clipboardPreview)
                    .lineLimit(2)
                    .font(.body)
                    .textSelection(.enabled)
                
                Spacer()
                
                // 소스 아이콘
                sourceIcon
            }
            
            // 메타데이터
            HStack {
                Label(item.source, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(item.timestamp.relativeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 해시 정보 (개발용)
            #if DEBUG
            Text("Hash: \(item.hash.prefix(16))...")
                .font(.caption2)
                .foregroundColor(.tertiary)
                .textSelection(.enabled)
            #endif
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button("클립보드에 복사") {
                onCopy()
            }
            
            Button("내용 공유") {
                shareContent()
            }
            
            #if DEBUG
            Button("해시 복사") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.hash, forType: .string)
            }
            #endif
        }
    }
    
    @ViewBuilder
    private var sourceIcon: some View {
        Group {
            if item.isLocal {
                Image(systemName: "laptopcomputer")
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.green)
            }
        }
        .font(.caption)
    }
    
    private func shareContent() {
        let activityVC = NSActivityViewController(
            activityItems: [item.content],
            applicationActivities: nil
        )
        
        if let window = NSApplication.shared.keyWindow {
            window.contentViewController?.present(activityVC, animated: true)
        }
    }
}

#Preview {
    VStack {
        ClipboardItemView(
            item: ClipboardItem(content: "예시 클립보드 내용입니다. 이것은 테스트용 텍스트입니다."),
            onCopy: {}
        )
        
        ClipboardItemView(
            item: ClipboardItem(content: "원격 디바이스에서 온 내용", source: "iPhone", isLocal: false),
            onCopy: {}
        )
    }
    .padding()
}
