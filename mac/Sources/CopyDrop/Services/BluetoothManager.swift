import Foundation
import CoreBluetooth
import Network
import Crypto
import Compression

extension String {
    func matches(regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}

struct ConnectedDevice {
    let name: String
    let address: String
    let lastSeen: Date
}

struct ClipboardMessage: Codable {
    let content: String
    let timestamp: String
    let deviceId: String
    let messageId: String
    let contentSize: Int // 바이트 단위 크기
    
    init(content: String, deviceId: String) {
        self.content = content
        
        // ISO8601 문자열로 timestamp 생성
        let formatter = ISO8601DateFormatter()
        self.timestamp = formatter.string(from: Date())
        
        self.deviceId = deviceId
        self.messageId = UUID().uuidString
        self.contentSize = content.data(using: .utf8)?.count ?? 0
    }
}

class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager()
    
    @Published var isServerRunning = false
    @Published var isConnected = false
    @Published var connectedDevices: [ConnectedDevice] = []
    
    // 분할된 데이터 조합을 위한 버퍼
    private var dataBuffer = Data()
    private var lastDataTime = Date()
    
    // 클립보드 허브 참조
    weak var pinAuthManager: PinAuthManager?
    
    // Core Bluetooth 설정
    private let serviceUUID = CBUUID(string: "00001101-0000-1000-8000-00805F9B34FB")
    private let characteristicUUID = CBUUID(string: "00002101-0000-1000-8000-00805F9B34FB")
    private let serviceName = "CopyDropService"
    
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var service: CBMutableService?
    private var characteristic: CBMutableCharacteristic?
    
    private let deviceId: String
    
    // 하이브리드 통신을 위한 임계값
    private static let BLE_SIZE_THRESHOLD = 10 * 1024 * 1024 // 10MB로 변경 (고속 전송 최적화 적용)
    
    // gzip 압축/해제 함수들 (Android와 호환성을 위해 gzip 사용)
    private func compressData(_ data: Data) -> Data? {
        return data.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
            defer { buffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(
                buffer, data.count,
                bytes.bindMemory(to: UInt8.self).baseAddress!, data.count,
                nil, COMPRESSION_ZLIB
            )
            
            guard compressedSize > 0 else { return nil }
            return Data(bytes: buffer, count: compressedSize)
        }
    }
    
    private func decompressData(_ compressedData: Data) -> Data? {
        // Android GZIP 호환성을 위해 먼저 ZLIB 시도
        if let zlibResult = tryDecompressZlib(compressedData) {
            return zlibResult
        }
        
        // 기존 LZFSE 방식도 유지 (Mac끼리 통신용)
        return tryDecompressLZFSE(compressedData)
    }
    
    private func tryDecompressZlib(_ compressedData: Data) -> Data? {
        // GZIP 헤더가 있는 경우 LZFSE로 시도 (Apple Compression Framework의 GZIP 지원)
        if compressedData.count >= 3 && compressedData[0] == 0x1f && compressedData[1] == 0x8b && compressedData[2] == 0x08 {
            print("🗜️ GZIP 데이터를 Apple Compression Framework로 압축 해제 시도")
            
            // Apple Compression Framework를 사용한 GZIP 압축 해제
            return compressedData.withUnsafeBytes { bytes in
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: compressedData.count * 8) // 더 큰 버퍼
                defer { buffer.deallocate() }
                
                // GZIP = ZLIB with different header/footer
                let decompressedSize = compression_decode_buffer(
                    buffer, compressedData.count * 8,
                    bytes.bindMemory(to: UInt8.self).baseAddress!, compressedData.count,
                    nil, COMPRESSION_LZFSE // LZFSE로 시도
                )
                
                if decompressedSize > 0 {
                    print("✅ GZIP->LZFSE 압축 해제 성공: \(compressedData.count) -> \(decompressedSize) bytes")
                    return Data(bytes: buffer, count: decompressedSize)
                }
                
                // LZFSE 실패 시 ZLIB 시도
                let zlibSize = compression_decode_buffer(
                    buffer, compressedData.count * 8,
                    bytes.bindMemory(to: UInt8.self).baseAddress!, compressedData.count,
                    nil, COMPRESSION_ZLIB
                )
                
                if zlibSize > 0 {
                    print("✅ GZIP->ZLIB 압축 해제 성공: \(compressedData.count) -> \(zlibSize) bytes")
                    return Data(bytes: buffer, count: zlibSize)
                }
                
                print("❌ GZIP 압축 해제 실패 - 모든 방법 시도함")
                return nil
            }
        }
        
