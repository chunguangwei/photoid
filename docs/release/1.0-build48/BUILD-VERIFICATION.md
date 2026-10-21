# 发布验证记录

2026-10-21，Flutter 3.47.2。

- 最终全量测试：128 项通过。
- `dart analyze`：No issues found。`git diff --check` 通过。
- Android：`flutter build apk --release --no-pub` 成功；cn.wcg.photoid，1.0.0，versionCode 48，minSdk 26，targetSdk 36。通用 APK 包含 arm64-v8a / armeabi-v7a / x86_64。
- APK 字节数：143989826。SHA-256：`fd7cf1cd42ffa8bcbc5ffd313dd0148c055d87131b6f8a2585636446a5a4ace8`。
- 正式签名证书 SHA-256：`d27c0bd02d30bf67b1b66d833934a0ec806a5f22a1085839988551bd8616c87f`；apksigner verify 通过。
- 最终合并清单不含 RECORD_AUDIO、READ_MEDIA_AUDIO、READ_MEDIA_VIDEO 和 POST_NOTIFICATIONS；camera.any 可选。
- iOS 最终归档成功：cn.wcg.idphoto，1.0.0 (48)。分发导出失败，原因为 Xcode No Accounts / 缺少 iOS Distribution 身份；签名信任验证未通过。旧 IPA 已隔离，不是最终上传包。
- 原图处理、SDK、Swift 辅助功能通道已编入归档；未完成系统相册/相机/分享/离线与 iPad 兼容模式验收。
- iPhone 自动化 VM Service 连接被重置；Android 未连接设备，未测试实际覆盖安装。
- 20 张 UI 本地渲染预览已保存到 docs/ui-preview-2026-10-21；不作为真机商店截图。

GitHub Android 发布与 App Store 送审分开；本轮未上传或提交 App Store。
