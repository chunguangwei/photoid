---
layout: default
title: App Store 上架
---

# App Store 重新送审准备

2026-10-21 更新。以 [候选 build 48 准备清单](release/1.0-build48/README.md) 为当前依据；[完整审查报告](audit-2026-10-21.md) 记录修复和未验证范围。

## 应用与版本

- App：PhotoID Studio；App ID：6811734521。
- iOS Bundle ID：`cn.wcg.idphoto`；Team：`CCTFP9X3SW`。Android 为 `cn.wcg.photoid`。
- 最低系统：iOS 15.5，Android API 26。iPhone 设备家族、竖屏；仍需验证 iPad 的 iPhone 兼容模式。
- 用户提供的 ASC 截图显示版本 **1.0 被拒绝**，审核构建 **47**。候选 build **48**，最终版本以归档 Info.plist 为准。
- 原有地区选择记录为排除中国大陆与欧盟；本轮未读取 ASC 实时销售地区，须在后台核对。

## 审核事实

1. 2026-09-16 首轮列出 1.1.6 与 4.3(a)，设备为 iPad Air 11-inch (M3)。旧截图的 “official specs” 存在误导风险，已去除；Apple 原信没有说明其为唯一问题。
2. 2026-09-24 已回复，说明照片准备工具定位及独立开发情况。
3. 2026-10-16 再次只列 4.3(a)，仍称 “similar binary, metadata, and/or concept”。无法据此判断具体命中二进制、元数据还是概念。
4. 同日已向 App Review Board 申诉；原始通信见 [历史存档](review-reply-en.txt)。本轮未读取最新回复，未重复发信。旧信中提交数、完全无统计、自定义头部比例及竞品比较等陈述不能继续复用。

不得保证通过审核。开源与独立编写支持开发来源说明，视觉更新和本地处理也不能自动证明 4.3(a) 已解决。应使用真实的新流程演示，明确自定义要求、实际文件检查和原始文件交付的价值。

## 本次代码与视觉调整

统一深浅主题，自定义规格优先，玻璃视觉限于导航，高对比度/iOS 减少透明度回退实底。它是 Flutter 材质近似，未宣称原生 Liquid Glass。修复搜索、KB 限制、异步换底/相机生命周期、裁剪与文件缓存；新增 JPEG + JSON 报告导出。

本地 UI 渲染预览见 [走查预览](ui-preview-2026-10-21/README.md)，不是可直接上传的设备截图。

## 隐私与商店资料

照片与人脸检测结果在本机处理，但 ML Kit 默认收集技术诊断和使用指标。最终包中 GoogleDataTransport 的隐私清单声明 Other Diagnostic Data / Analytics，不能直接选 “Data Not Collected”。App 自己的空采集清单不能代表所有 SDK。提交前须按完整归档与 SDK 文档核对问卷。

- [隐私政策](https://chunguangwei.github.io/photoid/privacy-policy)
- [支持页面](https://chunguangwei.github.io/photoid/)
- [中英文商店文案](release/1.0-build48/metadata.json)
- [审核操作路径](release/1.0-build48/review-notes-en.txt)
- [未发送的更新说明草稿](release/1.0-build48/resubmission-reply-en.txt)

## 更新审核按钮与提交顺序

当前截图中的「更新审核」用于更新现有被拒提交，不能凭该按钮保证通过。继续使用原 App 与 Bundle ID，核对申诉状态后上传新构建、替换 build 47、更新截图/文案/隐私问卷，再检查提交详情并重新提交。本轮仅导出 IPA 和准备材料，没有上传或点击提交。

仍需完成系统相机/照片权限、真实照片推理、快速换底与裁剪、Files 导出字节数、Photos 保存、离线、减少透明度与 iPad 兼容模式验收。设备自动化 VM Service 连接失败不等于已经验收。

[Apple 审核准则](https://developer.apple.com/app-store/review/guidelines/) · [处理存在未解决问题的提交](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/manage-a-submission-with-unresolved-issues/) · [ML Kit 数据披露](https://developers.google.com/ml-kit/ios-data-disclosure)
