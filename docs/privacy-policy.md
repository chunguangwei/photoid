---
layout: default
title: Privacy Policy
permalink: /privacy-policy
---

# Privacy Policy / 隐私政策

**Effective date / 生效日期：2026-11-10**
**App: PhotoID Studio（智能证件照）**

---

## English

### Summary

PhotoID processes everything **on your device**. We do not collect, transmit,
or store your photos on our servers. We have no account system or advertising SDK.
The third-party ML Kit SDK can send diagnostic and usage metrics to Google,
as explained below.

### What we access, and why

| Permission | Why | Leaves your device? |
|---|---|---|
| Camera | To take your ID photo in the app | No |
| Photo Library (read) | To let you pick an existing photo | No |
| Photo Library (add) | To save the finished ID photo | No |

Face detection and background removal run locally via on-device machine
learning models bundled inside the app. Your photos are **never uploaded** for
processing.

### Data we collect

We do not operate an account system or collect your photos on a server.
Google ML Kit collects technical diagnostics and usage metrics by default,
including device/app information, per-installation identifiers, API events,
configuration, performance and errors. These metrics help Google maintain
and improve the SDK. ML Kit does not upload input photos or detection results.
See [Google’s ML Kit privacy terms](https://developers.google.com/ml-kit/terms)
and [data disclosure details](https://developers.google.com/ml-kit/ios-data-disclosure).

Settings you choose (such as your preferred language) are stored locally on
your device only.

### Network access

Photo processing works offline. Google ML Kit may contact Google for SDK
diagnostics and maintenance. Android also checks GitHub Releases and downloads
updates when requested; on iOS, this update mechanism is disabled and updates
come from the App Store. Opening the online privacy policy uses your browser.

### Local photo storage

Saved results are also kept in the app’s private album. You can delete those
copies in My Photos. Copies exported to the system photo library remain there
until you delete them in Photos. System photo syncing and device backups follow
your operating system settings. Temporary export copies stay in the app cache so
receiving apps can read them; copies older than one day are removed on the next
app launch or export.

### Children

The app is suitable for all ages and does not knowingly collect any data from
children through an account or photo upload. The SDK metrics described above
still apply.

### Third-party components

The app bundles Google ML Kit (face detection) and ONNX Runtime (background
segmentation). Both run **locally**. Photo processing stays local; ML Kit’s technical metrics are described above.

### Changes

If this policy changes, the updated version will be published at this URL with
a new effective date.

### Contact

Questions: **chunguangwee@gmail.com**

---

## 中文

### 概要

PhotoID 的全部处理都在**你的设备本地**完成。我们不会把你的照片或个人信息
上传或存储到我们运营的服务器。App 没有账号体系或广告 SDK。
第三方 ML Kit SDK 可向 Google 发送技术诊断与使用指标，详见下文。

### 我们申请的权限及用途

| 权限 | 用途 | 是否离开设备 |
|---|---|---|
| 相机 | 在 App 内拍摄证件照 | 否 |
| 相册（读取） | 从相册选择已有照片 | 否 |
| 相册（写入） | 保存制作完成的证件照 | 否 |

人脸检测与抠图均由 App 内置的端侧模型在本地完成，你的照片**不会被上传**。

### 我们收集的数据

我们不运营账号系统，也不在服务器收集照片。Google ML Kit 默认收集技术诊断与
使用指标，包括设备与应用信息、安装级标识符、API 事件与配置、性能和错误数据，
用于维护和改进 SDK。ML Kit 不上传输入照片或检测结果。详见
[Google ML Kit 隐私条款](https://developers.google.com/ml-kit/terms) 与
[数据披露说明](https://developers.google.com/ml-kit/ios-data-disclosure)。

你选择的设置（例如界面语言）仅保存在本机。

### 网络访问

照片处理可离线完成。Google ML Kit 可为技术诊断和维护联系 Google 服务器。
Android 还会检查 GitHub Releases，并在用户选择后下载更新；iOS 关闭该更新机制，
通过 App Store 更新。打开在线隐私政策会使用系统浏览器。

### 本地照片存储

保存的成片也会保留在 App 私有相册，可在「我的相册」删除。已导出到系统
照片库的副本需在系统相册单独删除。系统照片同步与设备备份遵循你的系统设置。为便于接收应用读取，临时导出副本会
保留在 App 缓存中，超过一天的副本在下次启动或导出时清理。

### 未成年人

本 App 适合所有年龄段使用，不通过账号或照片上传收集儿童信息；上述 SDK 技术指标仍适用。

### 第三方组件

App 内置 Google ML Kit（人脸检测）与 ONNX Runtime（抠图分割），二者均在
**本地**运行，照片处理留在本机，ML Kit 的技术指标见上文。

### 政策变更

若本政策发生变更，我们会在此网址发布更新版本并标注新的生效日期。

### 联系方式

如有疑问请联系：**chunguangwee@gmail.com**


### Application tasks / 报名任务

Task names, notes, user-supplied requirement references and dates, optional requirement screenshots, source photos and prepared files are kept in the app’s Documents storage. References are not fetched or independently verified. Deleting a task removes its app-owned copies, not system originals or previously exported files. Device backups follow system settings.

Existing-file checks read the selected bytes without modifying them. Files selection preserves the selected file bytes; the system photo library or camera may provide a converted copy. ZIP delivery packages include photos, requirements and check reports. They leave the app only through the sharing destination you select. Recent delivery copies use the temporary export cache described above.

任务名称、备注、用户提供的要求来源与日期、可选要求截图、原图和成片保存在应用文档目录。应用不抓取或独立验证来源。删除任务会删除应用内副本，不影响系统原图及已导出文件；设备备份由系统设置决定。


已有照片检查只读取、不改写所选字节。“文件”选取保留所选文件字节，图库或相机可能提供系统转换副本。ZIP 交付包包含照片、要求和检查报告，仅通过你选择的分享目标离开应用。近期交付副本按上述临时导出缓存规则保留。

## Enhanced photo finder / 加强版找照片

The optional Enhanced photo finder uses a ~287MB EmbeddingGemma image-semantics model. After your confirmation, model files download from Hugging Face (including its China mirror) or ModelScope into the app's private storage and can be deleted anytime in Settings. Downloads transfer model files only; your photos are never uploaded. When enabled, embeddings are computed on-device for the current photo batch only and used solely to reorder candidates; there is no full-library index, and nothing is uploaded. Turning it off or clearing the session releases the data.

可选的「加强版找照片」使用约 287MB 的 EmbeddingGemma 图像语义模型。模型文件经你确认后从 Hugging Face（含国内镜像）或 ModelScope 下载到 App 私有目录，可随时在「我的」页删除；下载仅传输模型文件，不上传你的照片。开启后仅对当前选择的照片批次在设备本地生成语义向量并按相似度重排候选，不建立全相册索引、不上传向量或照片；关闭或清除会话即释放。


## Requirement screenshots / 要求截图

Requirement screenshots are recognized locally using Apple Vision on iOS and bundled ML Kit on Android. Only selected images are processed. Recognition images and text are not uploaded for recognition. Android ML Kit may send technical diagnostics and usage metrics as disclosed above. User-confirmed short excerpts stay in local tasks and are included in reports only on explicit export. Review excerpts and remove personal information before saving or sharing. Changes to the source or requirements require confirmation again.

要求截图在本机识别：iOS 使用 Apple Vision，Android 使用随包 ML Kit。仅处理用户选中的图片，不为识别上传图片或文字。Android ML Kit 可按上文披露发送技术诊断与使用指标。用户确认的短摘录保存在本地任务中，仅在主动导出报告时包含；请在保存与分享前移除个人信息。来源或要求改变后需重新核对，确认不代表机构认证。


## Local photo finder / 本机照片寻找

The optional finder reads only the folder or files you explicitly select; subfolders are opt-in. It uses on-device face detection, dimensions and advisory image measurements to suggest candidates for your task. It does not identify people, build identity embeddings, index the full library, persist directory bookmarks or request all-files access. Manual Files, Photos and camera selection remain available.

File providers may retrieve files you explicitly select. Folder scanning skips undownloaded or unverified remote items; Android directory access is restricted to known local providers. This is not a claim that every file-provider interaction is offline. Processing does not upload photos. ML Kit diagnostics remain as disclosed above.

File names, relative paths, face boxes and candidate results stay within the active session. Private thumbnails use a 100 MB limit and are deleted when clearing, changing scope or leaving. After abnormal termination, stale native caches older than 24 hours are removed at the next initialization. Stopping a scan keeps completed results until you clear or leave; backgrounding stops further scanning. One in-flight operation can finish but its late result is ignored.

Only a photo you explicitly adopt is saved as a task source copy. The original is not modified, renamed, moved or deleted. Adoption rechecks original bytes and the task's requirements/source revision. Shared ZIP files exclude the scan listing, unselected photos and face analysis. App-owned public sample variants are demonstration assets, not user photos. Task copies, backups and explicit exports follow the existing storage rules above.

可选的找照片功能仅访问你明确选择的目录或文件，子目录需主动勾选。通过本机人脸检测、像素和画质参考寻找任务候选，不识别身份、不生成身份向量、不索引整个相册、不持久保存目录书签、不申请所有文件访问。人工文件、图库、拍照入口保留。

文件提供方可能下载你明确选择的文件。目录扫描跳过未下载或无法确认本地状态的项目；Android 目录仅接受已知本地提供方。这不代表所有文件提供方交互都离线。照片不为处理上传，ML Kit 的技术诊断披露仍适用。

文件名、相对路径、人脸框和候选结果限于本次会话。私有缩略图缓存上限 100 MB，清除、切换范围或离开页面时删除；异常退出残留在下次初始化时清理超过 24 小时的原生缓存。停止保留已完成结果，清除或退出后结束访问；进入后台停止后续扫描，单次在途计算可能完成但旧返回被忽略。

只有你明确采用的照片会作为任务原图副本保存，不更改、重命名、移动或删除外部原文件。采用前复核文件字节及任务要求/原图版本。ZIP 不包含扫描清单、未选照片或人脸分析。公共示例变体属于演示素材，并非用户私人照片；任务副本、备份及主动导出仍按上文规则管理。


### Simplified selection / 简版选图（build51）

The finder opens without creating a task. Choosing a specification, inspecting a batch or canceling does not create a preparation record. Explicitly adopting a photo saves an app-owned source copy and requirement. System multi-photo selection grants access only to selected items; iOS retains provider handles and reads one bounded representation at a time. Providers may download explicitly selected content. Canceling replacement selection keeps the prior active batch; clearing or leaving releases its session. Example creation entries have been removed; existing records are not automatically deleted.

找照片入口不先建任务。选规格、查看照片或取消不会新建制作记录，明确采用后才保存应用内原图副本与要求。系统相册多选只授权所选项目；iOS 保留提供方句柄、逐张有界读取，不预先复制整批原图。提供方可能下载明确选中的内容。取消换批次保留原有会话，清除或退出结束访问。示例创建入口已移除，不自动删除已有记录。
