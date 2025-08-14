//
//  Foundation+Extensions.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import Foundation

// MARK: - Data Extensions
extension Data {
    /// 데이터를 16진수 문자열로 변환
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
    
    /// 16진수 문자열에서 Data 생성
    init?(hexString: String) {
        let length = hexString.count / 2
        var data = Data(capacity: length)
        
        for i in 0..<length {
            let start = hexString.index(hexString.startIndex, offsetBy: i * 2)
            let end = hexString.index(start, offsetBy: 2)
            let hexByte = String(hexString[start..<end])
            
            guard let byte = UInt8(hexByte, radix: 16) else {
                return nil
            }
            
            data.append(byte)
        }
        
        self = data
    }
}

// MARK: - String Extensions
extension String {
    /// 문자열에서 민감한 정보 마스킹
    var masked: String {
        let length = self.count
        if length <= 4 {
            return String(repeating: "*", count: length)
        } else {
            let prefix = String(self.prefix(2))
            let suffix = String(self.suffix(2))
            let middle = String(repeating: "*", count: length - 4)
            return prefix + middle + suffix
        }
    }
    
    /// 안전한 로깅을 위한 문자열 (민감한 키워드 자동 마스킹)
    var safeForLogging: String {
        var result = self
        
        for keyword in AppConstants.SensitivePatterns.passwordKeywords {
            if self.lowercased().contains(keyword.lowercased()) {
                result = self.masked
                break
            }
        }
        
        return result
    }
    
    /// 클립보드 내용 미리보기 (50자 제한)
    var clipboardPreview: String {
        let maxLength = 50
        if self.count <= maxLength {
            return self
        } else {
            return String(self.prefix(maxLength)) + "..."
        }
    }
}

// MARK: - Date Extensions
extension Date {
    /// 상대적 시간 표시 (예: "2분 전")
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// 파일명에 사용 가능한 날짜 문자열
    var fileNameString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: self)
    }
}

// MARK: - Bundle Extensions
extension Bundle {
    /// 앱 버전 정보
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    /// 빌드 번호
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    /// 앱 이름
    var appName: String {
        return infoDictionary?["CFBundleDisplayName"] as? String ?? 
               infoDictionary?["CFBundleName"] as? String ?? "CopyDrop"
    }
    
    /// 전체 버전 문자열
    var fullVersionString: String {
        return "\(appName) \(appVersion) (\(buildNumber))"
    }
}
