//
//  SystemTestView.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import SwiftUI

struct SystemTestView: View {
    let systemTester: SystemTester
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("🔧 시스템 통합 테스트")
                    .font(.title2)
                    .bold()
                
                // 현재 진행 상황
                if systemTester.isRunning {
                    VStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("테스트 진행 중...")
                            .font(.headline)
                        
                        Text(systemTester.currentTest)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // 테스트 실행 버튼
                HStack {
                    Button(action: runTests) {
                        HStack {
                            if systemTester.isRunning {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "play.circle.fill")
                            }
                            Text(systemTester.isRunning ? "테스트 실행 중..." : "전체 시스템 테스트 실행")
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(systemTester.isRunning)
                    
                    if !systemTester.testResults.isEmpty {
                        Button("리포트 생성") {
                            generateReport()
                        }
                        .disabled(systemTester.isRunning)
                        
                        Button("결과 지우기") {
                            systemTester.clearResults()
                        }
                        .disabled(systemTester.isRunning)
                    }
                }
                
                // 테스트 결과 요약
                if !systemTester.testResults.isEmpty {
                    let successCount = systemTester.testResults.filter(\.success).count
                    let totalCount = systemTester.testResults.count
                    
                    HStack {
                        VStack {
                            Text("\(successCount)")
                                .font(.title)
                                .bold()
                                .foregroundColor(.green)
                            Text("성공")
                                .font(.caption)
                        }
                        
                        VStack {
                            Text("\(totalCount - successCount)")
                                .font(.title)
                                .bold()
                                .foregroundColor(.red)
                            Text("실패")
                                .font(.caption)
                        }
                        
                        VStack {
                            Text("\(totalCount)")
                                .font(.title)
                                .bold()
                                .foregroundColor(.blue)
                            Text("전체")
                                .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // 테스트 결과 목록
                if !systemTester.testResults.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("테스트 결과 상세")
                            .font(.headline)
                        
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(systemTester.testResults.indices, id: \.self) { index in
                                    let result = systemTester.testResults[index]
                                    SystemTestResultRow(result: result)
                                }
                            }
                        }
                    }
                } else if !systemTester.isRunning {
                    VStack {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("시스템 테스트를 실행하여\n전체 기능을 검증하세요")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("시스템 테스트")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .frame(width: 700, height: 600)
    }
    
    private func runTests() {
        Task {
            await systemTester.runFullSystemTest()
        }
    }
    
    private func generateReport() {
        let report = systemTester.generateSystemReport()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
    }
}

struct SystemTestResultRow: View {
    let result: SystemTester.TestResult
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 성공/실패 아이콘
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.testName)
                        .font(.headline)
                    
                    Text(result.message)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if result.details != nil {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                }
            }
            
            // 확장된 상세 정보
            if isExpanded, let details = result.details {
                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 30)
                    .padding(.top, 4)
            }
            
            Text(result.timestamp.formatted(.dateTime.hour().minute().second()))
                .font(.caption2)
                .foregroundColor(.tertiary)
                .padding(.leading, 30)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(result.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(result.success ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    SystemTestView(systemTester: SystemTester())
}
