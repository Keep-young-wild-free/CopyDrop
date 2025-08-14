//
//  StatusIndicatorView.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import SwiftUI

struct StatusIndicatorView: View {
    let isConnected: Bool
    let status: String
    let lastUpdate: Date?
    
    var body: some View {
        HStack {
            Circle()
                .fill(isConnected ? .green : .red)
                .frame(width: AppConstants.UI.statusIndicatorSize, 
                       height: AppConstants.UI.statusIndicatorSize)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(status)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let lastUpdate = lastUpdate {
                    Text("마지막 업데이트: \(lastUpdate.relativeString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isConnected ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 10) {
        StatusIndicatorView(
            isConnected: true,
            status: "연결됨",
            lastUpdate: Date()
        )
        
        StatusIndicatorView(
            isConnected: false,
            status: "연결 안됨",
            lastUpdate: nil
        )
    }
    .padding()
}
