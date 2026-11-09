# 截图、图示与视频

工程图示见 [功能流程图](../../photo-finder.md)，实际 [iPhone / Android 中英文工程采集](device-captures/README.md) 已准备。真机集成测试可采集生产 PhotoFinderPage 的中英文图；来自真实 iPhone、实际原生模型与公开示例，不是 AI 生成 UI，也不把 fixture 文件名预设成推荐结果。测试使用临时任务和生产主题，不替代最终完整应用的 Store 素材验收。

## 最终 App Store 截图顺序

| 图 | 实际画面 | 中文标题 | English title |
|---|---|---|---|
| 1 | 首页、任务找照片入口 | 从要求开始找照片 | Find photos for your requirements |
| 2 | 已有任务、找照片设置，人工入口可见 | 文件夹筛选，人工选图仍在 | Folder finding. Manual choice stays. |
| 3 | 真实候选和人数/原因 | 看清原因，由你决定 | Review the reasons. You decide. |
| 4 | 逐项裁剪估计 | 按每份要求估计裁剪像素 | Estimate crop pixels for each output |
| 5 | 截图要求提取与确认 | 要求逐项核对后保存 | Verify requirements before saving |
| 6 | 成片总览与 ZIP 清单 | 逐份实测，打包交付 | Check actual files. Deliver together. |

避免“官方认证”“保证通过”“AI 自动选出合规照”“全相册自动分类”。示例和估计在截图中保留标识，不隐藏人工核对提示。除明确允许的展示排版外，不伪造功能状态或涂改检测结果。

## 采集要求

- 选择最终签名构建和版本号后，从正常应用流程再走一遍，屏幕内容与可下载二进制一致。
- 按 ASC 当前支持的 iPhone 截图设备类别和尺寸准备；iPhone 13 工程图不能直接宣称是所有大屏尺寸的原生截图。iPad 兼容模式另做实际走查，若 ASC 要求对应素材，需在相应设备采集。
- EN/ZH、正常字级、明暗模式核对；截图不包含私人目录、姓名、证件、通知或账号信息。
- 工程测试截图记录设备、日期、源码提交与生成方式；不把 widget render 当真机截图。

## 60–90 秒审核演示

首页 AI 找照片 → 选示例任务 → 展开任务要求 → 示例照片真实检测 → 单人/多人/无脸原因 → 各输出裁剪像素 → 明确采用、替换确认 → 手工调整并制作两份输出 → 文件总览与交付。另展示人工选图入口和停止/清除。目录授权、Photos/相机及 iPad 兼容模式须独立测试，不能从示例推断已验收。
