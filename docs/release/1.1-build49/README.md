# 1.1.0 (49) 报名照片交付准备

本目录是新增功能的送审草稿，未上传、未提交 App Store；不保证解决 4.3。沿用原 App ID / Bundle ID，不创建新 App。

- `metadata.json`：中英文商店文案，仅描述当前实现。
- `review-notes-en.txt`：已有文件检查与双版本交付操作路径。
- `verification.md`：验证结果及未完成项。

与 build 47 相比新增：已有照片检查（只读）；带来源/截图/日期的本地任务；一张源图分别制作最多五份文件；实际文件重新核对后 ZIP 交付，附逐份 JSON 和可读清单。build 48 已有自定义入口与单 JPEG/JSON 导出，本次不把它们重复声称为 build 49 首创。

送审前仍须：核对申诉最新回复；复核 App Privacy 问卷；新版真实设备截图与演示；iPhone/iPad 系统权限及 Files/Photos 分享/保存验收。现有 widget 渲染不能直接作为商店截图。代码来源记录不能替代产品差异，尚未完成系统性的竞品差异验证，不声称独有。

## 构建

先完整运行 `flutter test --no-pub` 与 `dart analyze`，再串行构建：

```sh
flutter build apk --release --no-pub
flutter build ios --release --build-name=1.1.0 --build-number=49 --no-pub
```

分发归档另行使用 Xcode 或 `flutter build ipa --release --build-name=1.1.0 --build-number=49 --no-pub --export-options-plist=docs/release/1.0-build48/ExportOptions.plist`。核对实际归档版本和 ASC 是否已占用 build 49 后上传，不把真机开发签名包当分发 IPA。
