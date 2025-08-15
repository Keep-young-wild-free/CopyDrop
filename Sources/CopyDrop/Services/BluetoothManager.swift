import Foundation
import CoreBluetooth
import Network
import Crypto

struct ConnectedDevice {
    let name: String
    let address: String
    let lastSeen: Date
}

struct ClipboardMessage: Codable {
    let content: String
    let timestamp: Date
    let deviceId: String
    let messageId: UUID
    
    init(content: String, deviceId: String) {
        self.content = content
        self.timestamp = Date()
        self.deviceId = deviceId
        self.messageId = UUID()
    }
}

class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager()
    
    @Published var isServerRunning = false
    @Published var isConnected = false
    @Published var connectedDevices: [ConnectedDevice] = []
    
    // Core Bluetooth 설정
    private let serviceUUID = CBUUID(string: "00001101-0000-1000-8000-00805F9B34FB")
    private let characteristicUUID = CBUUID(string: "00002101-0000-1000-8000-00805F9B34FB")
    private let serviceName = "CopyDropService"
    
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var service: CBMutableService?
    private var characteristic: CBMutableCharacteristic?
    
    private let deviceId: String
    
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
        
        // 시뮬레이션: 5초 후 가상 기기 연결 (테스트용)
        simulateDeviceConnection()
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
        
        let message = ClipboardMessage(content: content, deviceId: deviceId)
        
        do {
            let data = try JSONEncoder().encode(message)
            
            // Core Bluetooth를 통한 데이터 전송
            if let characteristic = characteristic {
                let success = peripheralManager?.updateValue(data, for: characteristic, onSubscribedCentrals: nil) ?? false
                if success {
                    print("BLE 메시지 전송 성공: \(content.prefix(30))...")
                } else {
                    print("BLE 메시지 전송 실패")
                }
            } else {
                // 시뮬레이션: 전송 성공으로 가정 (테스트용)
                print("시뮬레이션: 메시지 전송됨 - \(content.prefix(30))...")
            }
            
        } catch {
            print("메시지 인코딩 실패: \(error)")
        }
    }
    
    // MARK: - 데이터 수신 처리
    private func handleReceivedData(_ data: Data) {
        do {
            let message = try JSONDecoder().decode(ClipboardMessage.self, from: data)
            
            // 자신이 보낸 메시지는 무시
            guard message.deviceId != deviceId else { return }
            
            print("메시지 수신: \(message.content.prefix(30))...")
            
            // ClipboardManager에 전달
            DispatchQueue.main.async {
                ClipboardManager.shared.receiveFromRemoteDevice(message.content)
            }
            
        } catch {
            print("수신 메시지 디코딩 실패: \(error)")
        }
    }
    
    // MARK: - 시뮬레이션 (개발용)
    private func simulateDeviceConnection() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            let device = ConnectedDevice(
                name: "Galaxy S24",
                address: "AA:BB:CC:DD:EE:FF",
                lastSeen: Date()
            )
            
            self.connectedDevices.append(device)
            self.isConnected = true
            
            print("시뮬레이션: 기기 연결됨 - \(device.name)")
            
            // 테스트 메시지 수신 시뮬레이션
            self.simulateMessageReception()
        }
    }
    
    private func simulateMessageReception() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            let testMessage = ClipboardMessage(
                content: "Android에서 보낸 테스트 메시지입니다!",
                deviceId: "android-galaxy"
            )
            
            if let data = try? JSONEncoder().encode(testMessage) {
                self.handleReceivedData(data)
            }
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
        for request in requests {
            if let value = request.value {
                handleReceivedData(value)
                peripheral.respond(to: request, withResult: .success)
            }
        }
    }
}