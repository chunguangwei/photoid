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

## 推理可行性核实（2026-11-10，实测图文件）

- q4f16 两图用 **`com.microsoft.MatMulNBits`**（model_q4f16 ×146、vision_encoder_q4f16 ×113），
  不是标准 MatMul4Bit。当前打包引擎：`onnxruntime` pub 插件 → `onnxruntime-c` pod **1.15.1**。
  该 xcframework 二进制内 `com.microsoft`/contrib 字符串 103 处命中，contrib 算子
  （含 MatMulNBits）为编译内置，积极信号；但 kernel 注册与 1.15.1 对 Gemma4 图
  （q4f16 新格式）的完备性仍需真机冒烟：发布 manifest 前必须加载 model_q4f16 +
  vision_encoder_q4f16 各跑一次前向。失败则先升级引擎或回退 `*_quantized` int8 变体——
  打包体积从 ~287MB 变 ~540MB（314+195+32），对用户承诺的下载大小随之改写。
- **图契约（从 .onnx 字符串实测）**：文本图暴露 `input_ids`/`attention_mask` 且直接接收
  `image_features`（图内出现 41 次，含 embedding_projection 融合分支），**没有** `inputs_embeds`；
  视觉图输入 `pixel_values` 输出 `image_features`。
  因此逐图嵌入 = vision_encoder(pixel_values) → 文本图(input_ids 含 `<|image|>` 占位 + image_features)
  → 池化 768 维——每张照片仍跑整个 270M 文本骨干（prefill 280 vision token），
  吞吐验收按此估算，不是只跑 170M 视觉塔。
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
- 分词：tokenizer.json 的 SentencePiece unigram 在 Dart 侧实现（词表+分数一次性加载），
  用官方 README 样例做 golden token 对拍测试；分词不匹配即视为模型损坏，禁用加强版。
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
