---
layout: default
title: App Store 上架
---

> **当前开发版 1.2.0（51）**：按用户反馈简化为“选尺寸 → 选一批照片 → 点一张开始制作”，移除面向用户的示例入口。常用 33 个规格和自定义输入直接可用，主流程不再要求建任务；原有记录和高级工具保留。见 [简版交互说明](release/next-photo-finder/ux-1.2.0-build51.md)。build50 材料为历史，不能作为本版最终上架素材。

# App Store 下一版准备

更新：2026-11-09。当前候选为 **1.2.0（51）**，保持同一应用的实质功能升级。2026-11-09 实查：ASC 最新上传为 1.1.0（49），11 月 6 日的询问后暂无新增消息。

App：PhotoID Studio，App ID `6811734521`；iOS bundle `cn.wcg.idphoto`，Team `CCTFP9X3SW`。最低 iOS 15.5，主要 iPhone；仍需 iPad 的 iPhone 兼容模式验收。

## 审核背景

用户提供的历史记录：1.0(47) 曾因 1.1.6 与 4.3(a) 被拒，后续回复仅继续列 4.3(a)；1.1.0(49) 于 2026-11-05 再收到 4.3(a)。不据此承诺其他条款永远无问题。历史申诉、构建与准备材料见 [build48](release/1.0-build48/README.md)、[build49](release/1.1-build49/README.md) 和 [上一轮增量](release/next-requirements-workflow/changes.md)，保留原文，不改写历史。

当前新增简版找照片：选尺寸 → 从相册批量/文件夹找图 → 点图采用 → 原有编辑 → 文件实测交付。配合已有要求截图 OCR、短来源摘录和任务版本保护，提供可复现的新工作流。保留所有人工入口。新能力可能有助于说明产品差异，不能保证 Apple 改变 4.3(a) 判断。

## 本轮材料

- [完整功能与图示](photo-finder.md)
- [发布准备总览](release/next-photo-finder/README.md)
- [中英文描述、关键词、更新说明](release/next-photo-finder/metadata.md)
- [审核员操作说明草稿](release/next-photo-finder/review-notes-en.txt)
- [截图/视频清单](release/next-photo-finder/screenshots-and-video.md)
- [验证证据与待办](release/next-photo-finder/verification.md)
- [隐私政策](privacy-policy.md)

## 重新提交顺序

1. 完成本轮测试和重要代码审查问题修复，验收真实目录/文件提供方、Photos/相机和 iPad 兼容模式。
2. 对照 ASC 当前审核回复与已使用 build，选择下一版版本号和未使用 build，更新 pubspec、原生归档和更新说明；候选 `1.2.0+51` 已在本地选定，上传前再次核对编号并修改原有版本记录。
3. 同步最终构建的设备截图和演示视频，清晰展示选尺寸、批量找照片和制作结果，不用设计图替代真实功能图。核对设备尺寸和全部本地化。
4. 核对 SDK 数据披露、隐私政策、App Privacy、年龄分级和出口合规；仅填写实际情况。
5. 签名归档、上传 TestFlight 并验证。正式 Android 升级包需保持原 release key，测试签名包不得发布。
6. 在原有 App 的版本页更新构建、文案、截图和审核说明，检查所有字段后提交。本轮开发工作不自动点击提交审核，也不发送新的申诉。
