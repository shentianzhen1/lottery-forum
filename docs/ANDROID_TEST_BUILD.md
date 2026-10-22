# Android 横屏测试包

状态：仓库不提交 APK 二进制。`Android debug APK` 工作流新增实际构建与 artifact 上传；以具体 Actions 运行结果为准，不能仅凭配置声称已出包。构建成功仍不代表真机验收通过。

## 工具链与自动构建

本流程固定 Flutter 3.24.5、Java 17、AGP 8.1.0、Gradle 8.3、Kotlin 1.8.22，与 Flutter 3.24.5 的 Gradle 模板版本对齐。保留现有 Kotlin DSL，不重新生成 Android 项目。原 AGP 9.1/Gradle 9.3/Kotlin 2.4 配置不能当成 Flutter 3.24.5 已验收工具链。

涉及 mobile 或工作流的 PR，以及这些文件进入 main 的 push，都会自动构建 USB 地址测试包（`http://127.0.0.1:8000`）。在 GitHub Actions 的对应运行页下载 `android-debug-<run_id>` artifact，解压后含 APK、构建 SHA/API 地址记录和 SHA256SUMS；保留 7 天。PR 运行记录的 SHA 可能是 GitHub 测试合并提交，不是分支 HEAD。设备验收优先使用 main 的成功 push 构建，并核对 build-info.txt 中的提交与目标 main 一致；仅后端或文档变化不会触发 APK 重编译。

工作流进入默认分支后，可在 Actions → Android debug APK → Run workflow 中选择 USB 或模拟器地址；未进入默认分支前手动入口可能不可见。自动 PR 构建不依赖手动入口，不发布 Release、不上传商店，也不需要正式签名密钥。

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

## 真机通过 USB 连接本地 API

API 地址可通过构建参数 `API_BASE_URL` 指定，无需改源码；默认仍为模拟器地址。地址必须包含 `http://` 或 `https://`，不要带结尾 `/` 或 `/api/v1`，API 客户端会自行追加路径。该地址不是密钥，不要把凭据放入参数。

1. 手机启用 USB 调试，连接电脑并完成设备授权。
2. 在电脑启动 API（上面的 uvicorn 命令），在电脑浏览器检查 `http://127.0.0.1:8000/health`。
3. 执行 `adb devices` 确认设备，然后建立端口映射：

```bash
adb reverse tcp:8000 tcp:8000
```

4. 在 `apps/mobile` 目录构建并安装真机测试包：

```bash
flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:8000
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

多设备时为 adb 命令加 `-s <serial>`。USB 重连后可能需要重新执行 reverse。`127.0.0.1` 配合 reverse 才指向电脑；真机不能沿用模拟器的 `10.0.2.2`。测试结束可用 `adb reverse --remove tcp:8000` 移除映射。

地址在构建时确定，变更后需要重编译并重装。通过局域网连接时须使用电脑可达地址，单独检查 API 监听地址与防火墙，不要把开发服务直接暴露到公网。

明文 HTTP 仅在 debug manifest 中放行，便于本地开发；main/profile manifest 未新增明文许可。正式环境应使用 HTTPS。本次代码配置不等于已验证 APK、Android manifest 合并或设备连通。

## 配置回归

```bash
flutter test test/api_config_test.dart
flutter test test/api_config_test.dart --dart-define=API_BASE_URL=http://127.0.0.1:8000 --dart-define=EXPECTED_API_BASE_URL=http://127.0.0.1:8000
```

## 验收

至少看 16:9 手机横屏和接近 16:10 的平板横屏。检查首页、积分中心、登录、弹窗、键盘、安全区域和返回后状态。未登录时积分中心应显示读取失败和重试。

记录设备、提交 SHA、逻辑宽高、网络方式、截图和实际余额变化。当前页面门槛为 960 逻辑像素，手机横屏可能仍被拦截；本次不改变该门槛，也不把横屏验收标成完成。
