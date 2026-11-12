# Android build — Last Shelter v0.23

## GitHub build — automated GitHub Actions

The workflow is `.github/workflows/main.yml`. It:
- installs Java 17 and the Android SDK components required by Godot 4.3;
- installs the matching Godot 4.3 export templates;
- configures the Android SDK/JDK paths for the headless Godot editor;
- creates a temporary Android debug keystore in the GitHub runner (it is not committed);
- exports a signed ARM64 debug APK and uploads it as `LastShelter-Android`.

Push to `main`/`master`, or run the workflow manually from the Actions tab. Download the APK from the run's Artifacts section.

## Important signing note

This workflow creates a **debug-signed APK for installation and testing**. It is not a Play Store release. Before publishing, create a private release keystore, store its values in GitHub Secrets, and configure a separate release-signing workflow. Never commit keystore files or passwords.

## Local export

Install Godot 4.3, matching export templates, OpenJDK 17, and the Android SDK components listed in the workflow. Configure Editor Settings → Export → Android with the Java SDK and Android SDK paths, then export the Android preset.

The first GitHub run still needs to complete successfully; this archive has not itself been run through Godot's Android exporter in this environment.
