# 历史：1.2.0（50）候选包

已由 build51 简版 UX 替代；本页校验值只对应历史产物，不能用于当前上架。build51 编译会覆盖通用 iOS archive/ipa 路径。

同一 App/Bundle ID 的增量更新；恢复约 1.6 秒品牌组装动效，可立即进入并支持减少动态效果。人工选图仍完整保留。

## 当前验证

- 全量 209 项 Flutter 测试通过；原生格式/完整编辑及交付链路在 iPhone 与 Android 各两项通过。
- 安卓原发行签名与公开 v1.1.0 APK 的证书一致，SHA-256：`d27c0bd02d30bf67b1b66d833934a0ec806a5f22a1085839988551bd8616c87f`。
- Android 模拟器通过 `install -r` 从公版 1.1.0(49) 覆盖到 1.2.0(50)；UID 和首次安装时间保持，未在升级步骤卸载。该测试不冒充已有真实用户任务数据的恢复验证。

## 本地发行产物

- 正式签名 APK：`build/releases/1.2.0-50/app-release.apk`
- APK SHA-256：`6594b5f5c01cd95154264962c9a104a9adef011f0cb8530db84628ca3d69e2e2`
- 校验文件：`build/releases/1.2.0-50/SHA256SUMS`
- iOS 归档：`build/ios/archive/Runner.xcarchive`
- App Store IPA：`build/ios/ipa/photoid.ipa`，72290383 字节。
- IPA SHA-256：`abd362d89ff2d18a98806ac1543e0c9d6a5ec003fab6ebea4a937cfa299985f3`
- 已核对 IPA 版本 1.2.0、build 50、bundle/team、App Store 分发 profile（非开发或企业 profile），无测试 framework。
- 普通入口的开发签名归档 App 已通过签名校验，并在连接的 iPhone 上原位安装、启动；不是留下集成测试入口。
- GitHub 已建立 v1.2.0 发布草稿，附正式签名 APK 与 SHA256SUMS；公开 latest 仍为 v1.1.0，不触发旧用户自动更新。App Store 尚未上传/重新送审。

## 发布门槛

原生文件选择器授权、系统分享保存与 iPad 兼容模式尚需交互验收；当前 Mac iPhone 镜像重试失败，iPad 未连接。仅有 iOS 27 模拟器且现有 ML Kit 不支持 arm64 模拟运行，不能拿 widget 布局测试冒充 iPad 真机验收。

App Store Connect 在 2026-11-09 仍是 1.1.0(49) 拒审，最新沟通为 11 月 6 日用户询问；无新增 Apple 回复。新候选需要在原有应用版本记录中更新版本号、选择新构建及最终素材。4.3(a) 不因版本号或动效改变而自动解决，以实质找照片/要求/交付工作流和真实演示说明。
