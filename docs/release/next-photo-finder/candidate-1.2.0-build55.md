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
  对拍 HF tokenizers golden 16/16）+ `embedding_session.dart`
  （isolate 内双图推理；查询前缀 `task: search result | query: `；
  单 `<|image|>` 占位融合布局，与真机冒烟一致）。
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
- 加强版 UI 交互测试（注入假 store：未装→弹下载；就绪→出搜索框）
- 既有 219 测试基线全绿；`flutter build ios --release` 通过。
- 真机：iPhone 13 实测下载（国内源）与 500 张批嵌吞吐、排序体验。
