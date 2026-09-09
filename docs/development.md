# PhotoID 开发文档（Development Guide）

面向贡献者与维护者的架构与流程说明。用户-facing 介绍见 [README](../README.md)。
English readers: the codebase comments and ARB sources are authoritative; this
doc mirrors them in Chinese.

- 技术栈：Flutter 3.47.2（Dart ^3.5.0）
- 端侧 AI：Google ML Kit（Selfie Segmentation + Face Detection）
- 图像处理：`image` 包（像素级合成与缩放）
- 平台：Android 8.0+（minSdk 26）/ iOS 15.5+
- 仓库：https://github.com/chunguangwei/photoid
- 联系：chunguangwee@gmail.com

---

## 1. 项目结构

```
lib/
├── main.dart                 # 入口：MaterialApp + 本地化 + 更新检查
├── models/
│   └── photo_spec.dart       # PhotoSpec / SpecBackground 模型、五色底常量、学生报名照规格
├── services/                 # 纯逻辑层，不依赖 BuildContext（可单测）
│   ├── image_pipeline.dart   # 处理流水线：抠图→换底→构图→压缩
│   ├── compliance_service.dart # 合规检测引擎
│   ├── spec_library.dart     # 内置规格库加载/搜索（assets/photo_specs.json）
│   ├── album_service.dart    # 本地相册（保存/列表/删除）
│   └── update_service.dart   # GitHub Release 自升级检查
├── pages/                    # UI 层（依赖 BuildContext 做 i18n）
│   ├── home_page.dart        # 首页：规格列表/搜索
│   ├── camera_page.dart      # 拍摄
│   ├── edit_page.dart        # 编辑：换底/预览/触发流水线
│   ├── result_page.dart      # 结果：合规检测报告 + 保存
│   ├── spec_detail_page.dart # 规格详情与要求说明
│   ├── custom_spec_page.dart # 自定义规格
│   ├── kb_tool_page.dart     # 改 KB 工具
│   ├── my_album_page.dart    # 我的相册
│   └── update_dialog.dart    # 升级对话框
├── l10n/                     # 国际化
│   ├── app_zh.arb / app_en.arb        # 翻译源（唯一真源）
│   ├── app_localizations*.dart        # flutter gen-l10n 生成物（勿手改）
│   └── l10n_helpers.dart              # Tr 翻译层（语义标识 → l10n 键）
assets/
└── photo_specs.json          # 33+ 条内置规格
test/                         # 服务层单测（image_pipeline / compliance 间接、
                              # spec_library、album_service、update_service、update_dialog）
```

分层约定：`services/` 与 `models/` 是**纯 Dart**（不 import flutter material、
不碰 BuildContext），全部文案以稳定语义标识输出；本地化由 `pages/` 层通过
`Tr` 完成。这保证服务层可脱离平台单测。

## 2. 核心流程

```
拍摄(camera) / 相册上传(image_picker)
        │
        ▼
ImagePipeline（edit_page 触发）
  ① preparing   EXIF 归一化 → 工作分辨率原图
  ② reading     解码为 image.Image
  ③ segmenting  ML Kit Selfie Segmentation 人像分割（端侧）
  ④ compositing 按所选五色底逐像素 alpha 混合（compute 隔离）
  ⑤ framing     ML Kit Face Detection 定位人脸 → 自动构图 → 按规格像素精确裁剪
  ⑥ compressing 二分压缩 jpg，落到规格的 [minFileKb, maxFileKb]
        │
        ▼
ComplianceService（result_page 触发）
  对最终 jpg 逐项检测：format / fileSize / decodable / pixelSize /
  bestSize / ratio / blueBg / faceDetected / headRatio / headCentered / eyesOpen
  （soft 项不通过不阻断保存）
        │
        ▼
保存（result_page / my_album）
  AlbumService 写应用私有目录；gal 可选保存到系统相册；
  学生报名照按教育 ID 命名文件
```

错误与进度同样以语义标识传递：`PipelineException.code`（noFace 等）和
`PipelineStep` 枚举，由 UI 层翻译展示。

## 3. 关键类说明

### PhotoSpec（lib/models/photo_spec.dart）
证件照规格模型，JSON 可反序列化。字段：`id / name / pixelWidth /
pixelHeight / minFileKb / maxFileKb / minWidth / maxWidth / minHeight /
maxHeight / minRatio / maxRatio / background(SpecBackground) / requirements`。
`SpecBackground` 为 `name + RGB`。文件内还定义五色常量
（`idPhotoBlue/White/Red/Gray/DarkBlue`，`idPhotoBackgrounds` 即 UI 顺序）与
内置学生报名照 `studentPhotoSpec`（id: `student_edu_id`，480×640）。

### ImagePipeline（lib/services/image_pipeline.dart）
处理流水线核心。对外返回 `PipelineResult`（最终 jpg 字节 + 原图/成片
`image.Image` 供对比预览）。步骤枚举 `PipelineStep` 用于进度展示；
`PipelineException` 携带语义化 `code`。重像素运算（合成）放入 `compute`
避免卡 UI。全流程无网络请求。

### ComplianceService（lib/services/compliance_service.dart）
对**最终 jpg 字节**做合规检测。产出 `ComplianceReport`（`List<CheckItem>`），
`hardAllPass` 表示硬性项全过。`CheckItem.id` 是稳定语义标识
（format/fileSize/…/eyesOpen），`fixId` 是修复建议标识，`soft` 标记软指标；
`detail` 为实测值（如「486KB」）。底色检测通过四角采样 + HSV 判断。

### SpecLibrary（lib/services/spec_library.dart）
内置规格库访问入口。`load()` 从 `assets/photo_specs.json` 解析并缓存；
`search(keyword)` 按名称过滤。纯端侧，无网络。

