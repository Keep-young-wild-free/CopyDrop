import Foundation

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let content: String
    let timestamp: Date
    let source: Source
    
    init(content: String, timestamp: Date, source: Source) {
        self.id = UUID()
        self.content = content
        self.timestamp = timestamp
        self.source = source
    }
    
    var preview: String {
        let cleaned = content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.count > 100 {
            return String(cleaned.prefix(100)) + "..."
        }
        return cleaned
    }
    
    enum Source: String, Codable {
        case local = "local"
        case remote = "remote"
    }
}