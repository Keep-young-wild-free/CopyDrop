package com.copydrop.android

import android.app.Application
import timber.log.Timber

/**
 * CopyDrop 애플리케이션 클래스
 * - 전역 설정 및 메모리 누수 방지 관리
 */
class CopyDropApplication : Application() {
    
    companion object {
        private const val TAG = "CopyDropApplication"
    }
    
    override fun onCreate() {
        super.onCreate()
        
        // Timber 로깅 초기화
        if (BuildConfig.DEBUG) {
            Timber.plant(Timber.DebugTree())
            Timber.d("CopyDrop 애플리케이션 시작 (디버그 모드)")
        } else {
            // 릴리즈 모드에서는 Crash 로그만
            Timber.plant(ReleaseTree())
            Timber.d("CopyDrop 애플리케이션 시작 (릴리즈 모드)")
        }
        
        // LeakCanary는 debugImplementation으로 추가했으므로 자동으로 활성화됨
        Timber.d("LeakCanary 메모리 누수 감지 활성화됨 (디버그 빌드)")
    }
    
    override fun onTerminate() {
        super.onTerminate()
        Timber.d("CopyDrop 애플리케이션 종료")
    }
    
    override fun onLowMemory() {
        super.onLowMemory()
        Timber.w("메모리 부족 상태 감지 - 가비지 컬렉션 권장")
        
        // 강제 가비지 컬렉션 (필요시)
        System.gc()
    }
    
    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        
        when (level) {
            TRIM_MEMORY_UI_HIDDEN -> {
                Timber.d("UI 숨김 - 메모리 정리 시작")
            }
            TRIM_MEMORY_RUNNING_MODERATE -> {
                Timber.d("메모리 사용량 보통 - 캐시 정리")
            }
            TRIM_MEMORY_RUNNING_LOW -> {
                Timber.w("메모리 사용량 높음 - 적극적 정리")
            }
            TRIM_MEMORY_RUNNING_CRITICAL -> {
                Timber.e("메모리 사용량 위험 - 긴급 정리")
                System.gc() // 긴급 상황에서만 명시적 GC
            }
            else -> {
                Timber.d("메모리 트림 레벨: $level")
            }
        }
    }
}

/**
 * 릴리즈 모드용 Timber Tree (에러/크래시만 로깅)
 */
class ReleaseTree : Timber.Tree() {
    override fun log(priority: Int, tag: String?, message: String, t: Throwable?) {
        // 릴리즈에서는 에러와 심각한 경고만 로깅
        if (priority >= android.util.Log.WARN) {
            // 여기서 Firebase Crashlytics 등에 로그 전송 가능
            android.util.Log.println(priority, tag ?: "CopyDrop", message)
            t?.printStackTrace()
        }
    }
}