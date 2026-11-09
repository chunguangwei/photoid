# 下一版：任务驱动的本机照片寻找

开发分支：`feat/requirements-workflow`，继续原有产品升级；不是新建应用。此目录覆盖上一轮 requirements-workflow 的增量准备，历史拒审/已发版本记录保持不变。

本版新增目录/多文件候选筛选、可解释理由、任务裁剪像素估计、文件与任务版本复核和真实模型示例；保留人工选图/拍照、OCR 要求导入、裁切换底压缩、文件核对及 ZIP 交付。

- [产品与架构](../../photo-finder.md)
- [EN/ZH 商店文案](metadata.md)
- [审核员说明草稿](review-notes-en.txt)
- [截图与视频](screenshots-and-video.md)
- [验证与待办](verification.md)

当前 pubspec 的 `1.1.0+49` 只用于开发验证，**不得直接用于重新上传**。上传前对照 App Store Connect 选定新版本/未使用 build，并更新截图、隐私披露和审核说明。尚未上传、提交审核或正式发布 Android。本功能能提供可演示的实质差异，但无法保证消除 4.3(a) 拒审风险。
