# Application photo delivery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 保留现有照片工具，增加可恢复的多版本报名文件交付与独立文件检查。
**Architecture:** 独立纯文件检查、Documents 中原子写入的任务仓库、ZIP 交付服务；页面复用 CustomSpecPage / EditPage / ResultPage，通过可选回调接入，不改变旧路由行为。
**Tech Stack:** Flutter, image, path_provider, archive, file_selector, share_plus。
**Spec:** docs/superpowers/specs/2026-10-21-application-delivery-design.md

## Global Constraints
- 保留全部原功能；双语/深浅主题；不新增云照片处理/账号/广告。
- 每任务最多 5 输出；文件名唯一 ASCII 1–80；30MB/24MP 输入上限。
- 不保证审核；来源链接仅保存不验证；机器属性与人像建议明确分开。
- 本机原工作区 Info.plist 重排属于已有改动，不纳入本次提交。

## Review Focus
- 原文件 PNG/损坏/过大：检查准确失败、不改写、不进入无限加载。
- 改要求或替换原图：旧输出必须失效，不能混入交付包。
- 文件缺失/同名/路径穿越/中断：导出明确失败，其他任务仍能加载。
- 退出页面/快速保存/取消选择：异步状态安全、数据不丢失。
- 320px 130% 双语/深浅主题：操作能滚动到，无横向溢出。

### Task 1: 文件属性检查
**Files:** lib/services/photo_file_inspection.dart, test/photo_file_inspection_test.dart
**Interfaces:** inspectPhotoFile(Uint8List, PhotoSpec) -> PhotoFileInspection；toJson、hardAllPass、readable(locale)。
- [x] 写测试：JPEG 精确尺寸/KB、PNG 格式不通过、损坏、超过限制，记录输入字节不变。
- [x] 运行测试验证缺少功能失败。
- [x] 实现 worker/isolate 可用纯检查，区分实际数值与要求。
- [x] 测试绿；提交。

### Task 2: 任务持久化与交付包
**Files:** lib/models/application_task.dart, lib/services/application_task_store.dart, lib/services/application_delivery.dart, test/application_task_store_test.dart, test/application_delivery_test.dart
**Interfaces:** ApplicationTaskStore(Directory), create/list/get, metadata/source/output mutation; ApplicationDelivery.build(task, store, cacheDirectory, locale) -> File ZIP。
- [x] 写并运行失败测试：恢复任务、多输出、并发追加、改要求/源图失效、坏记录隔离、安全命名、ZIP 原字节与清单一致、文件缺失拒绝、过期缓存。
- [x] 实现原子 JSON、串行 mutation、受限文件读写、导出重新检查，不将分享结果当保存。
- [x] 测试绿；提交。

### Task 3: 任务与独立检查页面
**Files:** lib/pages/application_tasks_page.dart, application_task_page.dart, photo_check_page.dart; 修改 home_page/custom_spec_page/edit_page/result_page；lib/l10n/app_*.arb；test/application_workflow_test.dart。
**Interfaces:** CustomSpecPage(onCreated?, initialSpec?); EditPage(onDelivered?, fixedRequirements=false); 回调 (bytes,spec) 异步保存；ResultPage 同步接入并保留原按钮。
- [x] 写并运行失败 widget 测试：新首页入口、创建恢复任务、需求/输出添加、已有照片选择取消及文件报告、小屏双语布局。
- [x] 新增所有双语文案与路由、文件选择、状态错误/取消/加载、回调保存与多版本导出；复用原功能。
- [x] targeted 与全量测试绿，静态分析；提交。

### Task 4: 审核资料、UI 预览与真机
**Files:** docs/release/1.1-build49/*, docs/privacy-policy.md, README.md, UI capture；pubspec.yaml。
- [ ] 更新隐私与商店文案、前后功能对照、可复现示例；标注截图/外部审核状态，不声称已获认可。
- [ ] 全量 flutter test、dart analyze、双语深浅布局预览，独立代码复核。
- [ ] 构建 iOS release 并安装已连接 iPhone；构建 Android；不自动发布或上传 ASC。
- [ ] 修复复核阻塞问题，保留完整证据记录，完成代码提交及工作区整合。

## Execution ledger
用户已确认上轮完整功能范围，直接在独立工作区按原生方式执行，避免再次要求确认同一范围。文案与配置小变更不写实现镜像测试；功能行为使用测试验证。

## 验证进展

- 基线 128 项通过；新增功能/边界/交互后全量 153 项通过；静态分析 No issues found。
- 36 张本地页面渲染通过，其中新增流程与首页的 20 张已保存 docs/ui-preview-1.1；渲染不代表系统相机/Files/分享已验收。
- 独立代码审查：修复恢复底色时对象不匹配、ZIP 生成快照/页面退出后的分享竞态、截图更新缓存问题；新增回归覆盖恢复表单、串行快照、截图路径版本。
- 决策：本轮不做 OCR；从 Files 检查原字节，图库的系统转换副本明确提示；多版本分别手动裁剪，不能宣传一键全自动。
- 决策：用 returnSpec 可选参数复用现有自定义规格页，旧路由继续保存个人规格，不把任务输出写入旧全局列表。
- Android/iOS 构建均成功；iPhone 13 覆盖安装成功并确认 1.1.0 (49)，设备启动被 Security 拒绝，等待开发者信任/弹窗核对；不会自动上传或提交 ASC。
