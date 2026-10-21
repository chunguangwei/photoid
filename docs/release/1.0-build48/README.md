# 重新送审准备：1.0.0 / 候选 build 48

本目录材料可供核对与复制，尚未点击 App Store Connect 的「更新审核」。

- `metadata.json`：中英文名称、副标题、描述、关键词、更新说明。
- `review-notes-en.txt`：可复现的自定义规格 → JPEG/JSON 交付路径。
- `resubmission-reply-en.txt`：纠正旧绝对声明后的回复草稿，未发送。
- `ExportOptions.plist`：仅本地导出，不上传的 App Store 打包配置。
- `RELEASE-NOTES.md`：本次 Android / GitHub 发布说明。

## 提交顺序

1. 确认 App Review Board 是否已有新回复。当前所知：ASC 版本 1.0 被拒，只列 4.3.0。
2. 最终归档实际为 **1.0.0 (48)**，Android 同为 1.0.0+48。Flutter 会把 `--build-name=1.0` 规范化成 1.0.0，已核对 SDK 源码；不是归档失败。ASC 当前截图为 1.0，上传后核对构建可选性，必要时在原被拒版本将版本号更新为 1.0.0。
3. 先解决 Xcode 分发签名，再从本次归档导出并上传 IPA，等待处理后替换 build 47；若 build 48 已被其他操作占用，先升 build 并重新归档。
4. 更新商店文案和隐私问卷；不能再选「完全不采集数据」。最终包内 GoogleDataTransport 的隐私清单已声明用于分析的 Other Diagnostic Data，ML Kit 官方另列设备/安装级标识与性能指标，须据完整归档清单及实际 SDK 情况完成问卷。
5. 更新截图，展示自定义要求、实际编辑、文件检查与导出。旧商店图仍对应 build 47，不能把本地 UI 测试预览冒充新版真机截图。建议录一段 480×640、20–100 KB 的完整演示。
6. 真机验证选择照片、处理、快速换底、裁剪重置、导出 Files 的文件名/实际字节数、保存 Photos、拒绝权限、离线、减少透明度及 iPad 兼容模式。
7. 把已纠正的审核操作路径放入 Review Notes，补充本次改动说明。
8. 在原 App / 原 Bundle ID 的被拒版本更新审核内容，检查提交详情后重新提交。不要创建新 Bundle ID 规避 4.3。

[Apple：处理存在未解决问题的提交](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/manage-a-submission-with-unresolved-issues/)

## 本地检查与构建

```sh
flutter pub get
flutter test --reporter expanded
dart analyze
flutter build apk --release --no-pub
# 等 Android 构建完成后再构建 iOS；避免 Flutter 生成配置互相覆盖。
flutter build ipa --release --build-name=1.0.0 --build-number=48 --no-pub --export-options-plist=docs/release/1.0-build48/ExportOptions.plist
```

不要并发运行设备集成测试与发布构建：它们会改写共用的插件注册文件和生成配置。
设备脚本模板与启用步骤位于 `tools/device_review/README.md`。模板不参与发布依赖，避免 Flutter 3.47 的 dev 插件注册与 Release 依赖排除不一致导致 Android 编译失败。启用时，需先把仓库示例图复制到应用 Documents/photoid_review_fixture.png；这不访问用户系统相册。自动化需要设备解锁及调试服务可连接。当前 VM Service 连接被重置，不能据此声称真机流程已验收。

## 尚需人工/外部状态确认

- ASC 实时申诉状态、隐私问卷与已上传 build 列表未读取：浏览器电脑控制未获授权。
- 真机自动化已安装并启动，但调试服务连接未完成；设备截图与完整交付验收待确认。
- App Store 是否接受仍由 Apple 决定；本次修复和视觉改版不构成 4.3(a) 过审保证。

## 最终 iOS 产物状态

`build/ios/archive/Runner.xcarchive` 已完成最终源码归档：1.0.0 (48)，Bundle ID cn.wcg.idphoto。自动导出和带 `-allowProvisioningUpdates` 的独立重试均提示 `No Accounts` / `No signing certificate iOS Distribution`。当前 keychain 未找到该团队的有效分发身份，签名信任验证也未通过，不能将归档或旧 IPA 当作可上传包。

旧 `build/ios/ipa` 已移到 `build/ios/previous-ipa` 避免误传；它不是本次最终构建。请在 Xcode → Settings → Accounts 完成对应团队登录与分发签名配置，然后重试：

```sh
xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive -exportPath build/ios/appstore-final -exportOptionsPlist docs/release/1.0-build48/ExportOptions.plist -allowProvisioningUpdates
```

成功导出后重新验证包内版本、签名和 SDK 隐私清单，再上传。没有上传或提交审核。
