# 1.1.0 (49) 验证记录

## 已验证

- 原基线 128 项测试通过，加入新功能后完整 153 项通过；合并回原项目 main 后再次运行 153 项通过，Dart 静态分析无问题。
- 只读检查：输入 JPEG 字节不变、实际尺寸/大小/比例、PNG 格式失败、损坏输入、30MB 文件与 24MP 像素上限。
- 任务：持久化恢复、并发添加、唯一/安全命名、最多五份输出、要求/源图改变失效、过期编辑拒绝保存、坏任务隔离、删除任务不删除外部原图。
- 交付：ZIP 内 JPEG 与保存字节一致，JSON 实际字节数与可读清单一致；缺失/损坏/未完成输出拒绝交付；生成期间串行锁定快照。
- 页面：新建任务、返回恢复、已保存要求再次编辑、Files 选择取消保留旧选择；原 ID Photo 按钮继续进入规格区；320px / 130% 字号、中英双语、深浅主题无布局异常。
- 独立源码复核发现两项 Important 与一项 Minor，均已修复并增加回归。
- `docs/ui-preview-1.1` 为 widget 渲染预览，不是真机或商店截图。

## 构建与外部状态

Android release 构建成功：1.1.0 / versionCode 49，minSdk 26、targetSdk 36，三架构通用包。apksigner 验证通过，沿用正式签名证书 SHA-256 d27c0bd02d30bf67b1b66d833934a0ec806a5f22a1085839988551bd8616c87f。APK 字节数 146007258，SHA-256 `1b60dc6f55ee4c9d3612935de5b8a9d1e7439e05dbd3227588c0891bd2d3a2a7`。最终合并清单没有多余麦克风、音频、视频或通知权限。

iOS release 构建成功：cn.wcg.idphoto / 1.1.0 (49)，108.2MB。已覆盖安装 iPhone 13，设备端版本确认是 1.1.0 (49)，未卸载。电脑端 codesign --verify --deep --strict 通过；与旧版使用相同开发证书、团队、entitlements 与未过期且包含该设备的 profile。最初启动曾被 iOS Security 拒绝；用户确认安装后，再次通过 devicectl 启动成功。该结果只确认启动，不代表完整真机流程验收。

本机产物保存在原项目 build/releases/1.1.0/：app-release.apk、SHA256SUMS、Runner.app。Runner.app 为真机开发签名包，不是 App Store 分发 IPA。

完整的系统文件选择器、真实照片推理、相机授权、Photos 保存、系统分享与 ZIP 解压、离线与 iPad 兼容模式仍需设备验收，不能用模型/单元测试替代。2026-10-23 已在原 ASC 记录读取消息（无新回复），已通过 Xcode 上传 1.1.0 (49)，尚未重新提交审核，未完成系统性竞品差异验证，不保证 4.3 审核结果。2026-10-23 已授权发布 GitHub v1.1.0，使用本记录校验的 APK；发布结果见 https://github.com/chunguangwei/photoid/releases/tag/v1.1.0 。

源码功能提交：`2907acf`。本机原有 Info.plist 的重排改动保留，未纳入功能提交。

2026-10-23：正式 IPA 导出与上传成功，App Privacy 已按随包 SDK 清单发布修正。详见 submission-status-2026-10-23.md；新截图和系统交付流程验收仍待完成。
