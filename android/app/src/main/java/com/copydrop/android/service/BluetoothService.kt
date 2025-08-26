package com.copydrop.android.service

import android.bluetooth.*
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import com.copydrop.android.model.ClipboardMessage
import com.copydrop.android.auth.PinAuthManager
import com.google.gson.Gson
import java.util.*
import java.util.zip.GZIPInputStream
import java.util.zip.GZIPOutputStream
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.zip.CRC32

/**
 * Mac BluetoothManager와 연동하는 Android BLE 클라이언트
 * Mac은 Peripheral(서버), Android는 Central(클라이언트)
 */
class BluetoothService(private val context: Context) {
    
    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val bluetoothAdapter = bluetoothManager.adapter
    private val bluetoothLeScanner: BluetoothLeScanner? = bluetoothAdapter?.bluetoothLeScanner
    private val gson = Gson()
    private val pinAuthManager = PinAuthManager(context) // PIN 인증 관리자 추가
    
    private var bluetoothGatt: BluetoothGatt? = null
    private var targetCharacteristic: BluetoothGattCharacteristic? = null
    private val deviceId = "android-${android.os.Build.MODEL}"
    private var currentMtu = 20 // 기본 MTU 크기
    
    // 속도 최적화 관련 변수들
    private var pendingTransmission: PendingTransmission? = null
    private val sentChunks = mutableMapOf<Int, Boolean>() // 전송 완료된 청크 추적
    private var retryCount = 0
    
    // 하이브리드 통신을 위한 임계값 (KB 단위)
    companion object {
        private const val TAG = "BluetoothService"
        
        // Mac BluetoothManager와 동일한 UUID (docs/PROTOCOL.md 참조)
        private val SERVICE_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        private val CHARACTERISTIC_UUID = UUID.fromString("00002101-0000-1000-8000-00805F9B34FB")
        private const val SERVICE_NAME = "CopyDropService"
        
        private const val MAX_RETRY_COUNT = 3 // 최대 재전송 횟수
        private const val PARALLEL_CHUNK_SIZE = 4 // 동시 전송 청크 수
        private const val OPTIMIZED_INTERVAL = 5L // 최적화된 전송 간격 (ms)
    }
    
    // 재전송을 위한 데이터 클래스
    data class PendingTransmission(
        val originalData: ByteArray,
        val chunks: List<OrderedChunk>,
        val checksum: Long,
        val messageId: String
    )
    
    // 순서가 보장된 청크
    data class OrderedChunk(
        val index: Int,
        val total: Int,
        val data: ByteArray,
        val messageId: String
    )
    
    
    // 콜백 인터페이스
    interface BluetoothServiceCallback {
        fun onDeviceFound(device: BluetoothDevice)
        fun onConnected()
        fun onDisconnected()
        fun onMessageReceived(message: ClipboardMessage)
        fun onError(error: String)
        fun onSyncRequested() // Mac에서 동기화 요청 시
        fun onAuthRequired() // PIN 인증 필요
        fun onAuthSuccess(sessionToken: String) // PIN 인증 성공
        fun onAuthFailed(error: String) // PIN 인증 실패
    }
    
    private var callback: BluetoothServiceCallback? = null
    private var isScanning = false
    
    fun setCallback(callback: BluetoothServiceCallback) {
        this.callback = callback
    }
    
    fun isBluetoothEnabled(): Boolean = bluetoothAdapter?.isEnabled == true
    
    // PIN 인증을 위한 변수
    private var currentPin: String? = null
    
    /**
     * PIN 인증을 시작합니다
     */
    fun authenticateWithPin(pin: String) {
        currentPin = pin
        Log.d(TAG, "🔐 PIN 인증 준비: $pin")
    }
    
    /**
     * PIN 인증 상태를 초기화합니다
     */
    fun clearPinAuthentication() {
        currentPin = null
        Log.d(TAG, "🔐 PIN 인증 상태 초기화")
    }
    
