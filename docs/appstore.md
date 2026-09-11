# iOS 海外上架准备（App Store）

面向**英语系国家**（美、加、英、澳、新西兰、新加坡等）上架，不含中国大陆区
——大陆区需要软著与 ICP 备案号，海外区不需要，这是选择海外先行的主要原因。

- Bundle ID：`cn.wcg.photoid`
- Team：`L35RLT89XN`
- 最低系统：iOS 15.5
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

> **权限文案本地化为什么是硬要求**：`Info.plist` 里的 `UsageDescription` 是
> 硬编码中文时，英文系统用户会看到中文权限弹窗，属于 Guideline 5.1.1 的
> 常见拒审点。必须靠 `en.lproj/InfoPlist.strings` 覆盖。

## 2. 待办（代码侧，上架前必须处理）

- [ ] **收窄为 iPhone 专用 + 锁定竖屏**（已决策，尚未实施）

  当前 `TARGETED_DEVICE_FAMILY = "1,2"`（Universal）且 `Info.plist` 允许横屏，
  但全部 UI 是按竖屏手机设计的，代码里也没有 `setPreferredOrientations`。
  后果有两个：App Store **强制要求提供 iPad 截图**，且审核员会在 iPad 与
  横屏下实测，布局溢出会直接拒。

  改动清单：
  1. `project.pbxproj` 三处 `TARGETED_DEVICE_FAMILY` 改为 `"1"`；
  2. `Info.plist` 的 `UISupportedInterfaceOrientations` 只留
     `UIInterfaceOrientationPortrait`，删掉 `~ipad` 整个键；
  3. `main()` 里加 `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])`。

- [ ] 确认 App 名称在目标区域未被占用（`PhotoID` 是常见词，很可能已被注册）。
      App Store Connect 创建 App 时若提示重名，需换显示名，例如
      `PhotoID - ID Photo Maker`。**Bundle ID 一经创建不可更改**，名称可改。

## 3. 待办（App Store Connect 侧）

- [ ] Apple Developer Program 账号（$99/年），Xcode → Settings → Accounts 登录
- [ ] App Store Connect 创建 App，**Availability 只勾选目标英语区**
- [ ] 隐私政策 URL（见 §5，GitHub Pages 托管）
- [ ] 隐私问卷：全部选 "Data Not Collected"
- [ ] 年龄分级：4+（无 UGC、无网络内容、无广告 SDK）
- [ ] 截图（见 §4）
- [ ] `flutter build ipa` → Transporter 或 Xcode Organizer 上传 → 提交审核

## 4. 截图规格

App Store 要求按**当前 App Store Connect 页面提示为准**（Apple 会调整）。
截至目前，iPhone 必交的是这两档，其余尺寸由 Apple 自动缩放：

| 档位 | 分辨率（竖屏） | 对应机型 |
|---|---|---|
| 6.9" | 1320×2868 或 1290×2796 | iPhone 16 Pro Max / 15 Pro Max |
| 6.5" | 1242×2688 或 1284×2778 | iPhone 11 Pro Max / XS Max |

每档 3–10 张，建议 5 张，中英各一套（对应 en-US 与 zh-Hans 两个本地化）。

建议的叙事顺序（**截图是转化的主战场，不要只截界面**，要带一句话卖点）：

1. 首页规格列表 —— "50+ official specs, ready to use"
2. 处理中/成片对比 —— "AI cuts out the background, on your device"
3. 美颜与清晰度双滑杆 —— "Fine-tune skin and sharpness"
4. 合规检测报告 —— "Checked before you save"
5. 底色秒切 —— "Blue, white, red — switch instantly"

> 注意第 4 条文案不要写成 "guaranteed to pass"（保证通过官方审核）之类的
> 绝对承诺——App 只做本地规则校验，无法代表任何政府机构，写成绝对承诺既
> 有拒审风险，也容易招致用户差评与退款。

## 5. 隐私政策（GitHub Pages 托管）

正文见 `docs/privacy-policy.md`（中英双语）。发布方式：

```
仓库 Settings → Pages → Source 选 "Deploy from a branch"
  → Branch: main / 目录 /docs
```

启用后地址为：

```
https://chunguangwei.github.io/photoid/privacy-policy
```

该 URL 填入 App Store Connect 的 App Privacy → Privacy Policy URL。

> 必须是**公开可访问**的页面，审核会实际打开。仓库若是 private，
> GitHub Pages 需要付费计划才能公开，届时改用其他静态托管。

## 6. 审核风险点

| 风险 | 说明 | 应对 |
|---|---|---|
| **绝对化宣传** | 宣称"保证通过审核/官方认证"会被视为不实描述 | 文案统一用 "compliance **check**"、"meets common specs"，不用 guarantee/official |
| **iPad 未适配** | Universal 但 UI 只适配竖屏手机 | 见 §2，收窄为 iPhone-only |
| **权限文案语言** | 英文系统弹中文 | 已修复 |
| **首次启动即索权** | 无理由的权限弹窗会被拒 | 当前是用户点「拍摄/上传」时才请求，符合要求 |
| **包体较大** | 106MB，含 26MB 模型 | 低于蜂窝下载限制，无需处理；模型随包不走网络下载，反而有利于「无数据上传」的隐私主张 |
| **启动页广告位** | 启动页预留了广告位槽（当前为空） | 上架版本**不要**接入广告 SDK，否则隐私问卷与年龄分级都要重填 |

## 7. 上架文案（英文）

- **Name**: PhotoID - ID Photo Maker
- **Subtitle**: Passport & visa photos, offline
- **Promotional Text**: Every photo is processed on your device. Nothing is uploaded.
- **Keywords**: `id photo,passport photo,visa photo,background remover,headshot,photo resizer,id card`
- **Description**:

```
PhotoID makes compliant ID photos entirely on your device — your photos are
never uploaded, and the app works fully offline.

AI BACKGROUND REPLACEMENT
Swap to blue, white, red, gray or dark blue in one tap. Hair strands and
shoulder lines stay clean — no halo, no chopped-off edges.

AUTO FRAMING
Pick a spec and the photo is framed for you: output size, aspect ratio and
head proportion all follow the spec. You can still pinch and drag to adjust.

COMPLIANCE CHECK
Before you save, the app reviews the result against the spec — size, ratio,
head proportion, file size — so you know what you are getting.

NATURAL RETOUCHING
Two independent sliders: skin retouching and clarity. Both start at zero, so
you always see the untouched result first and add only what you want.

FILE SIZE CONTROL
Many online applications require the JPEG to fall inside a KB range. PhotoID
hits that range for you, and lets you rename the output file.

PRIVACY
No account. No network access for photo processing. No analytics SDK.
Your photos never leave your phone.
```

- **What's New**（v0.7.x 首次上架可写）：

```
First release on the App Store.
```

## 8. 打包命令

```bash
flutter build ipa --release
# 产物：build/ios/ipa/*.ipa
# 上传：open -a Transporter，或 Xcode → Organizer → Distribute App
```

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
