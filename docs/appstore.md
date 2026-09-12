---
layout: default
title: App Store 上架
---

# iOS 海外上架准备（App Store）

面向**英语系国家**（美、加、英、澳、新西兰、新加坡等）上架，不含中国大陆区
——大陆区需要软著与 ICP 备案号，海外区不需要，这是选择海外先行的主要原因。

- Bundle ID：`cn.wcg.photoid`
- Team：`L35RLT89XN`
- 最低系统：iOS 15.5
- 上架版本：v0.8.1（build 43）
- 包体：Runner.app 约 106MB（含 26MB MODNet 模型）

---

## 1. 已完成（代码侧）

- [x] 部署目标 iOS 15.5（project.pbxproj ×3 + AppFrameworkInfo.plist）
- [x] 应用内中英双语（`lib/l10n`，跟随系统语言）
- [x] **应用名本地化**：en → `PhotoID`，zh-Hans → `智能证件照`（InfoPlist.strings）
- [x] **权限文案本地化**：三条 `UsageDescription` 的中英两版均已就位
- [x] `PrivacyInfo.xcprivacy`：`NSPrivacyTracking=false`、采集数据类型为空，
      已申报 UserDefaults / FileTimestamp / DiskSpace / SystemBootTime 四类
      Required Reason API
- [x] 出口合规：`ITSAppUsesNonExemptEncryption = false`（仅用系统加密）
- [x] 全端侧处理、无数据上传（隐私问卷可全部答 "Data Not Collected"）
- [x] **收窄为 iPhone 专用 + 锁定竖屏**（v0.8.1 已实施）：
  `TARGETED_DEVICE_FAMILY = "1"`（pbxproj ×3）、`Info.plist` 只留
  `UIInterfaceOrientationPortrait` 且删除 `~ipad` 键、`main()` 已加
  `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])`。
  从此无需提供 iPad 截图，审核员也不会在横屏下实测。
- [x] 亮/暗双主题（跟随系统）+ iOS 确认弹窗 Cupertino 自适应（v0.8.1）

> **权限文案本地化为什么是硬要求**：`Info.plist` 里的 `UsageDescription` 是
> 硬编码中文时，英文系统用户会看到中文权限弹窗，属于 Guideline 5.1.1 的
> 常见拒审点。必须靠 `en.lproj/InfoPlist.strings` 覆盖。

## 2. 待办（代码侧）

- [ ] 确认 App 名称在目标区域未被占用（`PhotoID` 是常见词，很可能已被注册）。
      App Store Connect 创建 App 时若提示重名，需换显示名，例如
      `PhotoID - ID Photo Maker`。**Bundle ID 一经创建不可更改**，名称可改。

## 3. 待办（App Store Connect 侧）

- [ ] Apple Developer Program 账号（$99/年）；**Xcode → Settings → Accounts
      登录该 Apple ID**——当前机器未登录，导致 `flutter build ipa` 无法导出
      签名 IPA（archive 已构建成功，登录后直接在 Xcode Organizer 分发即可）
- [ ] App Store Connect 创建 App，**Availability 只勾选目标英语区**
- [ ] 隐私政策 URL：`https://chunguangwei.github.io/photoid/privacy-policy`
      （GitHub Pages 已启用，见 §5）
- [ ] **支持 URL（必填）**：`https://chunguangwei.github.io/photoid/`
      （GitHub Pages 首页）或仓库 README 页
- [ ] 类别：**Photo & Video（主）** / Utilities（副）
- [ ] 版权：`© 2026 chunguangwei`
- [ ] 隐私问卷：全部选 "Data Not Collected"
- [ ] 年龄分级：按当前问卷如实填写（无 UGC、无网络内容、无广告 SDK，
      预期最低档 4+）
- [ ] 截图（见 §4）
- [ ] 导出 IPA 上传（见 §8）→ 提交审核

## 4. 截图规格

App Store 要求按**当前 App Store Connect 页面提示为准**（Apple 会调整）。
截至目前，iPhone 必交的是这两档，其余尺寸由 Apple 自动缩放：

