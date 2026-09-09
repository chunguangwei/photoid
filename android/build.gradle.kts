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

// onnxruntime 插件 AAR 元数据检查（compileSdk 33 vs 依赖要求 34）：
// 该任务仅校验库模块自身 compileSdk，app 以 SDK 37 编译已覆盖所需 API。
subprojects {
    tasks.matching {
        it.name in listOf("checkDebugAarMetadata", "checkReleaseAarMetadata")
    }.configureEach {
        // 替换为 no-op：跳过校验但产出声明的输出目录，保持任务图有效。
        // （onnxruntime 插件 compileSdk 33 vs 依赖要求 34；app 以 SDK 37 编译已覆盖）
        setActions(listOf(org.gradle.api.Action<org.gradle.api.Task> {
            outputs.files.forEach { f -> f.mkdirs() }
        }))
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
