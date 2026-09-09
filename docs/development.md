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
│   ├── home_page.dart        # 主页骨架：底部 NavigationBar 双 Tab
│   │                         #   （首页 / 我的，IndexedStack）；首页 Tab =
│   │                         #   品牌渐变头→2×2 主功能大卡（拍证件照/换底色/
│   │                         #   改KB/我的相册）→次级小工具（自定义规格）→
│   │                         #   隐私横幅→搜索→热门锚点规格→「全部规格(33)」
│   │                         #   折叠区
│   ├── settings_page.dart    # 「我的」Tab：我的相册入口 + 检查更新(Android)
│   │                         #   + 隐私说明 + 关于（版本/许可/邮箱）
│   ├── camera_page.dart      # 拍摄：前后置切换 + 人像轮廓虚线参考框
│   ├── edit_page.dart        # 编辑：流水线步骤进度 + 五色底色 chips
│   │                         #   （切换即重跑）+ 原图/效果对比
│   ├── result_page.dart      # 结果：合规检测报告 + 保存
│   ├── spec_detail_page.dart # 规格详情：三栏参数卡 + 五色底色选择
│   │                         #   （默认色带「· 推荐」标记）+ 要求清单
│   │                         #   + 底部上传/拍摄双按钮
│   ├── custom_spec_page.dart # 自定义规格
│   ├── kb_tool_page.dart     # 改 KB 工具
│   ├── my_album_page.dart    # 我的相册
│   └── update_dialog.dart    # 升级对话框：下载 APK → FileProvider 安装
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
ImagePipeline（edit_page 触发；步骤枚举 PipelineStep 共 6 项，UI 逐条映射 l10n 进度文案）
  ① preparing   UI 初始态（run() 开始前由 EditPage 展示，流水线本身不回调）
  ② reading     解码 + 按 EXIF 旋转归一化（img.bakeOrientation）→ 工作分辨率原图（最长边 1440）
  ③ segmenting  ML Kit Selfie Segmentation 人像分割（端侧）
  ④ compositing 按所选五色底逐像素 alpha 混合（compute 隔离），掩码羽化（高斯模糊 r=3）
  ⑤ framing     ML Kit Face Detection 定位人脸 → 自动构图（头部约占 62%、顶部留白 10%，
                画幅不足处以底色**方向性扩边补齐**——仅向越界方向 pad，
                避免全向扩边的百 MB 级内存峰值）→ 按规格像素精确裁剪
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

错误与进度同样以语义标识传递：`PipelineException.code`（readPhoto / noPerson /
noFace 等）和 `PipelineStep` 枚举，由 UI 层翻译展示。

**ML Kit 输入双平台分路（`_inputImage`）**：流水线的分割与人脸检测共用同一份
工作图写出的临时 jpg（无 EXIF，保证掩码/人脸框坐标对齐），但构造
`InputImage` 时按平台分路——

- **Android**：`InputImage.fromFilePath` 不挂 `MediaImage`，ML Kit 原生层处理
  时 NPE（已知 bug），故改走 `InputImage.fromBytes`：工作图 RGBA 经
  `_rgbaToNv21`（BT.601 全幅转换、2×2 色度子采样，在 `compute` isolate 内
  执行）转为 NV21 字节流，附 `InputImageMetadata`（尺寸 / rotation0deg /
  `InputImageFormat.nv21`）。**奇数宽/高修复**：色度平面尺寸按
  `ceil(w/2)×ceil(h/2)` 分配，否则 `RangeError`。合规检测的人脸项在
  Android 同样走 NV21（`_faceChecks` 复用 `rgbaToNv21`），iOS 仍写临时
  jpg 后 `InputImage.fromFile`。
- **iOS**：`InputImage.fromFile` 工作正常，保持原路径不转码。

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
`detail` 为实测值（如「486KB」）。底色检测（id 沿用 `blueBg` 历史名，但
**逻辑已泛化**）：四角 8% 区域均值（短边比例取样防越界采到黑像素）→ RGB
转 HSV → 与 `spec.background` 目标色按容差比对，分两分支——

- **低饱和目标**（白/灰，S ≤ 0.25）：实测 S ≤ 0.35 且明度差 ≤ 0.25；
- **彩色目标**（蓝/红/深蓝）：色相环形差 ≤ 20°、实测 S > 0.2 且明度差
  ≤ 0.3。

UI 文案经 `Tr` 按目标色名输出：`checkBgColor({bg})` / `fixBgMismatch({bg})`。

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

双触发：
- **自动**：`main.dart` 启动 3 秒后 `Timer` 静默检查一次，有新版本弹
  `showUpdateDialog`；
- **手动**：`settings_page.dart`「检查更新」入口（仅 Android 显示），
  无更新时 snackbar 提示「已是最新」，有更新弹升级框。

下载与安装在 `update_dialog.dart`：「立即更新」后流式下载 APK 到临时目录，
经 `open_filex`（FileProvider）触发系统安装。

