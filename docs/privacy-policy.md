---
layout: default
title: Privacy Policy
permalink: /privacy-policy
---

# Privacy Policy / 隐私政策

**Effective date / 生效日期：2026-10-21**
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
