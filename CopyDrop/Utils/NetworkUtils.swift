//
//  NetworkUtils.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import Foundation
import Network

struct NetworkUtils {
    
    /// 로컬 IP 주소 가져오기
    static func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee else { continue }
                
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    
                    // WiFi 또는 Ethernet 인터페이스 우선
                    if name == "en0" || name == "en1" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count),
                                   nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                        
                        // en0 (WiFi)를 찾으면 즉시 반환
                        if name == "en0" {
                            break
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return address
    }
    
    /// 네트워크 연결 상태 확인
    static func isNetworkAvailable() -> Bool {
        let monitor = NWPathMonitor()
        var isConnected = false
        let semaphore = DispatchSemaphore(value: 0)
        
        monitor.pathUpdateHandler = { path in
            isConnected = path.status == .satisfied
            semaphore.signal()
        }
        
        let queue = DispatchQueue(label: "network-monitor")
        monitor.start(queue: queue)
        
        _ = semaphore.wait(timeout: .now() + 1.0)
        monitor.cancel()
        
        return isConnected
    }
    
    /// 포트 사용 가능 여부 확인
    static func isPortAvailable(_ port: UInt16) -> Bool {
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD != -1 else { return false }
        defer { close(socketFD) }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        return result == 0
    }
    
    /// 사용 가능한 포트 찾기
    static func findAvailablePort(startingFrom port: UInt16 = AppConstants.Network.defaultPort) -> UInt16? {
        for testPort in port...(port + 100) {
            if isPortAvailable(testPort) {
                return testPort
            }
        }
        return nil
    }
    
    /// URL 유효성 검사
    static func isValidWebSocketURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme else {
            return false
        }
        
        return scheme == "ws" || scheme == "wss"
    }
    
    /// QR 코드용 연결 정보 생성
    static func generateConnectionInfo(port: UInt16, key: String) -> [String: Any] {
        let deviceInfo = DeviceInfo.current()
        
        return [
            "deviceId": deviceInfo.id,
            "deviceName": deviceInfo.name,
            "deviceType": deviceInfo.type,
            "ipAddress": getLocalIPAddress() ?? "unknown",
            "port": port,
            "encryptionKey": key,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ]
    }
}

// MARK: - C Imports
import Darwin.C
