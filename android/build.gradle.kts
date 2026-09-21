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
}

// file_picker 11.0.2 only applies the Kotlin Gradle Plugin when AGP < 9,
// assuming AGP 9's built-in Kotlin will compile its sources instead. This
// project keeps android.builtInKotlin=false (the Flutter template default),
// so without this its Kotlin source never gets compiled and
// GeneratedPluginRegistrant.java fails with "cannot find symbol FilePickerPlugin".
subprojects {
    if (project.name == "file_picker") {
        project.plugins.apply("org.jetbrains.kotlin.android")
        // file_picker only sets jvmTarget for AGP < 9, so under AGP 9 Kotlin
        // defaults to a newer target than the Java sources' target (17),
        // which fails with "Inconsistent JVM Target Compatibility".
        project.extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
