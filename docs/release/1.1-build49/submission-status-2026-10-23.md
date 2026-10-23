# 2026-10-23 App Store Connect 操作记录

## 已完成

- 在原 App ID 6811734521 的被拒版本页面，将待审版本号由 1.0 修改并保存为 1.1.0；没有新建 App。
- 已保存新版中英文推广文本、描述、中英文关键词、支持链接和英文审核演示说明；App 信息中英文副标题已保存，名称沿用 PhotoID Studio。线上英文描述为同一功能范围的精简版。
- 原提交仍为 490a7db7-2fcc-4468-9b22-1f50b7276ff0，问题未解决，消息共 4 条，最后消息为开发者 10 月 16 日申诉；未发现新回复。
- 新版 archive 与 App Store IPA 生成成功。Xcode Organizer 显示 photoid 1.1.0 (49) uploaded / App upload complete。
- IPA：build/ios/ipa/photoid.ipa，71535174 字节，SHA-256 6b202bc9d9b82c47dc3b62c05358ef61d65ac0d63252f02ad2d78eb184e8891d。
- App Privacy 由“未收集数据”修正并发布为“不关联身份的数据”。按随包 MLKitCommon、MLKitFaceDetection 和 GoogleDataTransport 的 PrivacyInfo.xcprivacy 配置六类：设备 ID、产品交互、性能数据、其他诊断数据、其他数据类型、其他用户内容。其他诊断仅分析，其余为分析与 App 功能；全部不关联身份、不用于追踪。SDK 类别不代表上传照片；照片/视频未声明收集。参照 Google https://developers.google.com/ml-kit/ios-data-disclosure 。

## 真机验收、截图与重新提交

- ASC 已处理完成 build 49，已在原版本页替换旧 0.8.5 (47) 为 1.1.0 (49) 并保存；页面未提示缺失加密合规。
- 新版实际运行截图。目前仓库 widget 预览不能直接充当原始商店截图；旧版商店截图不展示新版任务流程。
- iPhone 13 / iOS 27.0.1 真机已完成：Files 选入公开示例照片；同一任务制作蓝底 480×640 / 20–100 KB 与白底 300×400 / 10–100 KB；裁切重置；保存照片到相册；保存成片到任务并重进确认；ZIP 分享到 Files 与解压；已有文件只读检查。实测 JPEG 分别为 95,221 / 67,626 字节，尺寸与 JSON、CHECKLIST.txt 相符，ZIP 共五个文件。
- iPad Air 4 / iPadOS 27.0.1 真机已启动并观察横竖屏兼容模式首页；Device Hub 点击暂未触发导航，不能据此声称完整交互已验收。
- 需要实际截图的建议顺序：新版首页、已有照片的检查结果、任务要求与来源、同一任务的两种文件规格、两份成片准备完成、实际 ZIP 清单。中英两套。仅使用可公开的示例照片和虚构任务，避免真实报名信息。
- 首图文案：中文“按报名要求，准备照片文件”；英文“Prepare photo files for applications”。后续依次“检查已有照片 / Check an existing photo”“保存要求，继续制作 / Keep requirements together”“一张原图，多个版本 / One source, several files”“照片与清单一起交付 / Export photos with a checklist”。不使用“官方”“认证”“保证受理”“独有”等无依据描述。
- 已通过 Xcode Device Hub 直接操作 iPhone，原生截图已采集至 assets/screenshots/v1.1/raw；中英商店海报已生成并目视核对。截图仅含虚构 Demo 任务与公开 Unsplash 示例照片。示例图：https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800 ，使用依据：https://unsplash.com/license 。
- 中英文旧版两组大屏截图引用均已移除，素材库原件保留；中英文各五张新版截图已上传至 1179×2556 主分组，页面均显示 5/10，其他尺寸使用主分组素材。已于 2026-10-23 10:03（Asia/Shanghai）在原提交中重新提交，页面确认“等待审核”。
- 已点击“更新审核”，原提交项目从旧版本替换为 iOS App 1.1.0 (49)，状态“可供审核”；随后点击“重新提交至 App 审核”，最终确认整单与版本均为“等待审核”。提交 ID 仍为 490a7db7-2fcc-4468-9b22-1f50b7276ff0，提交日期 2026-10-23 10:03。未额外发送审核消息；演示步骤位于新版本审核备注。

4.3 审核结果由 Apple 决定，不保证通过。