        // 일반 ZLIB 압축 해제
        return compressedData.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: compressedData.count * 4)
            defer { buffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                buffer, compressedData.count * 4,
                bytes.bindMemory(to: UInt8.self).baseAddress!, compressedData.count,
                nil, COMPRESSION_ZLIB
            )
            
            guard decompressedSize > 0 else { return nil }
            return Data(bytes: buffer, count: decompressedSize)
        }
    }
    
    private func tryDecompressLZFSE(_ compressedData: Data) -> Data? {
        return compressedData.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: compressedData.count * 4)
            defer { buffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                buffer, compressedData.count * 4,
                bytes.bindMemory(to: UInt8.self).baseAddress!, compressedData.count,
                nil, COMPRESSION_LZFSE
            )
            
            guard decompressedSize > 0 else { return nil }
            return Data(bytes: buffer, count: decompressedSize)
        }
    }
    
    
    private override init() {
        self.deviceId = "mac-" + (Host.current().localizedName ?? "Unknown")
        super.init()
    }
    
    var connectionStatusText: String {
        if isConnected {
            return "연결됨"
        } else if isServerRunning {
            return "대기 중"
        } else {
            return "중지됨"
        }
    }
    
    var serverStatusText: String {
        if isServerRunning {
            return "Android 기기 연결 대기 중..."
        } else {
            return "서버를 시작하여 Android 기기와 연결하세요"
        }
    }
    
    func start() {
        print("Core Bluetooth Manager 초기화")
        setupCentralManager()
        setupPeripheralManager()
    }
    
    func stop() {
        stopServer()
        print("Core Bluetooth Manager 종료")
    }
    
    private func setupCentralManager() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    private func setupPeripheralManager() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func startServer() {
        guard !isServerRunning else { return }
        
        print("Core Bluetooth 서버 시작 중...")
        
        guard let peripheralManager = peripheralManager,
              peripheralManager.state == .poweredOn else {
            print("Peripheral Manager가 준비되지 않음")
            return
        }
        
        setupService()
        
        DispatchQueue.main.async {
            self.isServerRunning = true
        }
    }
    
    func stopServer() {
        guard isServerRunning else { return }
        
        print("Core Bluetooth 서버 중지 중...")
        
        peripheralManager?.stopAdvertising()
        if let service = service {
            peripheralManager?.remove(service)
        }
        
        DispatchQueue.main.async {
            self.isServerRunning = false
            self.isConnected = false
            self.connectedDevices.removeAll()
        }
        
        print("Core Bluetooth 서버 중지됨")
    }
    
    private func setupService() {
        characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [CBCharacteristicProperties.read, CBCharacteristicProperties.write, CBCharacteristicProperties.notify],
            value: nil,
            permissions: [CBAttributePermissions.readable, CBAttributePermissions.writeable]
        )
        
        service = CBMutableService(type: serviceUUID, primary: true)
        service?.characteristics = [characteristic!]
        
        peripheralManager?.add(service!)
        
        // 광고 시작
        peripheralManager?.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: serviceName
        ])
        
        print("BLE 서비스 등록 및 광고 시작")
    }
    
    // MARK: - 하이브리드 데이터 전송
    func sendToConnectedDevices(content: String) {
        guard isConnected, !connectedDevices.isEmpty else {
            print("연결된 기기가 없습니다")
            return
        }
        
        let _ = content.count / 1024 // 크기 확인용
        
        // 크기 체크
        if content.count > Self.BLE_SIZE_THRESHOLD {
            let sizeMB = Double(content.count) / (1024.0 * 1024.0)
            print("🌐 데이터가 너무 큼 (\(String(format: "%.1f", sizeMB))MB > 10MB)")
            print("⚠️ 파일이 너무 큽니다. Wi-Fi 연결 시 더 빠르게 전송됩니다.")
            return
        }
        
        // 텍스트로 처리
        sendTextData(content)
    }
    
    // 텍스트 전송
    private func sendTextData(_ content: String) {
        print("📝 텍스트 전송: \(content.prefix(50))... ")
        
        var finalContent = content
        
        // 인증 관련 메시지는 암호화하지 않음 (세션이 아직 없으므로)
        let isAuthMessage = content.contains("\"type\":\"auth_response\"") || 
                           content.contains("\"type\":\"sync_request\"")
        
        if isAuthMessage {
            print("🔐 인증/동기화 메시지 - 암호화 없이 전송")
        } else {
            // 일반 클립보드 데이터는 세션이 활성화된 경우 암호화 시도
            if let sessionToken = PinAuthManager.shared.getActiveSessionToken() {
                if let encryptedContent = CryptoManager.shared.encrypt(content, sessionToken: sessionToken) {
                    print("🔐 Mac에서 데이터 암호화 성공")
                    finalContent = encryptedContent
                } else {
                    print("⚠️ Mac 암호화 실패, 원본 데이터 전송")
                }
            } else {
                print("⚠️ 활성 세션 없음, 원본 데이터 전송")
            }
        }
        
        let messageData = finalContent.data(using: .utf8) ?? Data()
        print("📤 최종 전송 데이터 크기: \(messageData.count) bytes")
        
        if let characteristic = characteristic {
            let success = peripheralManager?.updateValue(messageData, for: characteristic, onSubscribedCentrals: nil) ?? false
            if success {
                print("✅ BLE 텍스트 전송 성공")
            } else {
                print("❌ BLE 텍스트 전송 실패")
            }
        } else {
            print("❌ BLE characteristic가 설정되지 않음")
        }
    }
    
    
    private func sendUncompressedData(_ data: Data, content: String) {
        if let characteristic = characteristic {
            let success = peripheralManager?.updateValue(data, for: characteristic, onSubscribedCentrals: nil) ?? false
            if success {
                print("✅ BLE 원본 메시지 전송 성공: \(content.prefix(30))...")
            } else {
                print("❌ BLE 원본 메시지 전송 실패")
            }
        }
    }
    
    // MARK: - 하이브리드 데이터 수신 처리
    private func handleReceivedData(_ data: Data) {
        print("🔍🔍🔍 handleReceivedData 호출됨 - \(data.count) bytes 🔍🔍🔍")
        
        // 텍스트로 변환
        let textContent = String(data: data, encoding: .utf8) ?? "Invalid UTF-8"
        print("📥📥📥 Android에서 데이터 수신: \(textContent.prefix(100))... 📥📥📥")
        
        // 빈 문자열이 아닌 경우 처리
        if !textContent.isEmpty && textContent != "Invalid UTF-8" {
            
            // 모든 데이터를 텍스트로 처리
            print("📝📝📝 텍스트 데이터 수신: \(textContent.prefix(50))... 📝📝📝")
            processTextData(textContent)
        } else {
            print("❌❌❌ 유효하지 않은 데이터 ❌❌❌")
        }
    }
    
    // 텍스트 데이터 처리
    private func processTextData(_ content: String) {
        print("✅✅✅ 텍스트 수신 완료! 메시지 타입 확인 중... ✅✅✅")
        
        var finalContent = content
        
        // 암호화된 데이터인지 확인 및 복호화 시도
        if CryptoManager.shared.isEncrypted(content) {
            print("🔐 암호화된 데이터 감지, 복호화 시도 중...")
            
            // 활성 세션으로 복호화 시도
            if let sessionToken = PinAuthManager.shared.getActiveSessionToken() {
                if let decryptedContent = CryptoManager.shared.decrypt(content, sessionToken: sessionToken) {
                    print("🔓 Mac에서 복호화 성공")
                    finalContent = decryptedContent
                } else {
                    print("⚠️ 복호화 실패, 원본 데이터로 처리")
                }
            } else {
                print("⚠️ 활성 세션 없음, 복호화 불가")
            }
        }
        
        // JSON 메시지인지 확인
        if finalContent.hasPrefix("{") && finalContent.hasSuffix("}") {
            print("📱 JSON 메시지 감지 - Pin 인증 요청 처리 시도")
            
            // Pin 인증 요청 처리 시도
            if let authResponse = PinAuthManager.shared.processAuthRequest(finalContent) {
                print("🔐 Pin 인증 응답 생성: \(authResponse)")
                sendTextData(authResponse)
                return
            }
            
            // 재연결 요청 처리 시도
            if let reconnectResponse = PinAuthManager.shared.processReconnectRequest(finalContent) {
                print("🔄 재연결 응답 생성: \(reconnectResponse)")
                sendTextData(reconnectResponse)
                return
            }
            
            // 다른 JSON 메시지 타입 처리 가능
            print("⚠️ 알 수 없는 JSON 메시지: \(finalContent.prefix(100))")
        }
        
        // 일반 텍스트로 처리
        DispatchQueue.main.async {
            print("📋📋📋 ClipboardManager로 텍스트 전달 중... 📋📋📋")
            ClipboardManager.shared.receiveFromRemoteDevice(finalContent)
            print("📋📋📋 ClipboardManager 텍스트 전달 완료! 📋📋📋")
        }
    }
    
    
    // processCompleteJson 함수는 더 이상 사용하지 않음 (순수 텍스트 통신으로 변경)
    
    // MARK: - 동기화 요청
    
    /**
     * Android에게 클립보드 동기화 요청
     */
    func requestSyncFromAndroid() {
        guard isConnected, !connectedDevices.isEmpty else {
            print("⚠️ 연결된 Android 기기가 없습니다")
            return
        }
        
        print("🔄 Android에게 클립보드 동기화 요청")
        
        let syncRequest = [
            "type": "sync_request",
            "deviceId": deviceId,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "messageId": UUID().uuidString
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: syncRequest, options: [])
            
            if let characteristic = characteristic {
                let success = peripheralManager?.updateValue(data, for: characteristic, onSubscribedCentrals: nil) ?? false
                if success {
                    print("✅ 동기화 요청 전송 성공")
                } else {
                    print("❌ 동기화 요청 전송 실패")
                }
            }
        } catch {
            print("❌ 동기화 요청 인코딩 실패: \(error)")
        }
    }
    
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Central Manager: 블루투스 사용 가능")
        case .poweredOff:
            print("Central Manager: 블루투스가 꺼져있습니다")
        case .resetting:
            print("Central Manager: 블루투스 재시작 중")
        case .unauthorized:
            print("Central Manager: 블루투스 권한 없음")
        case .unsupported:
            print("Central Manager: 블루투스 지원 안됨")
        case .unknown:
            print("Central Manager: 블루투스 상태 불명")
        @unknown default:
            print("Central Manager: 알 수 없는 상태")
        }
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BluetoothManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("Peripheral Manager: 블루투스 사용 가능")
        case .poweredOff:
            print("Peripheral Manager: 블루투스가 꺼져있습니다")
        case .resetting:
            print("Peripheral Manager: 블루투스 재시작 중")
        case .unauthorized:
            print("Peripheral Manager: 블루투스 권한 없음")
        case .unsupported:
            print("Peripheral Manager: 블루투스 지원 안됨")
        case .unknown:
            print("Peripheral Manager: 블루투스 상태 불명")
        @unknown default:
            print("Peripheral Manager: 알 수 없는 상태")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("서비스 추가 실패: \(error.localizedDescription)")
        } else {
            print("BLE 서비스 추가 성공: \(service.uuid)")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("광고 시작 실패: \(error.localizedDescription)")
        } else {
            print("BLE 광고 시작 성공")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("🔔🔔🔔 BLE Write 요청 수신: \(requests.count)개 🔔🔔🔔")
        
        for request in requests {
            if let value = request.value {
                let jsonString = String(data: value, encoding: .utf8) ?? "Invalid UTF-8"
                print("📥📥📥 Android에서 수신: \(value.count) bytes 📥📥📥")
                print("📥 데이터: \(jsonString.prefix(200))...")
                print("📥 Raw 데이터: \(value.map { String(format: "%02x", $0) }.joined(separator: " "))")
                
                handleReceivedData(value)
                peripheral.respond(to: request, withResult: .success)
                print("✅✅✅ Write 요청 응답 완료 ✅✅✅")
            } else {
                print("❌❌❌ Write 요청에 데이터 없음 ❌❌❌")
                peripheral.respond(to: request, withResult: .invalidAttributeValueLength)
            }
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Android 기기 연결됨: \(central.identifier)")
        
        // 실제 기기 정보로 연결 상태 업데이트
        let device = ConnectedDevice(
            name: "Android Device",
            address: central.identifier.uuidString,
            lastSeen: Date()
        )
        
        DispatchQueue.main.async {
            self.connectedDevices.append(device)
            self.isConnected = true
            print("✅ Android 기기와 연결 완료")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("Android 기기 연결 해제: \(central.identifier)")
        
        DispatchQueue.main.async {
            self.connectedDevices.removeAll { $0.address == central.identifier.uuidString }
            self.isConnected = self.connectedDevices.count > 0
            print("❌ Android 기기 연결 해제됨")
        }
    }
}