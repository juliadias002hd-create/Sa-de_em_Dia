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

// Os módulos "jni" e "jni_flutter" (usados pelo path_provider_android) pedem
// a plataforma Android 35, que não está instalada nesta máquina. Compila só
// eles com a plataforma 36, que está. (Se instalar a plataforma 35 pelo
// Android Studio, este bloco pode ser removido.)
subprojects {
    afterEvaluate {
        if (project.name == "jni" || project.name == "jni_flutter") {
            extensions
                .findByType(com.android.build.api.dsl.LibraryExtension::class.java)
                ?.compileSdk = 36
        }
    }
}

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
