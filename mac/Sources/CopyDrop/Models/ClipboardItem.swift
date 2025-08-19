import Foundation
import AppKit

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let content: String
    let timestamp: Date
    let source: Source
    let type: ContentType
    let imageData: Data?
    
    init(content: String, timestamp: Date, source: Source, type: ContentType = .text, imageData: Data? = nil) {
        self.id = UUID()
        self.content = content
        self.timestamp = timestamp
        self.source = source
        self.type = type
        self.imageData = imageData
    }
    
    var preview: String {
        switch type {
        case .image:
            return formatImageSize()
        case .text:
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
    }
    
    private func formatImageSize() -> String {
        guard let data = imageData else { return "Unknown" }
        let sizeBytes = data.count
        let sizeKB = sizeBytes / 1024
        let sizeMB = Double(sizeBytes) / (1024.0 * 1024.0)
        
        // 10MB 이상이면 WiFi 권장 경고 추가
        let isLargeFile = sizeBytes > 10 * 1024 * 1024
        
        let sizeText: String
        if sizeKB < 1024 {
            sizeText = "\(sizeKB) KB"
        } else {
            sizeText = String(format: "%.1f MB", sizeMB)
        }
        
        if isLargeFile {
            return "\(sizeText) (큰 용량, WiFi 권장)"
        } else {
            return sizeText
        }
    }
    
    var nsImage: NSImage? {
        guard type == .image, let data = imageData else { return nil }
        return NSImage(data: data)
    }
    
    enum ContentType: String, Codable {
        case text = "text"
        case image = "image"
    }
    
    enum Source: String, Codable {
        case local = "local"
        case remote = "remote"
    }
}