### HomePage（lib/pages/home_page.dart）
主页骨架为底部 `NavigationBar` 双 Tab（首页 / 我的，`IndexedStack` 保持
两页状态）。**首页 Tab** 自上而下：品牌渐变头（appTitle + privacySlogan）
→ 2×2 主功能大卡（拍证件照→滚动定位到热门规格区，规格即拍摄入口；换底色
→以 `studentPhotoSpec` 进相册选图复用流水线；改 KB；我的相册）→ 次级小工具
（自定义规格）→ 黄色隐私横幅（锁图标 + 隐私文案）→ 搜索框 → 近期热门
（🔥 图标；`_hotIdKeys` 锚定 student / one_inch / two_inch / cet_english /
gaokao，**按锚点顺序各取一条**，学生照置顶，避免被寸照变体挤占；无匹配则取
列表前 5）→ 「全部规格(N)」ExpansionTile 默认折叠。非搜索态下学生报名照
（`studentPhotoSpec`）置顶进入规格流。搜索时整列表按名称过滤替换热门区。
相册选图统一 `imageQuality: 99`（Android quality=100 按字节拷贝原文件，
HEIC 会漏入；99 强制转 JPG 且质量损失可忽略）。

### SettingsPage（lib/pages/settings_page.dart）
「我的」Tab：我的相册入口 → 检查更新（`Platform.isAndroid` 才显示）→
隐私说明 → 关于区（版本号取自 `PackageInfo` / 许可 / 联系邮箱）。

### CameraPage（lib/pages/camera_page.dart）
拍摄页：实时预览 + 半透明遮罩 3:4 取景框 + **人像轮廓虚线参考框**
（CustomPainter：头部圆 + 颈肩剪影虚线，头部约占框高 40%、肩部展开至框宽
62%，替代旧版椭圆参考线）；前后置切换按钮（`_cameras.length > 1` 才显示，
默认后置，面向家长替孩子拍摄场景），切换时释放旧控制器按新镜头方向重建。

### SpecDetailPage（lib/pages/spec_detail_page.dart）
规格详情：三栏参数卡（像素尺寸 / DPI 300 / 文件大小区间）→ 五色底色选择
`ChoiceChip` 区（`idPhotoBackgrounds` 顺序：蓝/白/红/灰/深蓝；规格默认色带
「· 推荐」标记）→ 要求清单（经 `Tr.requirements` 翻译）。选中底色替换
`_spec.background` 后贯穿拍摄与上传；底部「上传照片」/「立即拍摄」双按钮。

### EditPage（lib/pages/edit_page.dart）
处理页：按 `PipelineStep` 枚举逐步展示流水线进度；五色底色 chips 切换后
携带新底色重跑流水线；`PipelineResult.original` / `processed` 支撑
原图/效果对比。

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

iOS 已加入隐私清单 `ios/Runner/PrivacyInfo.xcprivacy`，声明四类受访问
API：UserDefaults（CA92.1）、FileTimestamp（C617.1）、DiskSpace（E174.1）、
SystemBootTime（35F9.1），满足 App Store 隐私清单要求。

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

### 8.1 release 正式签名（Android）

release 构建的签名由 `android/key.properties` 控制（`build.gradle.kts`）：

```properties
storeFile=/Users/<you>/.android/photoid-release.keystore
storePassword=******
keyAlias=photoid
keyPassword=******
```

- `key.properties` **本地存放、gitignored**，四个字段：`storeFile` /
  `storePassword` / `keyAlias` / `keyPassword`。
- 文件存在 → release 用正式 keystore（`~/.android/photoid-release.keystore`）
  签名；**不存在 → 回退 debug 签名（仅限本地调试，不可分发）**。
- ⚠️ **keystore 与密码必须备份**（keystore 文件 + key.properties 各存一份
  异地）。应用内自升级是**同签名覆盖安装**——签名断裂（keystore 丢失、
  误用 debug 包发布）= 老用户无法升级，只能卸载重装，相册数据一并丢失。
- 换签名（新 keystore）对存量用户等效于签名断裂：**需用户卸载重装一次**。

### 8.2 发布步骤

Android 端应用内自升级完全依赖 GitHub Release。⚠️ **铁律：`pubspec.yaml`
的 `version`（应用内显示与比较基准）必须与 Release tag 严格对齐**——tag 是
远程版本唯一来源，pubspec 是本地版本唯一来源，两者不一致会导致
`isNewer()` 比较失准，已发版本被反复提示升级（v0.1.0 vs v0.2.0 教训：
发布新版本前 pubspec 忘了同步抬版本，旧包用户收到的「最新版」比较基准错乱，
形成升级循环）。发布步骤：

1. **先改 `pubspec.yaml` 版本号**：`version: X.Y.Z+N`（如 `0.2.0+2`）——
   应用内显示的当前版本取自这里（`PackageInfo`），升级比较是
   `Release tag` 对该版本做分段数字比较，远程必须**严格大于**它。
   发布 v0.2.0 前 pubspec 必须先写到 `0.2.0+2`，与 tag 对齐。
2. 构建 APK：`flutter build apk --release`（构建前确认 `key.properties`
   就位，见 8.1——误出 debug 签名包会导致老用户无法覆盖升级）。
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
- [product.md](product.md) — 当前产品文档（定位/功能/规格体系/合规检测）
- [CONTRIBUTING](../CONTRIBUTING.md) — 贡献指南
- [LICENSE](../LICENSE) — 非商业许可证（个人免费，商用需书面授权）
