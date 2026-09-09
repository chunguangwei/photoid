# 智能证件照 PhotoID

**English** | [中文](#中文)

## English

PhotoID is an AI-powered ID photo maker that runs **entirely on-device**. Take a photo or pick one from your gallery, and PhotoID handles background removal and replacement, automatic face-based framing and cropping, compliance checking, and saving with education-style ID filenames — **all locally, no photo ever leaves your phone**.

### Features

- 📷 **Capture or import** — shoot directly in the app or pick an existing photo
- ✂️ **Smart cutout & background replacement** — on-device segmentation with solid-color backgrounds
- 🎯 **Auto framing & cropping** — face detection drives automatic composition and spec-exact cropping
- ✅ **Compliance check** — verify head size, position, background and more against built-in specs
- 🏷️ **Education ID naming** — save files with student-style IDs for easy archiving
- 🔒 **100% local processing** — no account, no upload, no watermark, works offline

### Tech Stack

- **Flutter** (Dart) — cross-platform UI
- **Google ML Kit** — Selfie Segmentation + Face Detection, on-device inference
- **image** — pixel-level compositing and resizing
- Built-in spec library (`assets/photo_specs.json`) describing dimensions and compliance rules

### Quick Start

```bash
git clone https://github.com/chunguangwei/photoid.git
cd photoid
flutter pub get
flutter run
```

### Platform Support

- Android 8.0 (API 26)+
- iOS 15.5+

### License

Non-Commercial License — free for personal use; **commercial use requires the author's written permission: please contact <your-email@example.com>.** See [LICENSE](LICENSE).

### Disclaimer

Compliance results are advisory only. The final acceptance of an ID photo is always determined by the reviewing authority. Verify against the official requirements of the target institution before submitting.

---

## 中文

PhotoID 是一款**纯端侧**的 AI 证件照制作应用。支持拍摄或从相册导入照片，自动完成智能抠图换底、基于人脸检测的自动构图裁剪、合规检测，并以教育 ID 命名方式保存——**全部在本地处理，照片不会上传到任何服务器**。

### 功能特性

- 📷 **拍摄 / 上传**——应用内直接拍摄，或从相册导入现有照片
- ✨ **智能抠图换底**——端侧人像分割，一键替换纯色背景
- 🎯 **自动构图裁剪**——基于人脸检测自动定位头部，按规格精确裁剪
- ✅ **合规检测**——对照内置规格检测头部尺寸、位置、背景等合规项
- 🏷️ **教育 ID 命名保存**——按学号式 ID 命名文件，便于归档管理
- 🔒 **全部本地处理**——无需账号、不上传、无水印，离线可用

### 技术栈

- **Flutter**（Dart）——跨平台 UI 框架
- **Google ML Kit**——Selfie Segmentation + Face Detection，端侧推理
- **image** 包——像素级合成与缩放
- 内置规格库（`assets/photo_specs.json`）描述各证件照尺寸与合规规则

### 快速开始

```bash
git clone https://github.com/chunguangwei/photoid.git
cd photoid
flutter pub get
flutter run
```

### 平台支持

- Android 8.0（API 26）及以上
- iOS 15.5 及以上

### 许可证

本项目采用非商业许可证：个人使用免费；**商业使用需获得作者书面授权，请联系 <your-email@example.com>。** 详见 [LICENSE](LICENSE)。

### 免责声明

合规检测结果仅供参考，证件照最终是否合格以官方审核为准。请在提交前自行核对待办机构的官方要求。
