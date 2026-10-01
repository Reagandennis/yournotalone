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

// Several plugins still compile their Java with source/target 8, which newer
// JDKs warn about on every build. The app itself targets 17; this only quiets
// the plugins' "source value 8 is obsolete" lines.
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
