# 加强版语义找照片：EmbeddingGemma 2（无音频）设计

日期：2026-11-10。状态：设计定稿，待实现。前置：批量找照片已上线（1.2.0/54）。

## 目标与范围

- 首页找照片增加「加强版」能力：下载 EmbeddingGemma 2 后，支持用一句话描述来找照片
  （如"去年在办公室穿正装的照片"），对已选批次做语义排序；基础检测（人脸/尺寸/画质）不变。
- 「我的」页新增「图片处理模型」入口：查看状态、下载/暂停/取消、显示体积、删除。
- 首次开启加强版：弹下载确认（大小 + Wi-Fi 提示 + 隐私说明），确认即开始下载。
- 不下载音频编码器：官方 ONNX 模块化转换把 audio encoder 独立成文件，直接不拉取，
  体积从 ~457MB（q4f16 三件套）降到 ~287MB。

## 模型选型（2026-11-10 核实）

- google/embeddinggemma-2：740M = 文本 270M + 视觉 170M + 音频 300M，Apache 2.0，
  统一 768 维向量空间，支持 Matryoshka 截断与任务指令前缀（仅文本前缀，图片不加）。
- 推理格式采用 onnx-community/embeddinggemma-2-ONNX（本仓库 onnxruntime 已有依赖），
  模块化文件，按需只下 text + vision：
  - `model_q4f16.onnx`(495KB)+`model_q4f16.onnx_data`(157MB)：文本骨干
  - `vision_encoder_q4f16.onnx`(151KB)+`vision_encoder_q4f16.onnx_data`(97.6MB)：图像塔
  - `tokenizer.json`(32.2MB)+config/chat_template/preprocessor 若干（<40KB）
  - 合计 ≈ 287MB；音频 `audio_encoder_q4f16*`(170MB) 整块跳过；fp16/q4 变体不下载。
- 视觉 token 预算、图像 resize 参数、mean pooling、L2 归一化与查询前缀文案，
  以该 README「Best Practices」为准，实现时固化为常量并做参考向量对拍。

- **引擎门槛审计（实测图头）**：q4f16 与 int8 `*_quantized` 变体**同样**要求
  ai.onnx **opset 21** + com.microsoft 算子 `GatherBlockQuantized`（约 ORT ≥1.20）
  /`MatMulNBits`/`RotaryEmbedding`/`SkipSimplifiedLayerNormalization`/`MultiHeadAttention`。
  当前 pub 插件（onnxruntime 1.4.1，已为最新）podspec 钉死 `onnxruntime-objc 1.15.1`
  ——**现有引擎加载不了 q4f16 图，int8 也救不了**。决策：**升级引擎**
  （Podfile 显式声明 onnxruntime-objc/c ≥1.21 覆盖插件默认，Android 同步升
  com.microsoft.onnxruntime AAR；ORT C API 向后兼容，插件封装不动），
  升级后 MatuNet 现有链路回归 + q4f16 真机前向作为验收 #0；
  若真机不通过，唯一备选是自导出降级图（工作量大，暂不承诺）。

## 可行性冒烟结论（2026-11-10，验收 #0/#3 桌面等效，host ORT 1.27 CPU）

- **验收 #0 真机通过（iPhone 13）**：fork 插件（`plugins/onnxruntime`，代码同 1.4.1，
  podspec 引擎 1.15.1→**onnxruntime-objc/c 1.30.0**；Android 同 fork 内 jniLibs 换
  官方 1.30.0 libonnxruntime.so）。`integration_test/ort_q4f16_smoke_test.dart`：
  双图加载 + 视觉塔（29 image token）+ 文本塔前向（sentence_embedding L2 归一），
  含会话构建总耗时 1.9s。MatuNet 全量 219 单测在 fork 下全绿。
  **q4f16 ≈287MB 方案定案**，int8 回退不再需要。
  测试注意：集成测试会重装 App 重建容器，模型文件须边跑边推（devicectl copy），
  且必须按字节数轮询到传输完整再加载（存在≠完整）。

