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
import com.google.gson.Gson
import java.util.*

/**
 * Mac BluetoothManager와 연동하는 Android BLE 클라이언트
 * Mac은 Peripheral(서버), Android는 Central(클라이언트)
 */
class BluetoothService(private val context: Context) {
    
    companion object {
        private const val TAG = "BluetoothService"
        
        // Mac BluetoothManager와 동일한 UUID (docs/PROTOCOL.md 참조)
        private val SERVICE_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        private val CHARACTERISTIC_UUID = UUID.fromString("00002101-0000-1000-8000-00805F9B34FB")
        private const val SERVICE_NAME = "CopyDropService"
    }
    
    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val bluetoothAdapter = bluetoothManager.adapter
    private val bluetoothLeScanner: BluetoothLeScanner? = bluetoothAdapter?.bluetoothLeScanner
    private val gson = Gson()
    
    private var bluetoothGatt: BluetoothGatt? = null
    private var targetCharacteristic: BluetoothGattCharacteristic? = null
    private val deviceId = "android-${android.os.Build.MODEL}"
    private var currentMtu = 20 // 기본 MTU 크기
    
    // 콜백 인터페이스
    interface BluetoothServiceCallback {
        fun onDeviceFound(device: BluetoothDevice)
        fun onConnected()
        fun onDisconnected()
        fun onMessageReceived(message: ClipboardMessage)
        fun onError(error: String)
    }
    
    private var callback: BluetoothServiceCallback? = null
    private var isScanning = false
    
    fun setCallback(callback: BluetoothServiceCallback) {
        this.callback = callback
    }
    
    fun isBluetoothEnabled(): Boolean = bluetoothAdapter?.isEnabled == true
    
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
                        // MTU 크기 요청 (최대 512바이트)
                        Log.d(TAG, "MTU 크기 요청 중...")
                        gatt.requestMtu(512)
                        
                        // Notification 활성화
                        gatt.setCharacteristicNotification(characteristic, true)
                        
                        val descriptor = characteristic.getDescriptor(
                            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
                        )
                        descriptor?.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        gatt.writeDescriptor(descriptor)
                        
                        Log.d(TAG, "CopyDropService 연결 완료")
                        callback?.onConnected()
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
                val data = characteristic.value
                val jsonString = String(data, Charsets.UTF_8)
                
                Log.d(TAG, "📥 Mac에서 메시지 수신: ${jsonString.take(100)}...")
                
                try {
                    val message = gson.fromJson(jsonString, ClipboardMessage::class.java)
                    
                    // 자신이 보낸 메시지는 무시
                    if (message.deviceId != deviceId) {
                        Log.d(TAG, "✅ 메시지 수신 완료: ${message.content.take(30)}...")
                        callback?.onMessageReceived(message)
                    } else {
                        Log.d(TAG, "자신이 보낸 메시지 무시: ${message.deviceId}")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ 메시지 파싱 실패: ${jsonString}", e)
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
        targetCharacteristic?.let { characteristic ->
            val message = ClipboardMessage(content, deviceId)
            val jsonString = gson.toJson(message)
            val data = jsonString.toByteArray(Charsets.UTF_8)
            
            Log.d(TAG, "📤 메시지 전송 시도: ${content.take(30)}...")
            Log.d(TAG, "📤 JSON 크기: ${data.size} bytes, MTU: $currentMtu bytes")
            Log.d(TAG, "📤 JSON 전체: $jsonString")
            
            if (data.size <= currentMtu) {
                // 한 번에 전송 가능
                sendSinglePacket(characteristic, data)
            } else {
                // 분할 전송 필요
                Log.w(TAG, "⚠️ 데이터 크기가 MTU를 초과합니다. 분할 전송을 시도합니다.")
                sendChunkedData(characteristic, data)
            }
        } ?: run {
            Log.e(TAG, "❌ targetCharacteristic이 null입니다")
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
            
            // 다음 청크를 50ms 후에 전송
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                sendNextChunk(characteristic, chunks, index + 1)
            }, 50)
        } else {
            Log.e(TAG, "❌ 청크 ${index + 1} 전송 실패")
        }
    }
}