allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
// Phiên bản Google Services chỉ khai báo tại settings.gradle.kts để tránh trùng plugin.
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
