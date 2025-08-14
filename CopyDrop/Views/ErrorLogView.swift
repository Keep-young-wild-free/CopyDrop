//
//  ErrorLogView.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import SwiftUI

struct ErrorLogView: View {
    let errorHandler: ErrorHandler
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if errorHandler.errorHistory.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("오류 없음")
                            .font(.title2)
                            .bold()
                        
                        Text("현재까지 발생한 오류가 없습니다.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(errorHandler.errorHistory.reversed()) { entry in
                            ErrorLogRow(entry: entry)
                        }
                    }
                }
            }
            .navigationTitle("오류 로그")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if !errorHandler.errorHistory.isEmpty {
                        Button("로그 내보내기") {
                            exportErrorLog()
                        }
                        
                        Button("로그 지우기") {
                            errorHandler.errorHistory.removeAll()
                        }
                    }
                    
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
    }
    
    private func exportErrorLog() {
        let log = errorHandler.exportErrorLog()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(log, forType: .string)
    }
}

struct ErrorLogRow: View {
    let entry: ErrorLogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                Text(entry.error.localizedDescription)
                    .font(.headline)
                    .lineLimit(2)
                
                Spacer()
                
                Text(entry.timestamp.formatted(.dateTime.hour().minute().second()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let suggestion = entry.error.recoverySuggestion {
                Text("해결방법: \(suggestion)")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.leading, 20)
            }
            
            Text("컨텍스트: \(entry.context)")
                .font(.caption2)
                .foregroundColor(Color.secondary.opacity(0.7))
                .padding(.leading, 20)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ErrorLogView(errorHandler: ErrorHandler())
}
