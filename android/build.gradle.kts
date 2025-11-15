import org.gradle.api.tasks.Delete

plugins {
    id("com.android.application") version "8.5.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val sharedBuildDir = rootProject.layout.buildDirectory.dir("../../build")
rootProject.layout.buildDirectory.set(sharedBuildDir)

subprojects {
    // Reuse the shared build directory so app/ and plugin builds go to `<repo>/build`.
    layout.buildDirectory.set(sharedBuildDir.map { it.dir(name) })
    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}


