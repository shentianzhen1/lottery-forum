# Android 横屏测试包

状态：Android 平台文件已在 `main`。仓库里没有 APK。本环境安装了命令行 SDK，但 Gradle 进程中途退出，仍未生成包。

## 配置 Android SDK

安装 Android Studio 后，在 Android SDK 设置里勾选：

- Android SDK Platform，近期版本即可，例如 API 35。
- Android SDK Platform-Tools。
- Android SDK Build-Tools。
- Android SDK Command-line Tools。

然后：

```bash
flutter config --android-sdk "$HOME/Library/Android/sdk"
flutter doctor --android-licenses
flutter doctor
```

Linux 常见路径是 `~/Android/Sdk`，Windows 是 `%LOCALAPPDATA%\Android\Sdk`。`flutter doctor` 的 Android toolchain 通过后再构建。

也可以设置：

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
```

## 构建

先在另一终端启动 API：

```bash
uvicorn app.main:app --app-dir apps/api --reload
```

模拟器访问本机 API 的默认地址是 `http://10.0.2.2:8000`。

```bash
cd apps/mobile
flutter build apk --debug
```

产物在 `build/app/outputs/flutter-apk/app-debug.apk`。

## 验收

至少看 16:9 手机横屏和接近 16:10 的平板横屏。检查首页、积分中心、登录、弹窗、键盘、安全区域和返回后状态。未登录时积分中心应显示读取失败和重试。
