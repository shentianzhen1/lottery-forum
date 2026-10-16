# Android 横屏测试包

状态：Android 平台文件已在 `main`。仓库不提交 APK 二进制；可在本机或 CI 执行 `flutter build apk --debug` 出包。部分受限环境曾因内存不足导致 Gradle 中途退出，属环境备注，不代表流程不可用。

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

## 真机连接前置条件（尚未验收）

当前 `lib/api/api_config.dart` 默认地址固定为 `http://10.0.2.2:8000`，仅适用于 Android 模拟器；当前没有 `--dart-define` 地址配置入口，传入该参数不会改变地址。

USB 真机本地调试可按以下方式准备（尚无成功执行记录）：

1. 在本地测试工作副本中把 `ApiConfig` 默认地址改为 `http://127.0.0.1:8000`，然后重新构建 debug APK。不要提交个人局域网 IP。
2. 手机开启 USB 调试并连接电脑，执行 `adb devices` 确认设备已授权；多设备时给下面命令加 `-s <serial>`。
3. 在电脑启动上述 API，执行 `adb reverse tcp:8000 tcp:8000`。端口映射使手机访问 `127.0.0.1:8000` 到达电脑 API；它不会让硬编码的 `10.0.2.2` 地址生效。
4. 安装测试包并核对 `/health` 与客户端接口请求。若日志出现明文 HTTP 被阻止，需单独配置仅用于本地 debug 的网络策略，不能把未验证的网络连接算通过。

后续应增加可配置 API 地址并验证 debug 网络访问，再交付无需修改源码的真机测试包。当前 CI 只有 API 测试、Flutter analyze/test，不包含 Gradle 构建、APK 上传或设备测试。

## 业务验收记录要求

每次记录提交 SHA、设备型号、系统版本、屏幕逻辑宽高（Flutter 布局使用逻辑像素）、网络方式、操作截图与结果。当前横屏门槛为逻辑宽度 960，不能用截图物理宽度代替；手机横屏仍可能进入窄屏提示，需要真机验证后再决定适配方案。

- 注册/登录：新账号初始余额 100；退出后不能查询他人积分或投注。
- 选号/冻结：数字选号、福建31选7与任选2/3/4/5各一笔，核对固定注额 10、可用余额减 10、冻结增加 10。
- 取消：OPEN 期内取消本人 ACCEPTED 单，冻结释放；重复取消不能重复解冻；截止后取消应失败。
- 结算：使用带版块的期号与管理员分别验 WIN/LOSS/VOID；WIN 由版主可用余额付盈利，门槛冻结池不变；重复 finalize 不重复记账。客户端没有完整结算操作台，不能要求普通玩家自行写结算。
- 积分中心：切换页面后核对余额、冻结和明细；若与 API 不符，登记问题，不手工改账。
- 横屏：16:9 手机和 16:10 平板检查导航、选号区、键盘、弹窗、安全区域、返回与刷新；无真实设备记录前不标记通过。
- 公告：main 只验首页列表；详情页面需在 PR #65 对应代码上单独验，合入前不能混用验收结论。
