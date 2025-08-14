//
//  ClipboardMonitor.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import Foundation
import AppKit
import SwiftData

/// 간단한 클립보드 모니터링 서비스
@MainActor
@Observable
class ClipboardMonitor {
    var isMonitoring: Bool = false
    var lastContent: String = ""
    var changeCount: Int = 0
    
    private var timer: Timer?
    private var modelContext: ModelContext?
    private let logger = Logger.shared
    private let errorHandler: ErrorHandler
    
    init(errorHandler: ErrorHandler? = nil) {
        self.errorHandler = errorHandler ?? ErrorHandler()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        logger.logClipboard("클립보드 모니터링 시작")
        
        // 현재 클립보드 내용 저장
        lastContent = getCurrentClipboardContent()
        
        // 타이머 시작
        timer = Timer.scheduledTimer(withTimeInterval: AppConstants.Clipboard.monitorInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboardChanges()
            }
        }
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        logger.logClipboard("클립보드 모니터링 중지")
    }
    
    private func checkClipboardChanges() {
        let currentContent = getCurrentClipboardContent()
        
        // 내용이 변경되었는지 확인
        if currentContent != lastContent && !currentContent.isEmpty {
            logger.logClipboard("클립보드 변경 감지: \(currentContent.clipboardPreview)")
            
            // 필터링 검사
            let filterResult = SecurityManager.shared.filterClipboardContent(currentContent)
            if filterResult.allowed {
                saveClipboardItem(content: currentContent)
                changeCount += 1
            } else {
                logger.logSecurity("클립보드 내용 필터링됨: \(filterResult.reason ?? "unknown")")
            }
            
            lastContent = currentContent
        }
    }
    
    private func getCurrentClipboardContent() -> String {
        return NSPasteboard.general.string(forType: .string) ?? ""
    }
    
    private func saveClipboardItem(content: String) {
        guard let context = modelContext else {
            logger.log("ModelContext가 설정되지 않음", level: LogLevel.warning)
            return
        }
        
        let item = ClipboardItem(content: content, source: "local", isLocal: true)
        context.insert(item)
        
        do {
            try context.save()
            logger.logClipboard("클립보드 아이템 저장됨")
        } catch {
            logger.log("클립보드 아이템 저장 실패: \(error)", level: LogLevel.error)
        }
    }
    
    /// 수동으로 클립보드에 내용 설정
    func setClipboardContent(_ content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        lastContent = content // 자체 변경이므로 lastContent 업데이트
        logger.logClipboard("클립보드에 내용 설정: \(content.clipboardPreview)")
    }
}
