# Building the Android APK

These steps take a clean computer to an APK that installs on Android 8.0 or newer. Everything used here is free.

## 1. Install the tools

### Godot 4.7

Download the standard version from <https://godotengine.org/download> and unzip it. On Windows, use the `_console.exe` file for command-line work, because the normal one prints nothing to a terminal.

### Java (OpenJDK 17)

| System | Command |
| --- | --- |
| Windows | `winget install EclipseAdoptium.Temurin.17.JDK` |
| macOS | `brew install --cask temurin@17` |
| Linux (Debian, Ubuntu) | `sudo apt install openjdk-17-jdk` |

This project's APK has also been built successfully with the JDK 21 that comes with Android Studio. If you already have that, you can try it first.

### Android SDK

The simplest route is [Android Studio](https://developer.android.com/studio). Open **Settings**, then **Languages & Frameworks**, then **Android SDK**, and install:

- **SDK Platforms:** Android 16 (API 36)
- **SDK Tools:** Android SDK Build-Tools, Android SDK Platform-Tools

Note the **Android SDK Location** shown at the top of that page.

### Export templates

1. Open the project in Godot.
2. Choose **Editor**, then **Manage Export Templates**.
3. Choose **Download and Install**.

## 2. Tell Godot where the tools are

Choose **Editor**, then **Editor Settings**, then **Export**, then **Android**, and set:

| Setting | Value |
| --- | --- |
| Java SDK Path | the JDK folder, the one containing `bin` |
| Android SDK Path | the SDK location from Android Studio |

Godot creates its own debug signing key the first time you need one.

## 3. Build a debug APK

Debug APKs are for testing on your own phones. In Git Bash on Windows, or a terminal elsewhere:

```
cp tools/local.env.example tools/local.env
```

Edit `tools/local.env` to point at your Godot binary if `godot` is not on your PATH. Then:

```
bash tools/export_android.sh debug
```

The script first proves that the exported game data is complete, then writes `build/sky-skirmish-debug.apk`.

## 4. Build the signed release APK

### Create a keystore, once

```
keytool -genkeypair -v -keystore sky-skirmish-release.keystore -alias skyskirmish -keyalg RSA -keysize 2048 -validity 10000
```

Choose a strong password when asked.

**Keep the keystore and its password private and backed up.** Never commit them or send them in a group chat: the repository's `.gitignore` blocks `*.keystore`, but only for files with that name. If the keystore is lost, phones with the app installed cannot receive updates signed with a new one.

### Build

In Git Bash, macOS or Linux:

```
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="/full/path/to/sky-skirmish-release.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="skyskirmish"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="your-password"
bash tools/export_android.sh release
```

The result is `build/sky-skirmish.apk`. Check its signature with the `apksigner` in your SDK's `build-tools` folder:

```
apksigner verify --min-sdk-version 26 --print-certs build/sky-skirmish.apk
```

## 5. Install on a phone

Either copy the APK to the phone and open it, allowing "install unknown apps" when asked, or use USB debugging:

```
adb install -r build/sky-skirmish.apk
```

## Before submitting

- Set `relay_url` in `data/tuning.json` to your deployed relay, following [RELAY_DEPLOY.md](RELAY_DEPLOY.md). Without it, the Online lobby says the server is not set up.
- When releasing an update, raise `config/version` in `project.godot` and `version/code` in `export_presets.cfg`. Both phones must run the same version to play together.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| "Godot not found" | Set `GODOT` in `tools/local.env` |
| Export says no export template found | Install the templates that match your exact Godot version |
| Export complains about Java or the SDK | Recheck the two paths in Editor Settings |
| "The exported game is incomplete" | A file the game needs is missing from the export. Check `include_filter` and `exclude_filter` in `export_presets.cfg` |
| "App not installed" on the phone | Uninstall any copy signed with a different key, then install again |
| On Windows, `bash` opens WSL | Run the commands from Git Bash instead of PowerShell |
