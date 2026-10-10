# Android 横屏测试包

状态：Android 平台文件已生成。本环境没有 Android SDK，所以还没有 APK。

## 准备

Android 平台文件已在 `apps/mobile/android`。测试包默认横屏：`android:screenOrientation="sensorLandscape"`。

需要本机安装 Flutter 和 Android SDK。

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
