# 1.2.0 候选 build 55：加强版语义找照片（EmbeddingGemma 2）

## 目标

找照片页新增可选「加强版」：用 EmbeddingGemma 2 q4f16（约 287MB，去音频塔）
在设备本地对当前批次照片生成语义向量，按查询相似度重排候选。全程不上传
照片；只影响排序，不改变人脸检测/画质分组结论。设计见
`docs/superpowers/specs/2026-11-10-embeddinggemma-enhanced-search-design.md`。

## 内容

- 引擎：fork 插件 `plugins/onnxruntime`（同 pub 1.4.1 代码）钉
  onnxruntime-objc 1.30.0、Android jniLibs 双 ABI 换 1.30.0（已审计
  GatherBlockQuantized×62、e_machine 正确）。q4f16 图需 opset21 +
  MatMulNBits/GatherBlockQuantized，原 1.15.1 无法加载（9f764e1）。
  真机冒烟 `integration_test/ort_q4f16_smoke_test.dart` 通过
  （29 image tokens，1895ms）。ModNet 回归 219 全绿。
- 下载：`lib/services/embedding_model_store.dart` 三源
  （hf-mirror / huggingface / ModelScope）+ SHA-256 校验 + `.part`
  断点续传；「我的→图片处理模型」管理页（下载/暂停/删除/仅 Wi-Fi 偏好；
  状态含未装/部分/下载中进度条/就绪/损坏）。
- 推理：`lib/services/gemma_tokenizer.dart`（Gemma BPE 纯 Dart 移植，
  对拍 HF tokenizers golden 16/16，查询逐 id 与 HF 原生一致）+
  `embedding_session.dart`（isolate 内双图推理；查询前缀
  `task: search result | query: `；n×`<|image|>` 占位融合（占位数=特征
  行数；排序对拍 n 占位 8/8 vs 单占位 3/8 定案）；resize bilinear 对齐
  出厂实现（PIL 默认 bicubic 偏移 ~3%，golden 已按 BILINEAR 生成））。
  golden 参考：`scripts/embedding_reference.py` +
  `test/fixtures/embedding_golden.json`、`tokenizer_golden.json`。
- UI：找照片页加强版开关（首次开启提示下载 ~287MB）、语义搜索框、
  排序进度/可停止；未评分照片保持原序。文案含「语义参考排序」声明。
- 隐私：政策（App 内 + docs/privacy-policy.md）补加强版段落。
- 版本号 1.2.0（55）。

## 效果基准

桌面 ORT 1.27（真实人像 + 3 合成图）中英各 4 查询 8/8 top-1，
分离度 0.06–0.12；商店文案不承诺检索质量。

## 验证

- `test/embedding_model_store_test.dart`（loopback 假源：进度/续传/校验/切换源）
- `test/gemma_tokenizer_test.dart`（golden 16/16 逐 id 一致）
- `test/embedding_patch_test.dart`（patch 布局对拍 numpy golden）
- golden 对拍分两档（同实现 fp32 才是 0.999 标准；同为 q4f16 跨 ORT
  版本实测 ~0.987，官方 q4f16 最坏余弦表文本塔 0.988）：
  文本向量 ≥0.98、图像向量 ≥0.95（再叠 PIL vs package:image bilinear 差）。
  真机实测（iPhone 13, ORT 1.30）：q1 0.9868 / q2 0.9887 / portrait
  0.9586，全部通过 → 验收 #1。
- 加强版 UI 交互测试（注入假 store：未装→弹下载；就绪→出搜索框；
  提交→排序启动进度行出现）
- 全量 `flutter test` 248 全绿（基线 219 + 新增 29）；store 套件 20 连跑无抖动；
  `flutter build ios --release` 通过并已装 iPhone 13。
- 真机待用户复核：App 内下载（三源，本机网络 DNS 解析 modelscope.cn 失败时
  按序回退 hf-mirror）、500 张批嵌吞吐（验收 #3）、排序体验。
