import XCTest
@testable import CopyDrop

/**
 * Logger 단위 테스트
 */
final class LoggerTests: XCTestCase {
    
    private var logger: Logger!
    
    override func setUp() {
        super.setUp()
        logger = Logger.shared
    }
    
    override func tearDown() {
        logger = nil
        super.tearDown()
    }
    
    func testBasicLogging() {
        // Given
        let testMessage = "Test log message"
        let testMetadata = ["key1": "value1", "key2": 42] as [String : Any]
        
        // When & Then - 예외가 발생하지 않아야 함
        XCTAssertNoThrow(logger.debug(.bluetooth, testMessage))
        XCTAssertNoThrow(logger.info(.network, testMessage))
        XCTAssertNoThrow(logger.warning(.auth, testMessage))
        XCTAssertNoThrow(logger.error(.crypto, testMessage))
        XCTAssertNoThrow(logger.fault(.performance, testMessage))
        
        // 메타데이터와 함께
        XCTAssertNoThrow(logger.info(.ui, testMessage, metadata: testMetadata))
    }
    
    func testBluetoothConnectionLogging() {
        // Given
        let deviceId = "test-android-device"
        
        // When & Then
        XCTAssertNoThrow(logger.logBluetoothConnection(deviceId: deviceId, isConnected: true))
        XCTAssertNoThrow(logger.logBluetoothConnection(deviceId: deviceId, isConnected: false))
    }
    
    func testDataTransferLogging() {
        // Given
        let direction = "송신"
        let size = 1024 * 5 // 5KB
        let type = "텍스트"
        
        // When & Then
        XCTAssertNoThrow(logger.logDataTransfer(direction: direction, size: size, type: type, encrypted: false))
        XCTAssertNoThrow(logger.logDataTransfer(direction: direction, size: size, type: type, encrypted: true))
    }
    
    func testPinAuthenticationLogging() {
        // Given
        let pin = "1234"
        let deviceId = "test-device"
        
        // When & Then
        XCTAssertNoThrow(logger.logPinAuthentication(success: true, pin: pin, deviceId: deviceId))
        XCTAssertNoThrow(logger.logPinAuthentication(success: false, pin: pin, deviceId: deviceId))
    }
    
    func testPerformanceLogging() {
        // Given
        let operation = "테스트 작업"
        let fastDuration = 0.1 // 100ms
        let slowDuration = 6.0 // 6초
        
        // When & Then
        XCTAssertNoThrow(logger.logPerformance(operation: operation, duration: fastDuration, success: true))
        XCTAssertNoThrow(logger.logPerformance(operation: operation, duration: slowDuration, success: true))
        XCTAssertNoThrow(logger.logPerformance(operation: operation, duration: fastDuration, success: false))
    }
    
    func testUserActionLogging() {
        // Given
        let action = "버튼 클릭"
        let component = "메뉴바"
        let metadata = ["button_id": "scan_button"]
        
        // When & Then
        XCTAssertNoThrow(logger.logUserAction(action: action, component: component))
        XCTAssertNoThrow(logger.logUserAction(action: action, component: component, metadata: metadata))
    }
    
    func testClipboardEventLogging() {
        // Given
        let event = "복사"
        let contentType = "텍스트"
        let size = 512
        
        // When & Then
        XCTAssertNoThrow(logger.logClipboardEvent(event: event, contentType: contentType, size: size))
        XCTAssertNoThrow(logger.logClipboardEvent(event: event, contentType: contentType, size: size, source: "remote"))
    }
    
    func testCryptoOperationLogging() {
        // Given
        let operation = "암호화"
        let dataSize = 1024
        
        // When & Then
        XCTAssertNoThrow(logger.logCryptoOperation(operation: operation, success: true, dataSize: dataSize))
        XCTAssertNoThrow(logger.logCryptoOperation(operation: operation, success: false, dataSize: dataSize))
    }
    
    func testLifecycleLogging() {
        // Given
        let component = "AppDelegate"
        let event = "applicationDidFinishLaunching"
        
        // When & Then
        XCTAssertNoThrow(logger.logLifecycle(component: component, event: event))
    }
    
    func testErrorLogging() {
        // Given
        let testError = NSError(domain: "TestDomain", code: 404, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let context = ["operation": "test_operation"]
        
        // When & Then
        XCTAssertNoThrow(logger.logError(.network, "Test error occurred", error: testError, context: context))
    }
    
    func testMeasurePerformance() {
        // Given
        let operation = "테스트 성능 측정"
        var result: Int = 0
        
        // When & Then
        XCTAssertNoThrow({
            result = logger.measurePerformance(operation: operation) {
                // 시뮬레이션된 작업
                Thread.sleep(forTimeInterval: 0.01) // 10ms
                return 42
            }
        }())
        
        XCTAssertEqual(42, result, "성능 측정 후 결과가 정확해야 함")
    }
    
    func testMeasurePerformanceWithError() {
        // Given
        let operation = "에러 발생 작업"
        enum TestError: Error {
            case testFailure
        }
        
        // When & Then
        XCTAssertThrowsError(try logger.measurePerformance(operation: operation) {
            throw TestError.testFailure
        }) { error in
            XCTAssertTrue(error is TestError, "올바른 에러 타입이어야 함")
        }
    }
    
    func testConcurrentLogging() {
        // Given
        let expectation = self.expectation(description: "Concurrent logging")
        expectation.expectedFulfillmentCount = 10
        
        // When
        for i in 1...10 {
            DispatchQueue.global().async {
                self.logger.info(.performance, "동시 로그 테스트 \(i)", metadata: ["thread": i])
                expectation.fulfill()
            }
        }
        
        // Then
        waitForExpectations(timeout: 2.0) { error in
            XCTAssertNil(error, "모든 로그가 성공적으로 완료되어야 함")
        }
    }
    
    func testLogCategoriesComplete() {
        // Given & When & Then
        // 모든 카테고리가 정의되어 있는지 확인
        XCTAssertTrue(Logger.Category.allCases.count >= 8, "최소 8개의 로그 카테고리가 정의되어야 함")
        
        // 각 카테고리가 고유한 rawValue를 가지는지 확인
        let rawValues = Logger.Category.allCases.map { $0.rawValue }
        let uniqueRawValues = Set(rawValues)
        XCTAssertEqual(rawValues.count, uniqueRawValues.count, "모든 카테고리가 고유한 rawValue를 가져야 함")
    }
}