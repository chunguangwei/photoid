# iOS 海外 App Store 上架清单

## 已完成（代码侧）
- [x] 部署目标 iOS 15.5（project.pbxproj × 3 + AppFrameworkInfo.plist）
- [x] 应用内中英双语（lib/l10n，跟随系统语言，英文系统 → English）
- [x] 显示名本地化：en → "PhotoID"，zh-Hans → "智能证件照"（InfoPlist.strings）
- [x] 权限声明文案：NSCameraUsageDescription / NSPhotoLibrary(Add)UsageDescription
- [x] 隐私设计：全端侧处理，无数据上传（App Store 隐私问卷可全部答"不收集"）

## 待人工完成（App Store Connect）
- [ ] Apple Developer Program 账号（$99/年）并在 Xcode → Settings → Accounts 登录
- [ ] Runner → Signing & Capabilities 选择 Team，Bundle ID 按需改为正式域名（当前 cn.wcg.photoid）
- [ ] App Store Connect 创建 App，地区选择海外（避开中国大陆备案要求）
- [ ] 准备素材：6.7" / 6.5" 截图（中英各一套）、1024×1024 图标、隐私政策 URL
- [ ] 隐私问卷：数据收集全部选 "Data Not Collected"（端侧处理属实）
- [ ] 出口合规：仅系统加密 → ITSAppUsesNonExemptEncryption = false（可加入 Info.plist）
- [ ] `flutter build ipa` 后 Transporter/Xcode 上传，提交审核

## 上架文案（英文）
- **Name**: PhotoID — Smart ID Photo
- **Subtitle**: Compliance-checked ID photos, offline
- **Keywords**: id photo,passport photo,visa photo,background remover,photo compliance
- **Description**:
  PhotoID creates compliant ID photos entirely on your device — nothing is ever uploaded.
  • AI background replacement (blue/white/red)
  • Auto framing to official specs (size, ratio, head proportion)
  • Compliance report before you save
  • JPEG size control (KB range) for online applications
  • Rename output files (e.g. by Education ID)
