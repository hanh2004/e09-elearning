allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Chú ý: Dùng ngoặc đơn () và nháy kép ""
        classpath("com.google.gms:google-services:4.3.15")
    }
}
// ... các phần sau giữ nguyên
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
subprojects {
    pluginManager.withPlugin("com.android.library") {
        dependencies {
            add("compileOnly", "org.checkerframework:checker-qual:3.42.0")
        }
    }
}