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
    
    // MARK: - Network Discovery via DNS-SD (Bonjour)
    
    /// Bonjour 서비스 정보
    struct BonjourService {
        let name: String
        let type: String
        let domain: String
        let host: String
        let port: Int
        let txtRecord: [String: Data]
        
        var connectionURL: String {
            return "ws://\(host):\(port)/ws"
        }
        
        var deviceName: String {
            if let nameData = txtRecord["name"],
               let name = String(data: nameData, encoding: .utf8) {
                return name
            }
            return name
        }
        
        var deviceId: String {
            if let idData = txtRecord["id"],
               let id = String(data: idData, encoding: .utf8) {
                return id
            }
            return "unknown-\(host)"
        }
    }
    
    /// Bonjour 서비스 브라우저
    @MainActor
    class BonjourServiceBrowser: NSObject, ObservableObject {
        @Published var discoveredServices: [BonjourService] = []
        @Published var isSearching = false
        
        private var serviceBrowser: NetServiceBrowser?
        private var resolvingServices: Set<NetService> = []
        
        private let serviceType = "_copydrop._tcp"
        private let serviceDomain = "local."
        
        override init() {
            super.init()
            setupServiceBrowser()
        }
        
        private func setupServiceBrowser() {
            serviceBrowser = NetServiceBrowser()
            serviceBrowser?.delegate = self
        }
        
        func startSearching() {
            guard !isSearching else { return }
            
            isSearching = true
            discoveredServices.removeAll()
            serviceBrowser?.searchForServices(ofType: serviceType, inDomain: serviceDomain)
            
            // 5초 후 자동 중지
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.stopSearching()
            }
        }
        
        func stopSearching() {
            guard isSearching else { return }
            
            isSearching = false
            serviceBrowser?.stop()
            
            // 해결 중인 서비스들 정리
            for service in resolvingServices {
                service.stop()
            }
            resolvingServices.removeAll()
        }
    }
    
    // MARK: - Network Discovery via Broadcast
    
    /// 브로드캐스트를 통한 서버 발견 결과
    struct DiscoveredServer {
        let ipAddress: String
        let port: UInt16
        let deviceName: String
        let deviceId: String
        let timestamp: Date
        
        var connectionURL: String {
            return "ws://\(ipAddress):\(port)/ws"
        }
    }
    
    /// 브로드캐스트 스캔을 통해 CopyDrop 서버 발견
    /// - Parameters:
    ///   - timeout: 스캔 타임아웃 (초)
    ///   - onServerFound: 서버 발견 시 호출되는 콜백
    /// - Returns: 발견된 서버 목록
    static func discoverServers(timeout: TimeInterval = 3.0, 
                               onServerFound: @escaping (DiscoveredServer) -> Void) async -> [DiscoveredServer] {
        return await withCheckedContinuation { continuation in
            var discoveredServers: [DiscoveredServer] = []
            let broadcastPort: UInt16 = 8787 // 브로드캐스트 전용 포트
            
            // UDP 소켓 생성
            let socketFD = socket(AF_INET, SOCK_DGRAM, 0)
            guard socketFD != -1 else {
                continuation.resume(returning: [])
                return
            }
            defer { close(socketFD) }
            
            // 브로드캐스트 활성화
            var broadcast = 1
            setsockopt(socketFD, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int>.size))
            
            // 타임아웃 설정
            var timeout = timeval(tv_sec: Int(timeout), tv_usec: 0)
            setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            
            // 브로드캐스트 메시지 생성
            let discoveryMessage = createDiscoveryMessage()
            
            // 브로드캐스트 주소들
            let broadcastAddresses = getBroadcastAddresses()
            
            // 각 브로드캐스트 주소로 메시지 전송
            for address in broadcastAddresses {
                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = broadcastPort.bigEndian
                addr.sin_addr.s_addr = inet_addr(address)
                
                let messageData = discoveryMessage.data(using: .utf8) ?? Data()
                messageData.withUnsafeBytes { bytes in
                    withUnsafePointer(to: &addr) {
                        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                            sendto(socketFD, bytes.baseAddress, messageData.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                        }
                    }
                }
            }
            
            // 응답 수신
            DispatchQueue.global(qos: .userInitiated).async {
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
                defer { buffer.deallocate() }
                
                let startTime = Date()
                
                while Date().timeIntervalSince(startTime) < TimeInterval(timeout.tv_sec) {
                    var senderAddr = sockaddr_in()
                    var senderAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                    
                    let receivedBytes = withUnsafeMutablePointer(to: &senderAddr) {
                        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                            recvfrom(socketFD, buffer, 1024, 0, $0, &senderAddrLen)
                        }
                    }
                    
                    if receivedBytes > 0 {
                        let responseData = Data(bytes: buffer, count: receivedBytes)
                        if let responseString = String(data: responseData, encoding: .utf8),
                           let server = parseDiscoveryResponse(responseString, from: String(cString: inet_ntoa(senderAddr.sin_addr))) {
                            
                            // 중복 제거
                            if !discoveredServers.contains(where: { $0.deviceId == server.deviceId }) {
                                discoveredServers.append(server)
                                DispatchQueue.main.async {
                                    onServerFound(server)
                                }
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    continuation.resume(returning: discoveredServers)
                }
            }
        }
    }
    
    /// 브로드캐스트 주소 목록 생성
    private static func getBroadcastAddresses() -> [String] {
        var addresses: [String] = []
        
        // 현재 IP 기반 브로드캐스트 주소 계산
        if let localIP = getLocalIPAddress() {
            if let broadcastAddr = calculateBroadcastAddress(for: localIP) {
                addresses.append(broadcastAddr)
            }
        }
        
        // 일반적인 네트워크 브로드캐스트 주소들
        addresses.append(contentsOf: [
            "192.168.1.255",   // 192.168.1.x 네트워크
            "192.168.0.255",   // 192.168.0.x 네트워크
            "192.168.2.255",   // 192.168.2.x 네트워크
            "10.0.0.255",      // 10.0.0.x 네트워크
            "172.16.255.255",  // 172.16.x.x 네트워크
            "255.255.255.255"  // 전체 브로드캐스트
        ])
        
        return Array(Set(addresses)) // 중복 제거
    }
    
    /// IP 주소로부터 브로드캐스트 주소 계산
    private static func calculateBroadcastAddress(for ipAddress: String) -> String? {
        let components = ipAddress.split(separator: ".").compactMap { Int($0) }
        guard components.count == 4 else { return nil }
        
        // 일반적인 /24 서브넷 가정 (255.255.255.0)
        return "\(components[0]).\(components[1]).\(components[2]).255"
    }
    
    /// 디스커버리 메시지 생성
    private static func createDiscoveryMessage() -> String {
        let deviceInfo = DeviceInfo.current()
        
        let message: [String: Any] = [
            "type": "COPYDROP_DISCOVERY_REQUEST",
            "version": "1.0",
            "deviceId": deviceInfo.id,
            "deviceName": deviceInfo.name,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: message),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "COPYDROP_DISCOVERY_REQUEST"
    }
    
    /// 디스커버리 응답 파싱
    private static func parseDiscoveryResponse(_ response: String, from ipAddress: String) -> DiscoveredServer? {
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        guard let type = json["type"] as? String,
              type == "COPYDROP_DISCOVERY_RESPONSE",
              let deviceName = json["deviceName"] as? String,
              let deviceId = json["deviceId"] as? String,
              let port = json["port"] as? Int else {
            return nil
        }
        
        return DiscoveredServer(
            ipAddress: ipAddress,
            port: UInt16(port),
            deviceName: deviceName,
            deviceId: deviceId,
            timestamp: Date()
        )
    }
    
    /// 스마트 IP 스캔 (현재 IP 주변 ±5 + 일반적 주소)
    /// 총 ~50개 위치만 체크 (기존 350개에서 대폭 단축!)
    static func smartIPScan(port: UInt16 = 8080, 
                           timeout: TimeInterval = 0.5,
                           onServerFound: @escaping (String) -> Void) async -> [String] {
        return await withCheckedContinuation { continuation in
            var foundServers: [String] = []
            let group = DispatchGroup()
            let queue = DispatchQueue.global(qos: .userInitiated)
            
            // 스캔할 IP 주소 목록 생성
            let ipsToScan = generateSmartScanIPs()
            
            for ip in ipsToScan {
                group.enter()
                queue.async {
                    if isServerReachable(ip: ip, port: port, timeout: timeout) {
                        let serverURL = "ws://\(ip):\(port)/ws"
                        DispatchQueue.main.async {
                            foundServers.append(serverURL)
                            onServerFound(serverURL)
                        }
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                continuation.resume(returning: foundServers)
            }
        }
    }
    
    /// 스마트 스캔용 IP 목록 생성
    private static func generateSmartScanIPs() -> [String] {
        var ips: [String] = []
        
        // 현재 IP 주변 ±5개
        if let localIP = getLocalIPAddress() {
            let components = localIP.split(separator: ".").compactMap { Int($0) }
            if components.count == 4 {
                let baseIP = "\(components[0]).\(components[1]).\(components[2])"
                let currentLastOctet = components[3]
                
                // 현재 IP 주변 ±5개 (총 11개)
                for offset in -5...5 {
                    let newLastOctet = currentLastOctet + offset
                    if newLastOctet >= 1 && newLastOctet <= 254 {
                        ips.append("\(baseIP).\(newLastOctet)")
                    }
                }
            }
        }
        
        // 일반적인 라우터/서버 주소들 (약 39개)
        let commonIPs = [
            // 라우터 주소들
            "192.168.1.1", "192.168.0.1", "192.168.2.1", "10.0.0.1", "172.16.0.1",
            "192.168.1.254", "192.168.0.254", "192.168.2.254",
            
            // 일반적인 서버 주소들
            "192.168.1.10", "192.168.1.100", "192.168.1.200",
            "192.168.0.10", "192.168.0.100", "192.168.0.200",
            "192.168.2.10", "192.168.2.100", "192.168.2.200",
            "10.0.0.10", "10.0.0.100", "10.0.0.200",
            "172.16.0.10", "172.16.0.100", "172.16.0.200",
            
            // 기타 일반적인 주소들
            "192.168.1.50", "192.168.1.101", "192.168.1.102", "192.168.1.103",
            "192.168.0.50", "192.168.0.101", "192.168.0.102", "192.168.0.103",
            "192.168.2.50", "192.168.2.101", "192.168.2.102", "192.168.2.103",
            "10.0.0.50", "10.0.0.101", "10.0.0.102", "10.0.0.103",
            "172.16.0.50", "172.16.0.101", "172.16.0.102", "172.16.0.103"
        ]
        
        ips.append(contentsOf: commonIPs)
        
        // 중복 제거 후 최대 50개로 제한
        let uniqueIPs = Array(Set(ips))
        return Array(uniqueIPs.prefix(50))
    }
    
    /// 서버 연결 가능 여부 확인
    private static func isServerReachable(ip: String, port: UInt16, timeout: TimeInterval) -> Bool {
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD != -1 else { return false }
        defer { close(socketFD) }
        
        // 논블로킹 모드 설정
        let flags = fcntl(socketFD, F_GETFL, 0)
        _ = fcntl(socketFD, F_SETFL, flags | O_NONBLOCK)
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr(ip)
        
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        if result == 0 {
            return true // 즉시 연결됨
        }
        
        if errno == EINPROGRESS {
            // select를 사용해서 타임아웃 내에 연결 완료 확인
            var readfds = fd_set()
            var writefds = fd_set()
            var errorfds = fd_set()
            
            let nfds = socketFD + 1
            
            // fd_set 초기화 및 설정
            let connectResult = withUnsafeMutablePointer(to: &readfds) { readPtr in
                withUnsafeMutablePointer(to: &writefds) { writePtr in
                    withUnsafeMutablePointer(to: &errorfds) { errorPtr in
                        fdZero(readPtr)
                        fdZero(writePtr)
                        fdZero(errorPtr)
                        fdSet(socketFD, writePtr)
                        fdSet(socketFD, errorPtr)
                        
                        var timeoutVal = timeval(
                            tv_sec: Int(timeout),
                            tv_usec: __darwin_suseconds_t((timeout - Double(Int(timeout))) * 1_000_000)
                        )
                        
                        let selectResult = select(nfds, readPtr, writePtr, errorPtr, &timeoutVal)
                        
                        if selectResult > 0 {
                            // 연결 상태 확인
                            var error: Int32 = 0
                            var errorSize = socklen_t(MemoryLayout<Int32>.size)
                            let optResult = getsockopt(socketFD, SOL_SOCKET, SO_ERROR, &error, &errorSize)
                            
                            return optResult == 0 && error == 0
                        }
                        return false
                    }
                }
            }
            return connectResult
        }
        
        return false
    }
    
    // fd_set 헬퍼 함수들
    private static func fdZero(_ set: UnsafeMutablePointer<fd_set>) {
        set.pointee = fd_set()
    }
    
    private static func fdSet(_ fd: Int32, _ set: UnsafeMutablePointer<fd_set>) {
        let intOffset = Int(fd / 32)
        let bitOffset = fd % 32
        let mask = 1 << bitOffset
        
        withUnsafeMutableBytes(of: &set.pointee.fds_bits) { buffer in
            let intArray = buffer.bindMemory(to: Int32.self)
            intArray[intOffset] |= Int32(mask)
        }
    }
}

// MARK: - NetServiceBrowser Delegate
extension NetworkUtils.BonjourServiceBrowser: NetServiceBrowserDelegate {
    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        Task { @MainActor in
            // 서비스 해결 시작
            service.delegate = self
            resolvingServices.insert(service)
            service.resolve(withTimeout: 5.0)
        }
    }
    
    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        Task { @MainActor in
            // 서비스 제거
            discoveredServices.removeAll { bonjourService in
                bonjourService.name == service.name && 
                bonjourService.type == service.type &&
                bonjourService.domain == service.domain
            }
            resolvingServices.remove(service)
        }
    }
    
    nonisolated func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        Task { @MainActor in
            isSearching = false
        }
    }
    
    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        Task { @MainActor in
            isSearching = false
            print("Bonjour 검색 오류: \(errorDict)")
        }
    }
}

// MARK: - NetService Delegate
extension NetworkUtils.BonjourServiceBrowser: NetServiceDelegate {
    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        Task { @MainActor in
            guard let hostName = sender.hostName,
                  sender.port > 0 else {
                resolvingServices.remove(sender)
                return
            }
            
            // TXT 레코드 파싱
            var txtRecord: [String: Data] = [:]
            if let txtData = sender.txtRecordData() {
                txtRecord = NetService.dictionary(fromTXTRecord: txtData)
            }
            
            let bonjourService = NetworkUtils.BonjourService(
                name: sender.name,
                type: sender.type,
                domain: sender.domain,
                host: hostName,
                port: sender.port,
                txtRecord: txtRecord
            )
            
            // 중복 제거하고 추가
            if !discoveredServices.contains(where: { $0.name == bonjourService.name && $0.host == bonjourService.host }) {
                discoveredServices.append(bonjourService)
            }
            
            resolvingServices.remove(sender)
        }
    }
    
    nonisolated func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        Task { @MainActor in
            resolvingServices.remove(sender)
            print("Bonjour 서비스 해결 오류: \(errorDict)")
        }
    }
}

// MARK: - C Imports
import Darwin.C
