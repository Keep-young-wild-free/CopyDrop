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
    let contentType: String // "text", "image", "file"
    let contentSize: Int // 바이트 단위 크기
    
    init(content: String, deviceId: String, contentType: String = "text") {
        self.content = content
        
        // ISO8601 문자열로 timestamp 생성
        let formatter = ISO8601DateFormatter()
        self.timestamp = formatter.string(from: Date())
        
        self.deviceId = deviceId
        self.messageId = UUID().uuidString
        self.contentType = contentType
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
    
    // gzip 압축/해제 함수들
    private func compressData(_ data: Data) -> Data? {
        return data.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
            defer { buffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(
                buffer, data.count,
                bytes.bindMemory(to: UInt8.self).baseAddress!, data.count,
                nil, COMPRESSION_LZFSE
            )
            
            guard compressedSize > 0 else { return nil }
            return Data(bytes: buffer, count: compressedSize)
        }
    }
    
    private func decompressData(_ compressedData: Data) -> Data? {
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
    
    // 콘텐츠 타입 감지
    private func detectContentType(_ content: String) -> String {
        if content.matches(regex: "^data:image/[a-zA-Z]*;base64,") {
            return "image"
        } else if content.hasPrefix("file://") || content.hasPrefix("/") {
            return "file"
        } else {
            return "text"
        }
    }
    
    // 전송 방식 결정
    private func shouldUseWiFi(_ content: String, contentType: String) -> Bool {
        let sizeBytes = content.data(using: .utf8)?.count ?? 0
        return sizeBytes > Self.BLE_SIZE_THRESHOLD
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
    
    // MARK: - 데이터 전송
    func sendToConnectedDevices(content: String) {
        guard isConnected, !connectedDevices.isEmpty else {
            print("연결된 기기가 없습니다")
            return
        }
        
        let contentType = detectContentType(content)
        let useWiFi = shouldUseWiFi(content, contentType: contentType)
        
        if useWiFi {
            let sizeMB = Double(content.count) / (1024.0 * 1024.0)
            print("🌐 큰 데이터 감지 (\(contentType), \(String(format: "%.1f", sizeMB))MB), Wi-Fi 전송 권장")
            print("⚠️ 파일이 너무 큽니다. Wi-Fi 연결 시 더 빠르게 전송됩니다.")
            return
        }
        
        let message = ClipboardMessage(content: content, deviceId: deviceId, contentType: contentType)
        
        do {
            let originalData = try JSONEncoder().encode(message)
            
            // 압축 적용
            guard let compressedData = compressData(originalData) else {
                print("❌ 데이터 압축 실패, 원본 전송")
                sendUncompressedData(originalData, content: content)
                return
            }
            
            let compressionRatio = (1 - Double(compressedData.count) / Double(originalData.count)) * 100
            print("📤 메시지 전송 시도: \(content.prefix(30))...")
            print("📤 원본 크기: \(originalData.count) bytes")
            print("📤 압축 후: \(compressedData.count) bytes (\(String(format: "%.1f", compressionRatio))% 압축)")
            
            // Core Bluetooth를 통한 압축된 데이터 전송
            if let characteristic = characteristic {
                let success = peripheralManager?.updateValue(compressedData, for: characteristic, onSubscribedCentrals: nil) ?? false
                if success {
                    print("✅ BLE 압축 메시지 전송 성공")
                } else {
                    print("❌ BLE 압축 메시지 전송 실패")
                }
            } else {
                print("❌ BLE characteristic가 설정되지 않음")
            }
            
        } catch {
            print("❌ 메시지 인코딩 실패: \(error)")
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
    
    // MARK: - 데이터 수신 처리
    private func handleReceivedData(_ data: Data) {
        print("🔍🔍🔍 handleReceivedData 호출됨 - \(data.count) bytes 🔍🔍🔍")
        let currentTime = Date()
        
        // 새로운 데이터 시작인지 확인 (1초 이상 간격이 있으면 새 데이터로 간주)
        if currentTime.timeIntervalSince(lastDataTime) > 1.0 {
            dataBuffer = Data()
            print("🔄🔄🔄 새로운 데이터 수신 시작 🔄🔄🔄")
        }
        
        // 데이터를 버퍼에 추가
        dataBuffer.append(data)
        lastDataTime = currentTime
        
        let bufferString = String(data: dataBuffer, encoding: .utf8) ?? "Invalid UTF-8"
        print("📥📥📥 누적 데이터 (\(dataBuffer.count) bytes): \(bufferString.prefix(200))... 📥📥📥")
        print("📥 Raw 데이터: \(data.map { String(format: "%02x", $0) }.joined(separator: " "))")
        
        // 완전한 JSON인지 확인 (시작과 끝 브레이스가 모두 있는지)
        let openBraces = bufferString.filter { $0 == "{" }.count
        let closeBraces = bufferString.filter { $0 == "}" }.count
        
        print("🔍 JSON 분석: 열린괄호=\(openBraces), 닫힌괄호=\(closeBraces)")
        
        if openBraces > 0 && openBraces == closeBraces {
            // 완전한 JSON이 조합됨
            print("✅✅✅ 완전한 JSON 조합됨! 처리 시작 ✅✅✅")
            print("✅ JSON 내용: \(bufferString)")
            processCompleteJson(dataBuffer)
            dataBuffer = Data() // 버퍼 초기화
        } else {
            print("⏳⏳⏳ JSON 조합 대기 중... (열린괄호: \(openBraces), 닫힌괄호: \(closeBraces)) ⏳⏳⏳")
        }
    }
    
    private func processCompleteJson(_ data: Data) {
        print("🚀🚀🚀 processCompleteJson 시작 - \(data.count) bytes 🚀🚀🚀")
        
        do {
            // 먼저 압축 해제 시도
            var finalData = data
            if let decompressedData = decompressData(data) {
                print("📥📥📥 압축 해제 성공: \(data.count) -> \(decompressedData.count) bytes 📥📥📥")
                finalData = decompressedData
            } else {
                print("📥📥📥 압축 해제 실패 또는 비압축 데이터, 원본 사용 📥📥📥")
            }
            
            let jsonString = String(data: finalData, encoding: .utf8) ?? "Invalid UTF-8"
            print("🔍🔍🔍 JSON 디코딩 시도: \(jsonString) 🔍🔍🔍")
            
            let message = try JSONDecoder().decode(ClipboardMessage.self, from: finalData)
            
            print("✅✅✅ JSON 디코딩 성공! ✅✅✅")
            print("✅ DeviceId: \(message.deviceId) (내 ID: \(deviceId))")
            print("✅ Content: \(message.content.prefix(100))...")
            print("✅ ContentType: \(message.contentType)")
            
            // 자신이 보낸 메시지는 무시
            guard message.deviceId != deviceId else { 
                print("⚠️⚠️⚠️ 자신이 보낸 메시지 무시: \(message.deviceId) ⚠️⚠️⚠️")
                return 
            }
            
            print("🎉🎉🎉 Android에서 클립보드 메시지 수신 성공! 🎉🎉🎉")
            print("🎉 내용: \(message.content.prefix(50))...")
            
            // ClipboardManager에 전달
            DispatchQueue.main.async {
                print("📋📋📋 ClipboardManager로 전달 중... 📋📋📋")
                ClipboardManager.shared.receiveFromRemoteDevice(message.content)
                print("📋📋📋 ClipboardManager 전달 완료! 📋📋📋")
            }
            
        } catch {
            let jsonString = String(data: data, encoding: .utf8) ?? "Invalid UTF-8"
            print("❌❌❌ JSON 디코딩 실패: \(error) ❌❌❌")
            print("❌ 원본 데이터: \(jsonString)")
            print("❌ 데이터 길이: \(data.count) bytes")
        }
    }
    
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