    /**
     * PIN 인증 메시지를 Mac으로 전송합니다
     */
    private fun sendPinAuthentication(pin: String) {
        try {
            Log.d(TAG, "🔐 PIN 인증 메시지 전송 시작: $pin")
            
            // PinAuthManager를 사용하여 인증 요청 메시지 생성
            val authRequestJson = pinAuthManager.createAuthRequest(pin)
            Log.d(TAG, "📤 인증 요청 메시지 생성: ${authRequestJson.take(100)}...")
            
            // Mac으로 인증 요청 전송
            targetCharacteristic?.let { characteristic ->
                val authData = authRequestJson.toByteArray(Charsets.UTF_8)
                
                characteristic.value = authData
                characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                
                val success = bluetoothGatt?.writeCharacteristic(characteristic) ?: false
                if (success) {
                    Log.d(TAG, "✅ PIN 인증 요청 전송 성공")
                } else {
                    Log.e(TAG, "❌ PIN 인증 요청 전송 실패")
                    callback?.onAuthFailed("PIN 인증 요청 전송 실패")
                }
            } ?: run {
                Log.e(TAG, "❌ targetCharacteristic이 null입니다")
                callback?.onAuthFailed("연결이 준비되지 않았습니다")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ PIN 인증 전송 중 오류 발생", e)
            callback?.onAuthFailed("PIN 인증 전송 실패: ${e.message}")
        }
    }
    
    fun startScan() {
        if (isScanning) return
        
        Log.d(TAG, "BLE 스캔 시작 - CopyDropService 검색")
        isScanning = true
        
        // 스캔 필터 설정 (서비스 UUID로 필터링)
        val scanFilter = ScanFilter.Builder()
            .setServiceUuid(ParcelUuid(SERVICE_UUID))
            .build()
        
        val scanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        
        bluetoothLeScanner?.startScan(listOf(scanFilter), scanSettings, scanCallback)
        
        // 10초 후 자동 스캔 중지
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            if (isScanning) {
                stopScan()
                callback?.onError("CopyDropService를 찾을 수 없습니다")
            }
        }, 10000)
    }
    
    fun stopScan() {
        if (!isScanning) return
        
        Log.d(TAG, "BLE 스캔 중지")
        isScanning = false
        bluetoothLeScanner?.stopScan(scanCallback)
    }
    
    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device
            val deviceName = device.name
            val scanRecord = result.scanRecord
            
            Log.d(TAG, "CopyDropService 기기 발견: ${deviceName} (${device.address})")
            
            // 서비스 UUID로 필터링되었으므로 바로 연결 시도
            Log.d(TAG, "✅ CopyDropService 발견! 자동 연결 시작")
            callback?.onDeviceFound(device)
            stopScan()
        }
        
        override fun onScanFailed(errorCode: Int) {
            Log.e(TAG, "스캔 실패: $errorCode")
            isScanning = false
            callback?.onError("스캔 실패: $errorCode")
        }
    }
    
    fun connectToDevice(device: BluetoothDevice) {
        Log.d(TAG, "기기 연결 시도: ${device.address}")
        bluetoothGatt = device.connectGatt(context, false, gattCallback)
    }
    
    fun disconnect() {
        bluetoothGatt?.disconnect()
        bluetoothGatt?.close()
        bluetoothGatt = null
        targetCharacteristic = null
        clearPinAuthentication() // 연결 해제 시 PIN 상태 초기화
    }
    
    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    Log.d(TAG, "GATT 연결됨")
                    gatt.discoverServices()
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    Log.d(TAG, "GATT 연결 해제됨")
                    callback?.onDisconnected()
                }
            }
        }
        
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                val service = gatt.getService(SERVICE_UUID)
                if (service != null) {
                    targetCharacteristic = service.getCharacteristic(CHARACTERISTIC_UUID)
                    targetCharacteristic?.let { characteristic ->
                        // 연결 우선순위 최적화 (속도 향상)
                        Log.d(TAG, "연결 우선순위 최적화 중...")
                        gatt.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH)
                        
                        // MTU 크기 요청 (최대 517바이트 - BLE 최대값)
                        Log.d(TAG, "MTU 크기 요청 중...")
                        gatt.requestMtu(517)
                        
                        // Notification 활성화
                        gatt.setCharacteristicNotification(characteristic, true)
                        
                        val descriptor = characteristic.getDescriptor(
                            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
                        )
                        descriptor?.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        gatt.writeDescriptor(descriptor)
                        
                        Log.d(TAG, "CopyDropService 연결 완료")
                        callback?.onConnected()
                        
                        // 자동 PIN 인증 시작
                        currentPin?.let { pin ->
                            Log.d(TAG, "🔐 자동 PIN 인증 시작: $pin")
                            sendPinAuthentication(pin)
                        }
                    }
                } else {
                    callback?.onError("CopyDropService를 찾을 수 없습니다")
                }
            }
        }
        
        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                Log.d(TAG, "✅ MTU 크기 설정 성공: $mtu bytes")
                currentMtu = mtu - 3 // ATT 헤더 3바이트 제외
            } else {
                Log.w(TAG, "⚠️ MTU 크기 설정 실패, 기본값 사용: 20 bytes")
                currentMtu = 20
            }
        }
        
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            if (characteristic.uuid == CHARACTERISTIC_UUID) {
                val receivedData = characteristic.value
                
                Log.d(TAG, "📥 Mac에서 데이터 수신: ${receivedData.size} bytes")
                
                try {
                    // 하이브리드 데이터로 수신
                    val rawContent = String(receivedData, Charsets.UTF_8)
                    
                    Log.d(TAG, "📥 Mac에서 하이브리드 데이터 수신: ${rawContent.take(100)}...")
                    
                    // 메시지 타입 확인 (인증 응답인지 클립보드 데이터인지)
                    if (rawContent.contains("\"type\":\"auth_response\"")) {
                        // 인증 응답 처리
                        handleAuthResponse(rawContent)
                    } else if (rawContent.contains("\"type\":\"sync_request\"")) {
                        // 동기화 요청 처리
                        handleSyncRequest(rawContent)
                    } else {
                        // 일반 클립보드 데이터 처리
                        Log.d(TAG, "📝 클립보드 데이터 수신: ${rawContent.take(50)}...")
                        val cleanContent = rawContent
                        
                        // ClipboardMessage 객체 생성
                        val message = ClipboardMessage(
                            content = cleanContent,
                            deviceId = "mac-device"
                        )
                        
                        Log.d(TAG, "✅✅✅ Mac에서 클립보드 수신 완료: ${cleanContent.take(30)}... ✅✅✅")
                        callback?.onMessageReceived(message)
                    }
                    
                } catch (e: Exception) {
                    Log.e(TAG, "❌❌❌ 데이터 처리 실패 ❌❌❌", e)
                }
            }
        }
        
        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            if (characteristic.uuid == CHARACTERISTIC_UUID) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.d(TAG, "✅ Mac으로 메시지 전송 성공")
                } else {
                    Log.e(TAG, "❌ Mac으로 메시지 전송 실패: status=$status")
                }
            }
        }
    }
    
    fun sendMessage(content: String) {
        Log.d(TAG, "🚀🚀🚀 sendMessage 호출됨: ${content.take(50)}... 🚀🚀🚀")
        
        // 크기 체크 (10MB 제한)
        val sizeBytes = content.toByteArray(Charsets.UTF_8).size
        if (sizeBytes > 10 * 1024 * 1024) {
            val sizeMB = String.format("%.1f", sizeBytes / (1024.0 * 1024.0))
            Log.i(TAG, "🌐 큰 데이터 감지 (${sizeMB}MB), Wi-Fi 전송 권장")
            callback?.onError("파일이 너무 큽니다 (${sizeMB}MB). Wi-Fi 연결 시 더 빠르게 전송됩니다.")
            return
        }
        
        targetCharacteristic?.let { characteristic ->
            val sizeBytes = content.toByteArray(Charsets.UTF_8).size
            val sizeKB = sizeBytes / 1024
            
            Log.d(TAG, "📤📤📤 텍스트 전송 시작 - 크기: ${sizeKB}KB 📤📤📤")
            
            sendTextData(characteristic, content)
        } ?: run {
            Log.e(TAG, "❌❌❌ targetCharacteristic이 null입니다 ❌❌❌")
        }
    }
    
    // 텍스트 전송
    private fun sendTextData(characteristic: BluetoothGattCharacteristic, content: String) {
        val transmitData = content.toByteArray(Charsets.UTF_8)
        
        Log.d(TAG, "📝 텍스트 전송: ${content.take(50)}... (${transmitData.size} bytes)")
        
        if (transmitData.size <= currentMtu) {
            sendSinglePacketOptimized(characteristic, transmitData)
        } else {
            sendChunkedData(characteristic, transmitData)
        }
    }
    
    
    private fun sendSinglePacket(characteristic: BluetoothGattCharacteristic, data: ByteArray) {
        characteristic.value = data
        characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        
        val success = bluetoothGatt?.writeCharacteristic(characteristic) ?: false
        if (success) {
            Log.d(TAG, "✅ 단일 패킷 전송 성공")
        } else {
            Log.e(TAG, "❌ 단일 패킷 전송 실패")
        }
    }
    
    private fun sendChunkedData(characteristic: BluetoothGattCharacteristic, data: ByteArray) {
        val chunks = data.toList().chunked(currentMtu)
        Log.d(TAG, "📦 데이터를 ${chunks.size}개 청크로 분할")
        
        sendNextChunk(characteristic, chunks, 0)
    }
    
    
    private fun sendNextChunk(characteristic: BluetoothGattCharacteristic, chunks: List<List<Byte>>, index: Int) {
        if (index >= chunks.size) {
            Log.d(TAG, "✅ 모든 청크 전송 완료")
            return
        }
        
        val chunk = chunks[index].toByteArray()
        characteristic.value = chunk
        characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        
        val success = bluetoothGatt?.writeCharacteristic(characteristic) ?: false
        if (success) {
            Log.d(TAG, "✅ 청크 ${index + 1}/${chunks.size} 전송 (${chunk.size} bytes)")
            
            // 다음 청크를 10ms 후에 전송 (5배 빠름)
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                sendNextChunk(characteristic, chunks, index + 1)
            }, 10)
        } else {
            Log.e(TAG, "❌ 청크 ${index + 1} 전송 실패")
        }
    }
    
    
    // MARK: - 고속 최적화된 전송 메서드들
    
    /**
     * 단일 패킷 최적화 전송 (Write Without Response)
     */
    private fun sendSinglePacketOptimized(characteristic: BluetoothGattCharacteristic, data: ByteArray) {
        Log.d(TAG, "🚀🚀🚀 sendSinglePacketOptimized 시작 - ${data.size} bytes 🚀🚀🚀")
        
        characteristic.value = data
        characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT // Mac의 didReceiveWrite 콜백 활성화
        
        Log.d(TAG, "📤 전송할 데이터: ${String(data, Charsets.UTF_8).take(100)}...")
        Log.d(TAG, "📤 Raw 데이터: ${data.map { String.format("%02x", it) }.take(20).joinToString(" ")}...")
        
        val success = bluetoothGatt?.writeCharacteristic(characteristic) ?: false
        if (success) {
            Log.d(TAG, "🚀🚀🚀 고속 단일 패킷 전송 성공! 🚀🚀🚀")
        } else {
            Log.e(TAG, "❌❌❌ 고속 단일 패킷 전송 실패! ❌❌❌")
        }
    }
    
    /**
     * 고속 병렬 청크 전송
     */
    private fun sendOptimizedChunkedData(characteristic: BluetoothGattCharacteristic, data: ByteArray) {
        val messageId = UUID.randomUUID().toString()
        val chunks = createOrderedChunks(data, messageId)
        val checksum = calculateChecksum(data)
        
        // 재전송을 위한 정보 저장
        pendingTransmission = PendingTransmission(data, chunks, checksum, messageId)
        sentChunks.clear()
        retryCount = 0
        
        Log.d(TAG, "📦 고속 병렬 전송: ${chunks.size}개 청크, 체크섬: $checksum")
        
        // 병렬 전송 시작
        sendParallelChunks(characteristic, chunks)
    }
    
    /**
     * 순서가 보장된 청크 생성
     */
    private fun createOrderedChunks(data: ByteArray, messageId: String): List<OrderedChunk> {
        val chunkSize = currentMtu - 50 // 메타데이터를 위한 여유 공간
        val chunks = mutableListOf<OrderedChunk>()
        val totalChunks = (data.size + chunkSize - 1) / chunkSize // 올림 계산
        
        for (i in 0 until totalChunks) {
            val start = i * chunkSize
            val end = minOf(start + chunkSize, data.size)
            val chunkData = data.sliceArray(start until end)
            
            chunks.add(OrderedChunk(i, totalChunks, chunkData, messageId))
        }
        
        return chunks
    }
    
    /**
     * 체크섬 계산
     */
    private fun calculateChecksum(data: ByteArray): Long {
        val crc32 = CRC32()
        crc32.update(data)
        return crc32.value
    }
    
    /**
     * 병렬 청크 전송
     */
    private fun sendParallelChunks(characteristic: BluetoothGattCharacteristic, chunks: List<OrderedChunk>) {
        chunks.chunked(PARALLEL_CHUNK_SIZE).forEachIndexed { batchIndex, batch ->
            batch.forEachIndexed { chunkIndex, chunk ->
                val delay = batchIndex * PARALLEL_CHUNK_SIZE * OPTIMIZED_INTERVAL + chunkIndex * OPTIMIZED_INTERVAL
                
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    sendOptimizedChunk(characteristic, chunk)
                }, delay)
            }
        }
        
        // 전송 완료 확인 타이머
        val totalDelay = chunks.size * OPTIMIZED_INTERVAL + 1000 // 1초 여유
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            checkTransmissionComplete()
        }, totalDelay)
    }
    
    /**
     * 최적화된 청크 전송
     */
    private fun sendOptimizedChunk(characteristic: BluetoothGattCharacteristic, chunk: OrderedChunk) {
        val chunkJson = gson.toJson(chunk)
        val chunkData = chunkJson.toByteArray(Charsets.UTF_8)
        
        characteristic.value = chunkData
        characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        
        val success = bluetoothGatt?.writeCharacteristic(characteristic) ?: false
        if (success) {
            sentChunks[chunk.index] = true
            Log.d(TAG, "🚀 고속 청크 ${chunk.index + 1}/${chunk.total} 전송 완료")
        } else {
            Log.e(TAG, "❌ 고속 청크 ${chunk.index + 1} 전송 실패")
        }
    }
    
    /**
     * 전송 완료 확인 및 재전송 로직
     */
    private fun checkTransmissionComplete() {
        pendingTransmission?.let { transmission ->
            val failedChunks = transmission.chunks.filter { !sentChunks.containsKey(it.index) || sentChunks[it.index] != true }
            
            if (failedChunks.isEmpty()) {
                Log.d(TAG, "✅ 고속 전송 완전 성공!")
                pendingTransmission = null
                sentChunks.clear()
            } else if (retryCount < MAX_RETRY_COUNT) {
                retryCount++
                Log.w(TAG, "⚠️ 재전송 시도 $retryCount/$MAX_RETRY_COUNT - 실패 청크: ${failedChunks.size}개")
                
                targetCharacteristic?.let { characteristic ->
                    sendParallelChunks(characteristic, failedChunks)
                }
            } else {
                Log.e(TAG, "❌ 최대 재전송 횟수 초과 - 전송 실패")
                callback?.onError("전송 실패: 연결이 불안정합니다")
                pendingTransmission = null
                sentChunks.clear()
                retryCount = 0
            }
        }
    }
    
    // MARK: - 인증 응답 처리
    
    /**
     * Mac에서 온 인증 응답 처리
     */
    private fun handleAuthResponse(jsonString: String) {
        try {
            Log.d(TAG, "🔐 인증 응답 처리 중...")
            
            // PinAuthManager를 사용하여 인증 응답 파싱
            val authResponse = pinAuthManager.parseAuthResponse(jsonString)
            
            if (authResponse != null) {
                if (authResponse.success) {
                    Log.d(TAG, "🎉 PIN 인증 성공!")
                    
                    // 세션 토큰 저장
                    authResponse.sessionToken?.let { token ->
                        pinAuthManager.saveSessionToken(token, pinAuthManager.getOrCreateDeviceId())
                        Log.d(TAG, "💾 세션 토큰 저장 완료: ${token.take(8)}...")
                    }
                    
                    // 성공 콜백 호출
                    callback?.onAuthSuccess(authResponse.sessionToken ?: "")
                    
                } else {
                    Log.w(TAG, "❌ PIN 인증 실패: ${authResponse.error}")
                    clearPinAuthentication() // PIN 상태 초기화
                    callback?.onAuthFailed(authResponse.error ?: "PIN 인증 실패")
                }
            } else {
                Log.e(TAG, "❌ 인증 응답 파싱 실패")
                callback?.onAuthFailed("인증 응답 파싱 실패")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ 인증 응답 처리 실패", e)
            callback?.onAuthFailed("인증 응답 처리 실패: ${e.message}")
        }
    }
    
    // MARK: - 동기화 요청 처리
    
    /**
     * Mac에서 온 동기화 요청 처리
     */
    private fun handleSyncRequest(jsonString: String) {
        try {
            Log.d(TAG, "🔄 동기화 요청 처리 중...")
            
            // 현재 클립보드 내용 즉시 전송
            callback?.onSyncRequested()
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ 동기화 요청 처리 실패", e)
        }
    }
}