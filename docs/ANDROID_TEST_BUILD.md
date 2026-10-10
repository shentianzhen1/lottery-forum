# Android 横屏测试包

状态：构建步骤。本环境没有 Flutter，仓库里也还没有生成 APK。

## 准备

```bash
cd apps/mobile
flutter pub get
flutter create --platforms=android .
```

`flutter create` 只补 Android 平台文件，不覆盖 `lib/`。

## 横屏

在 `android/app/src/main/AndroidManifest.xml` 的 `activity` 上设置：

```xml
android:screenOrientation="sensorLandscape"
```

这只锁定测试包方向。主要页面仍以横屏布局验收，不能靠旋转代替。

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
