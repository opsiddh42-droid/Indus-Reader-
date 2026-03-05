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

    // --- SURGICAL STRIKE: Jis plugin ko jo Java version chahiye, wahi do ---
    tasks.withType<JavaCompile>().configureEach {
        if (project.name == "receive_sharing_intent") {
            sourceCompatibility = "1.8"
            targetCompatibility = "1.8"
        } else if (project.name == "file_picker") {
            sourceCompatibility = "11"
            targetCompatibility = "11"
        } else {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        if (project.name == "receive_sharing_intent") {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8)
        } else if (project.name == "file_picker") {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        } else {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
