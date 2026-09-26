import com.android.build.gradle.LibraryExtension

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
    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension>("android") {
            if (project.name == "better_player") {
                if (namespace == null) {
                    namespace = "com.jhomlala.better_player"
                }
            }
        }
        if (project.name == "better_player") {
            afterEvaluate {
                extensions.configure<LibraryExtension>("android") {
                    compileSdk = 36
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}
// StartApp : force la 4.11.5 (dernière compatible compileSdk 36) dans TOUS les
// modules, y compris :startapp_sdk qui compile en 34 et résolvait sinon la 5.3.2
// (exige compileSdk 37) → échec checkReleaseAarMetadata en CI.
// (Un force déclaré dans :app seul ne s'applique pas aux modules librairies.)
subprojects {
    configurations.all {
        resolutionStrategy {
            force("com.startapp:inapp-sdk:4.11.5")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