- 双图加载通过（MatMulNBits 正常执行）；真实照片端到端：视觉塔输出 29×512 图像 token
  （图内聚合 280 patch），文本塔融合后 `sentence_embedding` 输出 768 维且已 L2 归一化，
  全程 NaN-free。
- 语义效果冒烟：真实人像 + 3 张合成图（天空/草地/红墙），中英各 4 条查询，
  **8/8 排序第一命中**，命中-次名分离度 ≈ 0.06–0.10（如"红色的墙壁"：红墙 0.723 vs 次名 0.636）。
  随机 N(0,1) 假像素会致视觉塔饱和（-FLT_MAX），真实 /255 像素无此问题——
  实现时预处理必须严格按 image_processor（resize + /255，无 normalize）。
- 查询用官方非对称前缀 `task: search result | query: {q}`；图片不加前缀。
- 吞吐（M 系 CPU，4 线程）：每张嵌入 ≈0.2s、查询 0.02s；500 张顺序批嵌 ~100s，
  分批 + 进度 + 可取消按原设计执行；iPhone 13 真机数值另测（验收 #3）。
- 待办（真机阶段）：目标 ORT（pod 1.15.1）同图冒烟 + opset 审计见下节；
  不通过再谈升引擎或 int8 回退。

## 推理可行性核实（2026-11-10，实测图文件）

- q4f16 两图用 **`com.microsoft.MatMulNBits`**（model_q4f16 ×146、vision_encoder_q4f16 ×113），
  不是标准 MatMul4Bit。当前打包引擎：`onnxruntime` pub 插件 → `onnxruntime-c` pod **1.15.1**。
  该 xcframework 二进制内 `com.microsoft`/contrib 字符串 103 处命中，contrib 算子
  （含 MatMulNBits）为编译内置，积极信号；但 kernel 注册与 1.15.1 对 Gemma4 图
  （q4f16 新格式）的完备性仍需真机冒烟：发布 manifest 前必须加载 model_q4f16 +
  vision_encoder_q4f16 各跑一次前向。失败则先升级引擎或回退 `*_quantized` int8 变体——
  打包体积从 ~287MB 变 ~540MB（314+195+32），对用户承诺的下载大小随之改写。
- **图契约（实测 + 前向验证）**：文本图暴露 `input_ids`/`attention_mask` +
  `image_features`/`video_features`/`audio_features`（图内 multimodal_merge 融合），
  **没有** `inputs_embeds`，输出含现成的 `sentence_embedding`（768 维、L2 归一化）。
  视觉塔把 280 patch **聚合为约 29 个 512 维 token**（非 1:1 展开），
  每张图的文本塔增量只有 ~29 token prefill，成本远低于最初按 280 token 的估算。
  **融合布局（桌面排序对拍定案）**：`input_ids = [bos] + n×258880(<|image|>) +
  [eos]`，占位数 = `image_features` 行数 n；`video/audio_features` 传 `[0,512]`
  空张量；输出取第 2 个 `sentence_embedding`。**单占位 `[2,4642,IMG,1]`
  被否决**：merge 只消费 1 行特征，其余聚合 token 丢弃——4 图中英 8 查询
  排序 n 占位 8/8 top-1（margin .008–.038）vs 单占位 3/8（margin ≤.014）。
  真机冒烟当时用单占位仅证明有限性，不证明语义。
  参考实现固化于 `scripts/embedding_reference.py` +
  `test/fixtures/embedding_golden.json`（真实人像 cos 基准）；
  真机端到端对拍见 `integration_test/enhanced_golden_test.dart`（验收 #1）。
- 图像预处理实为轻量（image_processor 实测）：`do_resize` + `rescale 1/255`，
  `do_normalize=false`（mean 0/std 1），RGB，`image_seq_length=280`。
  Gemma4AudioFeatureExtractor 参数与已删音频一并忽略。