### AlbumService（lib/services/album_service.dart）
本地相册：成片双写一份到应用私有目录（`<documents>/album`），文件名
`{yyyyMMdd_HHmmss}_{baseName}.jpg`，`baseName` 通常为教育 ID 或原图名；
`list()` 按修改时间倒序，`delete(path)` 按路径删除。系统相册写入由
`gal` 完成（在 result_page 中调用）。

### UpdateService（lib/services/update_service.dart）
GitHub Release 自升级。`checkUpdate()` 请求
`api.github.com/repos/chunguangwei/photoid/releases/latest`（15s 超时），
`parseRelease()` 解析出版本号（去 v 前缀）、APK 下载地址、release notes、
是否强制更新；`isNewer()` 做分段数字 semver 比较。**仅 Android**：
iOS 直接返回 null（走 App Store）。静默失败——任何异常返回 null 不打扰用户。

## 4. i18n 架构

```
lib/l10n/app_zh.arb / app_en.arb        # 翻译源（唯一真源，唯一可编辑）
        │  flutter gen-l10n（l10n.yaml 配置，构建时自动生成）
        ▼
AppLocalizations（app_localizations*.dart，生成物勿手改）
        │  页面层直接取用；服务层/模型层不依赖它
        ▼
Tr（lib/l10n/l10n_helpers.dart）
        服务层与规格模型输出的语义标识（PipelineStep、PipelineException.code、
        CheckItem.id/fixId、底色名、规格 requirements）→ l10n 键的映射层
```

规则：
- 新增 UI 文案：只改 ARB 文件（中英两份），运行 `flutter gen-l10n` 或热重载生成。
- 服务层/模型层**不 import flutter material**；输出语义标识，由 pages 层
  `Tr.of(context).checkLabel(...)` 翻译。语义标识改动会破坏翻译映射，视为接口变更。
- 规格名/底色名等模型层中文数据，在 `Tr` 中按需映射（如 `student_edu_id`）。

## 5. 添加新规格

规格存放在 `assets/photo_specs.json`（数组，33+ 条），模型为 `PhotoSpec`：

```json
{
  "id": "one_inch",            // 唯一标识（snake_case）
  "name": "一寸",               // 展示名
  "pixelWidth": 295,           // 成片宽（px）
  "pixelHeight": 413,          // 成片高（px）
  "minFileKb": 0,              // 文件大小下限（KB）
  "maxFileKb": 10240,          // 文件大小上限（KB）
  "minWidth": 295, "maxWidth": 295,    // 允许像素宽范围
  "minHeight": 413, "maxHeight": 413,  // 允许像素高范围
  "minRatio": 1.35, "maxRatio": 1.45,  // 高/宽比例范围
  "background": { "name": "蓝底", "r": 67, "g": 142, "b": 219 },
  "requirements": ["冲印尺寸 25×35mm", "最佳尺寸 295×413 像素"]
}
```

新增条目追加到数组即可，`SpecLibrary.load()` 启动时自动加载。若规格需要
双语名称，在 `Tr` 中按 `spec.id` 增加映射。

## 6. 构建与运行

```bash
flutter pub get
flutter run                     # 调试运行（连接设备/模拟器）

# Android 发布
flutter build apk --release     # build/app/outputs/flutter-apk/app-release.apk

# iOS（需 macOS + Xcode；--no-codesign 仅构建不签名）
flutter build ios --no-codesign
```

注意：`flutter_launcher_icons` 在 pub get 时刷新图标（assets/icon.png，
Android adaptive 背景色 #2B6CB0）。

## 7. 测试

```bash
flutter test            # 全部单测
flutter analyze         # 静态检查
```

现有测试（`test/`）：`photo_spec_test`（JSON 反序列化）、
`image_pipeline_test`、`update_service_test`（含 parseRelease / isNewer）、
`update_dialog_test`、`album_service_test`。新逻辑优先写在 services 层并配套单测。

## 8. 发布流程（GitHub Release 自升级）

Android 端应用内自升级完全依赖 GitHub Release，发布步骤：

1. **同步版本号**：`pubspec.yaml` 的 `version: X.Y.Z+N`（如 `0.2.0+2`）——
   应用内显示的当前版本取自这里（`PackageInfo`），升级比较是
   `Release tag` 对该版本做分段数字比较，远程必须**严格大于**它。
2. 构建 APK：`flutter build apk --release`。
3. 提交并打 tag：`git tag vX.Y.Z`（如 `v0.2.0`）并推送——**远程版本号取自
   tag 名**（自动去掉 `v` 前缀），故 tag 与 pubspec 版本保持一致。
4. 在 GitHub 上基于该 tag 创建 Release：
   - Release 正文（body）即应用内展示的 release notes；
   - **必须上传 APK 作为 Release asset**（文件名含 `apk`，大小写不敏感），
     `UpdateService` 取第一个匹配的 asset 作为下载地址；无 APK asset 时
     升级检查返回 null；
   - `isForceUpdate` 目前固定为 `false`（预留字段，未实现强制更新逻辑）。
5. iOS 不发 APK：`UpdateService` 在 iOS 直接返回 null，走 App Store 流程。

版本比较规则：按 `.` 分段取各段前导数字比较，远程版本必须严格大于当前
版本才提示更新（`1.2` == `1.2.0`，`3-beta` 视为 `3`）。

---

## 相关文档

- [README](../README.md) — 项目介绍与功能列表
- [CONTRIBUTING](../CONTRIBUTING.md) — 贡献指南
- [LICENSE](../LICENSE) — 非商业许可证（个人免费，商用需书面授权）
