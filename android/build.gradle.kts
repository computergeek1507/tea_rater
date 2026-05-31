allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

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

    // AGP 9 dropped automatic Kotlin support for library modules. Some Flutter
    // plugins (e.g. file_picker) ship Kotlin sources but expect the host
    // project to apply the Kotlin plugin under AGP 9+. Do that here so any
    // Android library subproject that contains Kotlin sources still compiles.
    plugins.withId("com.android.library") {
        if (!plugins.hasPlugin("org.jetbrains.kotlin.android")) {
            plugins.apply("org.jetbrains.kotlin.android")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
