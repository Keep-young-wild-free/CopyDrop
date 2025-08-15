//
//  EncryptionTestView.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import SwiftUI

struct EncryptionTestView: View {
    let encryptionTester: EncryptionTester
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("🔐 암호화 시스템 테스트")
                    .font(.title2)
                    .bold()
                
                // 테스트 실행 버튼
                HStack {
                    Button(action: runTests) {
                        HStack {
                            if encryptionTester.isRunning {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "play.circle.fill")
                            }
                            Text(encryptionTester.isRunning ? "테스트 실행 중..." : "전체 테스트 실행")
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(encryptionTester.isRunning)
                    
                    Button("결과 지우기") {
                        encryptionTester.clearResults()
                    }
                    .disabled(encryptionTester.isRunning || encryptionTester.testResults.isEmpty)
                }
                
                // 테스트 결과 표시
                if !encryptionTester.testResults.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("테스트 결과")
                            .font(.headline)
                        
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(encryptionTester.testResults.indices, id: \.self) { index in
                                    let result = encryptionTester.testResults[index]
                                    TestResultRow(result: result)
                                }
                            }
                        }
                    }
                } else {
                    VStack {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("암호화 테스트를 실행하여\n보안 시스템을 검증하세요")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("암호화 테스트")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .frame(width: 600, height: 500)
    }
    
    private func runTests() {
        Task {
            await encryptionTester.runAllTests()
        }
    }
}

struct TestResultRow: View {
    let result: EncryptionTester.TestResult
    
    var body: some View {
        HStack {
            // 성공/실패 아이콘
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.testName)
                    .font(.headline)
                
                Text(result.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(result.timestamp.formatted(.dateTime.hour().minute().second()))
                    .font(.caption2)
                    .foregroundColor(Color.secondary.opacity(0.7))
            }
            
            Spacer()
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
    EncryptionTestView(encryptionTester: EncryptionTester())
}
