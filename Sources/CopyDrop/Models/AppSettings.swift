import Foundation

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // MARK: - 동기화 설정
    @Published var isAutoSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutoSyncEnabled, forKey: "isAutoSyncEnabled")
        }
    }
    
    @Published var syncDelay: Double {
        didSet {
            UserDefaults.standard.set(syncDelay, forKey: "syncDelay")
        }
    }
    
    // MARK: - 필터링 설정
    @Published var isContentFilteringEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isContentFilteringEnabled, forKey: "isContentFilteringEnabled")
        }
    }
    
    @Published var maxContentLength: Int {
        didSet {
            UserDefaults.standard.set(maxContentLength, forKey: "maxContentLength")
        }
    }
    
    @Published var blockedKeywords: [String] {
        didSet {
            UserDefaults.standard.set(blockedKeywords, forKey: "blockedKeywords")
        }
    }
    
    // MARK: - 히스토리 설정
    @Published var maxHistoryCount: Int {
        didSet {
            UserDefaults.standard.set(maxHistoryCount, forKey: "maxHistoryCount")
        }
    }
    
    @Published var isHistoryEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isHistoryEnabled, forKey: "isHistoryEnabled")
        }
    }
    
    // MARK: - 보안 설정
    @Published var requiresConfirmation: Bool {
        didSet {
            UserDefaults.standard.set(requiresConfirmation, forKey: "requiresConfirmation")
        }
    }
    
    @Published var isEncryptionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEncryptionEnabled, forKey: "isEncryptionEnabled")
        }
    }
    
    private init() {
        // 기본값 설정
        self.isAutoSyncEnabled = UserDefaults.standard.object(forKey: "isAutoSyncEnabled") as? Bool ?? true
        self.syncDelay = UserDefaults.standard.object(forKey: "syncDelay") as? Double ?? 0.5
        self.isContentFilteringEnabled = UserDefaults.standard.object(forKey: "isContentFilteringEnabled") as? Bool ?? true
        self.maxContentLength = UserDefaults.standard.object(forKey: "maxContentLength") as? Int ?? 10000
        self.blockedKeywords = UserDefaults.standard.object(forKey: "blockedKeywords") as? [String] ?? [
            "password", "비밀번호", "신용카드", "주민등록번호", "계좌번호"
        ]
        self.maxHistoryCount = UserDefaults.standard.object(forKey: "maxHistoryCount") as? Int ?? 50
        self.isHistoryEnabled = UserDefaults.standard.object(forKey: "isHistoryEnabled") as? Bool ?? true
        self.requiresConfirmation = UserDefaults.standard.object(forKey: "requiresConfirmation") as? Bool ?? false
        self.isEncryptionEnabled = UserDefaults.standard.object(forKey: "isEncryptionEnabled") as? Bool ?? true
    }
    
    // MARK: - 콘텐츠 필터링
    func shouldFilterContent(_ content: String) -> Bool {
        guard isContentFilteringEnabled else { return false }
        
        // 길이 체크
        if content.count > maxContentLength {
            return true
        }
        
        // 키워드 체크
        let lowercased = content.lowercased()
        for keyword in blockedKeywords {
            if lowercased.contains(keyword.lowercased()) {
                return true
            }
        }
        
        // 민감한 패턴 체크
        if containsSensitivePatterns(content) {
            return true
        }
        
        return false
    }
    
    private func containsSensitivePatterns(_ content: String) -> Bool {
        // 신용카드 번호 패턴 (16자리 숫자)
        let creditCardPattern = "\\b\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}\\b"
        
        // 이메일 패턴 중 비밀번호 재설정 등
        let sensitiveEmailPattern = "password|reset|verification"
        
        let patterns = [creditCardPattern, sensitiveEmailPattern]
        
        for pattern in patterns {
            if content.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - 설정 초기화
    func resetToDefaults() {
        isAutoSyncEnabled = true
        syncDelay = 0.5
        isContentFilteringEnabled = true
        maxContentLength = 10000
        blockedKeywords = ["password", "비밀번호", "신용카드", "주민등록번호", "계좌번호"]
        maxHistoryCount = 50
        isHistoryEnabled = true
        requiresConfirmation = false
        isEncryptionEnabled = true
    }
}