| 档位 | 分辨率（竖屏） | 对应机型 |
|---|---|---|
| 6.9" | 1320×2868 或 1290×2796 | iPhone 16 Pro Max / 15 Pro Max |
| 6.5" | 1242×2688 或 1284×2778 | iPhone 11 Pro Max / XS Max |

每档 3–10 张，建议 5 张，中英各一套（对应 en-US 与 zh-Hans 两个本地化）。
**需在真机上跑 App 实截**（模拟器缺 onnxruntime arm64 支持，跑不起来）。

建议的叙事顺序（**截图是转化的主战场，不要只截界面**，要带一句话卖点）：

| # | 画面 | en-US 标题 | zh-Hans 标题 |
|---|---|---|---|
| 1 | 首页规格列表 | 33+ official specs, ready to use | 33+ 官方规格，开箱即用 |
| 2 | 处理中/成片对比 | AI cutout and recolor, on your device | AI 抠图换底，全在本机完成 |
| 3 | 美颜与清晰度双滑杆 | Fine-tune skin and sharpness | 美颜与清晰度，随手微调 |
| 4 | 合规检测报告 | Checked before you save | 保存前逐项合规检测 |
| 5 | 底色秒切 | Blue, white, red — switch instantly | 蓝白红灰，底色秒切 |

> 注意第 4 条文案不要写成 "guaranteed to pass"（保证通过官方审核）之类的
> 绝对承诺——App 只做本地规则校验，无法代表任何政府机构，写成绝对承诺既
> 有拒审风险，也容易招致用户差评与退款。

## 5. 隐私政策（GitHub Pages 托管）

正文见 `docs/privacy-policy.md`（中英双语，生效日期 2026-09-11）。
**GitHub Pages 已启用**：Source = main 分支 /docs 目录，地址：

```
https://chunguangwei.github.io/photoid/privacy-policy
```

该 URL 填入 App Store Connect 的 App Privacy → Privacy Policy URL。
首次部署有分钟级延迟，提交审核前务必**实际打开验证**。

## 6. 审核风险点

| 风险 | 说明 | 应对 |
|---|---|---|
| **绝对化宣传** | 宣称"保证通过审核/官方认证"会被视为不实描述 | 文案统一用 "compliance **check**"、"meets common specs"，不用 guarantee/official |
| **iPad 未适配** | Universal 但 UI 只适配竖屏手机 | 已解决：v0.8.1 收窄为 iPhone-only（见 §1） |
| **权限文案语言** | 英文系统弹中文 | 已修复 |
| **首次启动即索权** | 无理由的权限弹窗会被拒 | 当前是用户点「拍摄/上传」时才请求，符合要求 |
| **包体较大** | 106MB，含 26MB 模型 | 低于蜂窝下载限制，无需处理；模型随包不走网络下载，反而有利于「无数据上传」的隐私主张 |
| **启动页广告位** | 启动页预留了广告位槽（当前为空） | 上架版本**不要**接入广告 SDK，否则隐私问卷与年龄分级都要重填 |

## 7. 上架文案（v0.8.1 正式版）

### 7.1 en-US（主语言）

- **Name**（≤30 字符）: `PhotoID - ID Photo Maker`
- **Subtitle**（≤30）: `Passport photos, fully offline`
- **Promotional Text**（≤170，可随时改无需过审）:
  `Every photo is processed on your device — cutout, retouching, framing and compliance checks all run offline. Nothing is ever uploaded.`
- **Keywords**（≤100，英文逗号分隔）:
  `id photo,passport photo,visa photo,background remover,headshot,id card,photo resizer,compliance`
- **Description**（≤4000）:

