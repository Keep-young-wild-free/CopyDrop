import SwiftUI

/**
 * Pin 표시 팝업 뷰
 * Mac에서 4자리 Pin을 표시하고 인증 대기 상태를 보여줍니다
 */
struct PinDisplayView: View {
    @ObservedObject var pinAuthManager: PinAuthManager
    @State private var isVisible = true
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            headerView
            
            Divider()
            
            if let pin = pinAuthManager.currentPin {
                pinContentView(pin: pin)
            } else {
                expiredPinView
            }
            
            Divider()
            
            infoView
        }
        .padding(25)
        .frame(width: 400)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            onDismiss()
        }
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "key.fill")
                .foregroundColor(.blue)
                .font(.title2)
            
            Text("Pin 연결")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func pinContentView(pin: String) -> some View {
        VStack(spacing: 15) {
            Text("Android 앱에서 이 Pin을 입력하세요")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            pinDigitsView(pin: pin)
            
            if pinAuthManager.isWaitingForAuth {
                waitingView
            }
            
            if !pinAuthManager.connectedDevices.isEmpty {
                connectedDevicesView
            }
        }
    }
    
    private func pinDigitsView(pin: String) -> some View {
        HStack(spacing: 15) {
            ForEach(Array(pin.enumerated()), id: \.offset) { index, digit in
                Text(String(digit))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .frame(width: 60, height: 80)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    )
                    .scaleEffect(isVisible ? 1.0 : 0.8)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.1), value: isVisible)
            }
        }
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
    
    private var waitingView: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(0.8)
            
            Text("Android 앱에서 Pin 입력을 기다리는 중...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 10)
    }
    
    private var connectedDevicesView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("연결된 디바이스:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(Array(pinAuthManager.connectedDevices), id: \.self) { deviceId in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text(deviceId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 10)
    }
    
    private var expiredPinView: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.title)
                .foregroundColor(.orange)
            
            Text("Pin이 만료되었습니다")
                .font(.headline)
            
            Text("새로운 Pin을 생성하려면 다시 시도하세요")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("새 Pin 생성") {
                let _ = pinAuthManager.generateNewPin()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    private var infoView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text("Pin은 5분간 유효합니다")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            HStack {
                Image(systemName: "shield")
                    .foregroundColor(.green)
                    .font(.caption)
                
                Text("인증 후 24시간 동안 자동 재연결됩니다")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(.top, 5)
    }
}

// MARK: - Preview
struct PinDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        let pinAuthManager = PinAuthManager.shared
        let _ = pinAuthManager.generateNewPin()
        
        return PinDisplayView(pinAuthManager: pinAuthManager) {
            // Dismiss action
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}