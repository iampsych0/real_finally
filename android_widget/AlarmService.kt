Run cd cspi
  cd cspi
  flutter build apk --release
  shell: /usr/bin/bash -e {0}
  env:
    JAVA_HOME: /opt/hostedtoolcache/Java_Zulu_jdk/17.0.20-8/x64
    JAVA_HOME_17_X64: /opt/hostedtoolcache/Java_Zulu_jdk/17.0.20-8/x64
    FLUTTER_ROOT: /opt/hostedtoolcache/flutter/stable-3.24.0-x64/flutter
    PUB_CACHE: /home/runner/.pub-cache

Running Gradle task 'assembleRelease'...                        
Checking the license for package Android SDK Build-Tools 30.0.3 in /usr/local/lib/android/sdk/licenses
License for package Android SDK Build-Tools 30.0.3 accepted.
Preparing "Install Android SDK Build-Tools 30.0.3 (revision: 30.0.3)".
"Install Android SDK Build-Tools 30.0.3 (revision: 30.0.3)" ready.
Installing Android SDK Build-Tools 30.0.3 in /usr/local/lib/android/sdk/build-tools/30.0.3
"Install Android SDK Build-Tools 30.0.3 (revision: 30.0.3)" complete.
"Install Android SDK Build-Tools 30.0.3 (revision: 30.0.3)" finished.
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 3148 bytes (99.8% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.
e: file:///home/runner/work/real_finally/real_finally/cspi/android/app/src/main/kotlin/com/example/cspi/AlarmService.kt:66:17 Val cannot be reassigned

FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:compileReleaseKotlin'.
> A failure occurred while executing org.jetbrains.kotlin.compilerRunner.GradleCompilerRunnerWithWorkers$GradleKotlinCompilerWorkAction
   > Compilation error. See log for more details

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights.

* Get more help at https://help.gradle.org

BUILD FAILED in 2m 48s
Running Gradle task 'assembleRelease'...                          169.6s
Gradle task assembleRelease failed with exit code 1
Error: Process completed with exit code 1.