```
PhotoID makes compliant ID photos entirely on your device. Cutout, framing,
retouching and file-size control all run locally — your photos are never
uploaded, and the app works fully offline.

FIVE BACKGROUNDS, HAIR-LEVEL CUTOUT
Switch between blue, white, red, gray and dark blue instantly, with a
recommended default per spec. On-device AI keeps hair strands and shoulder
lines clean — no halo, no chopped edges.

AUTO FRAMING FOR 33+ SPECS
One-inch, two-inch, passport, visa and exam formats are built in, and you can
define your own. Output size, aspect ratio and head proportion follow the
spec automatically; pinch and drag to fine-tune.

COMPLIANCE CHECK BEFORE YOU SAVE
The result is reviewed against the spec — dimensions, ratio, background,
head proportion, head position, eyes open and file size — so issues are
caught before you submit.

NATURAL RETOUCHING
Two independent sliders: skin retouching and clarity. Both start at zero, so
you always see the untouched photo first and add only what you want.

KB-SIZE CONTROL
Many online applications require the JPEG to fall inside a KB range. PhotoID
hits the range for you and can name the file with your student or applicant
ID.

DARK MODE & BILINGUAL
Full light and dark themes follow your system. Interface in English and
Chinese.

PRIVATE BY DESIGN
No account. No analytics. No ads. No network access for photo processing.
Your photos never leave your phone.
```

- **What's New**（首次上架）:

```
First release on the App Store — a fully offline ID photo maker with
on-device AI cutout, five backgrounds, compliance checks and natural
retouching.
```

### 7.2 zh-Hans（本地化）

- **名称**: `智能证件照`
- **副标题**: `证件照·换底·美颜，全程离线`
- **宣传文本**:
  `抠图、换底、美颜、构图、合规检测全部在本机离线完成，照片永不上传。`
- **关键词**: `证件照,护照照片,签证照片,换底色,抠图,美颜,一寸照,报名照`
- **描述**:

```
智能证件照把合规证件照的全部流程放在你的设备本地完成：抠图、换底、
构图、美颜、文件大小控制，全程离线，照片永不上传。

发丝级抠图 · 五色换底
蓝 / 白 / 红 / 灰 / 深蓝秒速切换，每种规格带推荐默认色。端侧 AI 保留
发丝与肩线细节，无光晕、无残缺边缘。

33+ 内置规格 · 自动构图
一寸、二寸、护照、签证、考试报名等规格内置，也支持自定义。输出尺寸、
宽高比、头部占比自动对齐规格，双指缩放拖动可微调。

保存前合规检测
逐项核对尺寸、比例、底色、头部占比、居中、睁眼与文件大小，问题在
提交前发现。

自然美颜
美颜与清晰度两条独立滑杆，每次进入都从 0 开始：先看到原片，再按需
添加。

KB 大小控制
很多线上报名要求 JPEG 落在指定 KB 区间，App 自动压到区间内，并可用
学号式 ID 命名文件。

深色模式 · 中英双语
亮 / 暗主题跟随系统，界面支持中文与英文。

隐私优先
无账号、无统计、无广告、照片处理不联网，你的照片不会离开手机。
```

- **新增内容**: `首次上架 App Store。`

> 文案纪律：全篇不得出现 guarantee / official / 保证通过 等绝对化措辞；
> 合规功能一律表述为 "check / 检测"（见 §6）。

## 8. 打包与上传

```bash
flutter build ipa --release
# 产物：build/ios/ipa/*.ipa
# 上传：open -a Transporter，或 Xcode → Organizer → Distribute App
```

**当前状态**：archive 已构建成功（`build/ios/archive/Runner.xcarchive`），
但本机 Xcode 未登录 Apple 账号、无 iOS Distribution 证书，导出 IPA 失败。
处理：Xcode → Settings → Accounts 登录开发者账号后，Xcode → Organizer →
Distribute App 直接分发该 archive，或重跑 `flutter build ipa --release`。

真机联调安装（开发证书，**7 天过期**，长期测试请用 TestFlight）：

```bash
flutter build ios --release          # 必须带签名，不能用 --no-codesign
flutter install --release -d <device-id>
```

---

## 相关文档

- 产品说明：`docs/product.md`
- 开发与发布：`docs/development.md`
- 隐私政策正文：`docs/privacy-policy.md`
