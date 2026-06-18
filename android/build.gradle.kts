buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.3.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.24")
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = file("../build")

subprojects {
    project.buildDir = file("${rootProject.buildDir}/${project.name}")
    // Force all subprojects to compile against SDK 35
    afterEvaluate {
        if (project.hasProperty("android")) {
            extensions.findByName("android")?.let { ext ->
                (ext as? com.android.build.gradle.BaseExtension)?.let {
                    if (it.compileSdkVersion?.removePrefix("android-")?.toIntOrNull() ?: 0 < 35) {
                        it.compileSdkVersion(35)
                    }
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}