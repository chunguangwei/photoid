# 1.2.0（51）简版候选包

2026-11-09，同一应用升级。代码提交 `e40736dbdfa3bf3c6ff20d47c92b8bdfc676551c`，文档后续提交不改变安装包。原有冷启动加载效果与 ce86365 一致，不新增或修改动效。

## 功能与验证

主路径：选 33 个常用规格或自定义尺寸/KB → 从相册批量或文件夹选照片 → 点图预览并制作。移除用户示例入口和前置建任务步骤，保留人工选图、拍照、记录及高级工具。

216 项 Flutter 测试通过，静态分析 No issues found。iPhone 原生处理 3 项通过，UI 因非前台跳过；Android 原生处理和简版 UI 4 项通过，[中英文工程图](device-captures-simple/README.md)已检查。原生选择器、iPad 和最终 Store 素材仍待交互验收。

## Android

- APK：`build/releases/1.2.0-51/app-release.apk`，178950293 字节。
- SHA-256：`9b21c4165d1fb2871cc743b51e0f915fda4b788f2c33f56c22a2c723b2aad384`。
- 原发行签名 SHA-256：`d27c0bd02d30bf67b1b66d833934a0ec806a5f22a1085839988551bd8616c87f`。
- versionName=1.2.0，versionCode=51。一次性模拟器从公开 1.1.0(49) `install -r` 覆盖升级通过，appId 与首次安装时间保持；不是已有真实用户数据恢复验收。

## iOS

- 归档：`build/ios/archive/Runner.xcarchive`。
- App Store 分发 IPA：`build/releases/1.2.0-51/photoid.ipa`，72306960 字节；通用导出路径 `build/ios/ipa/photoid.ipa`。
- SHA-256：`bf7ed6c938feaa62b1acd79e69fec716ca153ff2ce7a9c89e7ba83363f743d84`。
- 版本 1.2.0，build51；bundle `cn.wcg.idphoto`，Team `CCTFP9X3SW`；App Store 分发 profile 已核对，无测试 framework。
- 正常入口的开发签名归档 App 签名校验通过，已在连接 iPhone 上原位安装并启动。设备应用清单确认版本 1.2.0、bundleVersion 51；未卸载。
- 原始工作区用户 Info.plist 改动保留。

## 发布状态

GitHub v1.2.0 草稿替换为 build51 原签名 APK 与校验文件，并指向本次源码；公开 latest 保持 v1.1.0。未上传 App Store、未提交新审核、未发送申诉。不保证通过 4.3(a)；须完成原生交互和最终素材验收，再在原 App 记录中选择新包送审。
