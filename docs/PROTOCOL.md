# CopyDrop BLE 통신 프로토콜

## 📡 Bluetooth Low Energy 사양

### 서비스 및 특성 UUID
```
Service UUID:        00001101-0000-1000-8000-00805F9B34FB
Characteristic UUID: 00002101-0000-1000-8000-00805F9B34FB
Service Name:        "CopyDropService"
```

### 역할 분담
- **Mac**: BLE Peripheral (서버) - 광고하고 대기
- **Android**: BLE Central (클라이언트) - 스캔하고 연결

## 📦 데이터 구조

### ClipboardMessage JSON 포맷
```json
{
  "content": "클립보드 텍스트 내용",
  "timestamp": "2024-01-01T12:00:00Z",
  "deviceId": "mac-MacBook-Pro",
  "messageId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### 필드 설명
- **content**: 클립보드 텍스트 내용 (String)
- **timestamp**: UTC 타임스탬프 (ISO 8601)
- **deviceId**: 발신 기기 식별자 (String)
- **messageId**: 중복 메시지 방지용 UUID (String)

## 🔄 통신 흐름

### 1. 연결 설정
1. Mac이 BLE 광고 시작 (`CopyDropService`)
2. Android가 스캔하여 서비스 발견
3. Android가 Mac에 연결 요청
4. 특성 구독 설정 (Notification 활성화)

### 2. 클립보드 동기화
```
Mac 클립보드 변경 → JSON 인코딩 → BLE 전송 → Android 수신 → 클립보드 적용
Android 클립보드 변경 → JSON 인코딩 → BLE 전송 → Mac 수신 → 클립보드 적용
```

### 3. 중복 방지
- 자신이 보낸 메시지는 `deviceId`로 필터링
- 동일한 `messageId`는 무시

## 🛡️ 보안 및 필터링

### Mac 측 필터링 (송신 시)
```swift
// AppSettings.shouldFilterContent() 사용
- 콘텐츠 길이 제한: 1,000~50,000 글자
- 차단 키워드 검사
- 민감한 정보 패턴 감지
```

### 예외 처리
- 연결 끊김 시 자동 재연결
- JSON 파싱 오류 시 무시
- BLE 권한 없을 시 사용자 안내

## 🔧 구현 참고사항

### Mac (Core Bluetooth)
- `CBPeripheralManager`로 서버 구현
- `CBMutableCharacteristic`으로 데이터 전송
- `updateValue(_:for:onSubscribedCentrals:)` 사용

### Android (Android BLE)
- `BluetoothGatt`로 클라이언트 구현
- `onCharacteristicChanged()` 콜백으로 수신
- `writeCharacteristic()` 으로 전송