plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.copydrop.android"
    compileSdk = 32

    defaultConfig {
        applicationId = "com.copydrop.android"
        minSdk = 23  // Android 6.0 - BLE 지원
        targetSdk = 32
        versionCode = 1
        versionName = "1.0"

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
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    
    kotlinOptions {
        jvmTarget = "1.8"
    }
    
}

dependencies {
    // JSON 처리만 - 다른 의존성 완전 제거
    implementation("com.google.code.gson:gson:2.8.9")
    
    testImplementation("junit:junit:4.13.2")
}