- 量化质量（官方表，最坏余弦 vs fp32）：q4f16/q4 = 0.975（文本塔 0.988）、q8 = 0.9997。
  语义排序场景接受 q4f16；若用户侧质量反馈差，同 manifest 结构可换 q8 变体（体积 3×）。

## 下载稳定性（国内外）

- 每个文件内嵌清单：文件名、字节数、SHA-256（HF 与 ModelScope 元数据一致后才发布）。
- 源站候选（沿用 UpdateService 探测模式，Range 1 字节、4s 超时、按序回退）：
  1. `https://hf-mirror.com/onnx-community/embeddinggemma-2-ONNX/resolve/main/`（国内，已实测连通）
  2. `https://huggingface.co/onnx-community/embeddinggemma-2-ONNX/resolve/main/`
  3. ModelScope 镜像 `onnx-community/embeddinggemma-2-ONNX`
     （已实测其 API 列出 31 个 onnx 文件，含 q4f16 视觉塔；发布前逐文件核对 SHA-256）
- 断点续传：临时文件 + `Range` 续传；整文件 SHA-256 校验后原子改名；校验失败换源重下。
- 一次会话记住可用源；全部失败保留进度，用户可稍后继续。下载失败不阻塞基础筛选。
- 磁盘检查：剩余空间 < 600MB（模型 + 双份缓冲）时先提示。执行下载来的数据，不执行下载来的代码。

## App 侧架构

- `services/embedding_model_store.dart`：清单、探测、续传、校验、状态（未装/下载中/就绪/损坏）、
  占用统计与删除；沿用 ApplicationTaskStore 的原子发布风格。
- `services/embedding_session.dart`：onnxruntime isolate 加载双编码器，
  逐图有界嵌入（复用 photo_finder_session 的 foreground/cancel 语义），
  768 维向量按候选 id 缓存于内存（不持久化，防跨库串数据）。
- 分词：Gemma BPE（vocab 262144 + merges 514906、byte_fallback、
  Split(" ", MergedWithPrevious) 预分词、TemplateProcessing `<bos>…<eos>`）
  纯 Dart 实现（`services/gemma_tokenizer.dart`），
  与 HF tokenizers 逐 id 对拍 `test/fixtures/tokenizer_golden.json`（16 条）；
  分词不匹配即视为模型损坏，禁用加强版。
- UI：
  - 「我的」→「图片处理模型」：状态卡（大小/源/进度/速度）、下载/暂停/删除；仅 Wi-Fi 默认开，可改。
  - 找照片页：加强版开关；未装模型时开启即弹下载确认（约 287MB、本地运行、不上传）。
    开启后结果列表顶部出现语义搜索框，输入即对当前批次重排（相似度分数仅用于排序，不显示"匹配度%"）。
  - 冷启动动画不变。

## 隐私与文案

- 照片与查询文本全程本机推理；下载只拉模型文件。隐私政策补一句加强版说明。
- 商店文案不承诺搜索质量："加强版为语义参考排序，不保证检索结果"。

## 验收

0. 真机冒烟：现有打包 ORT（onnxruntime-c 1.15.1）加载 model_q4f16 + vision_encoder_q4f16
   （MatMulNBits，contrib opset com.microsoft）；失败则先升级引擎或切 int8 `*_quantized`
   并改写体积承诺，再发布 manifest。
1. 分词 golden 对拍；text/vision 参考向量与 transformers.js 同输入余弦 ≥ 0.999。
2. 断点：下载中断 3 次仍能续传完成且 SHA 通过；三源逐个拔线演练。
3. 500 张批次嵌入吞吐：iPhone 13 上记录并设定上限（超 30s 分批+进度可取消）。
4. 关闭/删除模型后基础流程零回归；基础筛选不受模型状态影响。
5. 现有 218 个测试全绿 + 新增上述测试。
