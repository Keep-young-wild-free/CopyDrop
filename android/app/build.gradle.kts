plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.copydrop.android"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.copydrop.android"
        minSdk = 23  // Android 6.0 - BLE 지원
        targetSdk = 34
        versionCode = 2
        versionName = "1.1"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    
    kotlinOptions {
        jvmTarget = "17"
    }
    
}

dependencies {
    // JSON 처리
    implementation("com.google.code.gson:gson:2.10.1")
    
    // AndroidX Core for permissions
    implementation("androidx.core:core-ktx:1.12.0")
    
    // UI 컴포넌트
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.appcompat:appcompat:1.6.1")
    
    // 암호화 지원 (AES)
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    
    
    // 향상된 로깅
    implementation("com.jakewharton.timber:timber:5.0.1")
    
    // 단위 테스트
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.mockito:mockito-core:5.6.0")
    testImplementation("org.mockito:mockito-inline:5.2.0")
    testImplementation("androidx.test:core:1.5.0")
    testImplementation("org.robolectric:robolectric:4.11.1")
    
    // UI 테스트
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
    androidTestImplementation("androidx.test.espresso:espresso-intents:3.5.1")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.2.0")
}