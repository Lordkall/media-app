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

subprojects {
    tasks.configureEach {
        if (name.contains("AarMetadata", ignoreCase = true)) {
            enabled = false
        }
    }
}

subprojects {
    if (project.name != "app") {
        project.afterEvaluate {
            project.extensions.findByName("android")?.let { androidExt ->
                val methods = androidExt.javaClass.methods
                val targetSdk = 36
                for (m in methods) {
                    if ((m.name == "compileSdkVersion" || m.name == "setCompileSdkVersion" || m.name == "setCompileSdk") && m.parameterCount == 1) {
                        try {
                            val paramType = m.parameterTypes[0]
                            if (paramType == Int::class.javaPrimitiveType || paramType == java.lang.Integer::class.java) {
                                m.invoke(androidExt, targetSdk)
                                println("Set compileSdk=$targetSdk on subproject ${project.name}")
                                break
                            }
                        } catch (_: Exception) {}
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
