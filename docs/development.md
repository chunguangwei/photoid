# PhotoID 开发文档（Development Guide）

面向贡献者与维护者的架构与流程说明。用户-facing 介绍见 [README](../README.md)。
English readers: the codebase comments and ARB sources are authoritative; this
doc mirrors them in Chinese.

- 技术栈：Flutter 3.47.2（Dart ^3.5.0）
- 端侧 AI：MODNet（ONNX Runtime）人像抠图 + Google ML Kit Face Detection
- 图像处理：`image` 包 + 自研原始缓冲区算子（`photo_effects.dart`）
- 平台：Android 8.0+（minSdk 26）/ iOS 15.5+
- 仓库：https://github.com/chunguangwei/photoid
- 联系：chunguangwee@gmail.com

---

## 1. 项目结构

```
lib/
├── main.dart                 # 入口：MaterialApp + 本地化 + 更新检查
├── models/
│   └── photo_spec.dart       # PhotoSpec / SpecBackground 模型、五色底常量、学生报名照规格
├── services/                 # 纯逻辑层，不依赖 BuildContext（可单测）
│   ├── image_pipeline.dart   # 处理流水线：抠图→换底→构图→压缩；含全部 isolate 入口
│   ├── modnet_segmenter.dart # MODNet ONNX 人像抠图（常驻 worker isolate）
│   ├── photo_effects.dart    # 面部精修 / 画质清晰度两条效果通道
│   ├── compliance_service.dart # 合规检测引擎
│   ├── spec_library.dart     # 内置规格库加载/搜索（assets/photo_specs.json）
│   ├── custom_spec_store.dart  # 自定义规格持久化（SharedPreferences）
│   ├── album_service.dart    # 本地相册（保存/列表/删除）
│   ├── locale_service.dart   # 语言覆盖（ValueNotifier + 持久化）
│   └── update_service.dart   # GitHub Release 自升级检查
├── pages/                    # UI 层（依赖 BuildContext 做 i18n）
│   ├── splash_page.dart      # 启动页：全 Dart 矢量吉祥物 + 眨眼 + MODNet 预热
│   ├── home_page.dart        # 主页骨架：底部 NavigationBar 双 Tab
│   │                         #   （首页 / 我的，IndexedStack）；首页 Tab =
│   │                         #   品牌渐变头→2×2 主功能大卡（拍证件照/换底色/
│   │                         #   改KB/我的相册）→次级小工具（自定义规格）→
│   │                         #   隐私横幅→搜索→热门锚点规格→「全部规格(33)」
│   │                         #   折叠区
│   ├── settings_page.dart    # 「我的」Tab：我的相册入口 + 检查更新(Android)
│   │                         #   + 隐私说明 + 关于（版本/许可/邮箱）
│   ├── camera_page.dart      # 拍摄：前后置切换 + 人像轮廓虚线参考框
│   ├── edit_page.dart        # 编辑：流水线进度 + 底色切换 + 精修档 +
│   │                         #   美颜/清晰度双滑杆 + 交互裁剪
│   ├── crop_editor.dart      # 图版截取式裁剪编辑器（固定比例窗 + 缩放平移）
│   ├── scan_effect.dart      # 扫描揭色 / 扫描叠加 / 体感进度条（见 §2.2）
│   ├── result_page.dart      # 结果：合规检测报告 + 保存
│   ├── spec_detail_page.dart # 规格详情：三栏参数卡 + 五色底色选择
│   │                         #   （默认色带「· 推荐」标记）+ 要求清单
│   │                         #   + 底部上传/拍摄双按钮
│   ├── custom_spec_page.dart # 自定义规格
│   ├── kb_tool_page.dart     # 改 KB 工具
│   ├── my_album_page.dart    # 我的相册
│   └── update_dialog.dart    # 升级对话框：下载 APK → FileProvider 安装
├── l10n/                     # 国际化
│   ├── app_zh.arb / app_en.arb        # 翻译源（唯一真源）
│   ├── app_localizations*.dart        # flutter gen-l10n 生成物（勿手改）
│   └── l10n_helpers.dart              # Tr 翻译层（语义标识 → l10n 键）
assets/                       # 只放**运行时真正 load** 的资源
├── photo_specs.json          # 33+ 条内置规格
└── models/hivision_modnet.onnx  # MODNet 抠图模型（约 26MB）
logo/                         # 图标设计源与构建期产物（不打进包体，见 §6）
test/                         # 服务层与关键 UI 单测
```

分层约定：`services/` 与 `models/` 是**纯 Dart**（不 import flutter material、
不碰 BuildContext），全部文案以稳定语义标识输出；本地化由 `pages/` 层通过
`Tr` 完成。这保证服务层可脱离平台单测。

`assets:` 只列运行时会 `load` 的文件。图标 PNG 属于构建期输入，放 `logo/`
而不是 `assets/`——曾经误列进去，白白多打约 1.4MB 进包体。

## 2. 核心流程

```
拍摄(camera) / 相册上传(image_picker)
        │
        ▼
ImagePipeline.run()（edit_page 触发；PipelineStep 共 6 项，UI 逐条映射 l10n 进度文案）
  ① preparing   UI 初态（run() 开始前由 EditPage 展示，流水线本身不回调）
  ② reading     [isolate] 解码 + EXIF 归一化 + 前置镜像补偿 + 限边缩放
                （最长边 1440）+ 顺带编出 ML Kit 输入图（≤960px/q85）
  ③ segmenting  **串行**：ML Kit 人脸检测（原生线程）→ 按人脸粗裁人像 ROI
                → MODNet 抠图（worker isolate）。见 §2.3「抠图前粗裁 ROI」
  ④ compositing [isolate] 掩码精修（膝点映射+主体过滤）→ 前景色解混 → 换底合成 → 自动构图
                → 按构图框越界量补底色边 → 编出预览 JPEG
  ⑤ framing     [isolate] 底色补边裁剪 → 规格缩放 → 效果通道 → 轻锐化
  ⑥ compressing 二分压缩 jpg，落到规格的 [minFileKb, maxFileKb]
        │
        ▼
ComplianceService（result_page 触发）
  对最终 jpg 逐项检测：format / fileSize / decodable / pixelSize /
  bestSize / ratio / blueBg / faceDetected / headRatio / headCentered / eyesOpen
  （soft 项不通过不阻断保存）
        │
        ▼
保存（result_page / my_album）
  AlbumService 写应用私有目录；gal 可选保存到系统相册；
  学生报名照按教育 ID 命名文件
```

错误与进度同样以语义标识传递：`PipelineException.code`（readPhoto / noPerson /
noFace 等）和 `PipelineStep` 枚举，由 UI 层翻译展示。

**ML Kit 输入双平台分路（`_inputImage`）**：流水线的分割与人脸检测共用同一份
工作图写出的临时 jpg（无 EXIF，保证掩码/人脸框坐标对齐），但构造
`InputImage` 时按平台分路——

- **Android**：`InputImage.fromFilePath` 不挂 `MediaImage`，ML Kit 原生层处理
  时 NPE（已知 bug），故改走 `InputImage.fromBytes`：工作图 RGBA 经
  `_rgbaToNv21`（BT.601 全幅转换、2×2 色度子采样，在 `compute` isolate 内
  执行）转为 NV21 字节流，附 `InputImageMetadata`（尺寸 / rotation0deg /
  `InputImageFormat.nv21`）。**奇数宽/高修复**：色度平面尺寸按
  `ceil(w/2)×ceil(h/2)` 分配，否则 `RangeError`。合规检测的人脸项在
  Android 同样走 NV21（`_faceChecks` 复用 `rgbaToNv21`），iOS 仍写临时
  jpg 后 `InputImage.fromFile`。
- **iOS**：`InputImage.fromFile` 工作正常，保持原路径不转码。

### 2.1 线程模型（硬约束，改动勿回退）

**主 isolate 不做任何像素级运算。** 解码、抠图、掩码精修、合成、裁剪、
缩放、效果、JPEG 编码全部在后台 isolate。

这条约束是踩过坑换来的：早期版本把 `gaussianBlur`、`copyCrop`、
`resizeToSpecUniform` 以及 `encodeToKbRange` 的**最多 10 次 JPEG 编码**
留在主 isolate，导致处理页整页冻结数秒——表现为「扫描动效和进度条卡顿」，
但根因不在动效，优化动画完全无效。同理，点「保存」时的成片生成也必须
异步化（`_goResult` 走 `compute`），否则点击瞬间整页冻结。

isolate 入口一览（均为 `image_pipeline.dart` 顶层函数，可被 `compute` 调用）：

| 入口 | 职责 |
| --- | --- |
| `_loadWork` | 解码 / EXIF / 镜像 / 限边缩放 / ML 输入编码 |
| `_compositeWork` | 掩码精修 + 解混 + 合成 + 自动构图 + 补边 + 预览编码 |
| `deliverWorker` | 裁剪 + 规格缩放 + 效果 + 锐化 + 二分压缩（**出片唯一路径**） |
| `previewWorker` | 工作图上应用效果并编码预览 |
| `cropRgbaWorker` | 抠图前的人像 ROI 粗裁 |
| `recolorWorker` | 换底色（一次 alpha 混合，不重跑抠图） |
| `rgbaToNv21` | RGBA → NV21（ML Kit Android 输入） |

`deliverWorker` 被「首次出片」「用户改裁剪框」「用户改效果强度」三条路径
复用，保证预览与成片走完全相同的参数与算法，不会出现「预览好看、导出不一样」。

**换底色不重跑流水线**：掩码、解混后的前景色、构图框都与底色无关，重跑等于
白白再做一次 MODNet 推理（最贵的一步），用户每点一次色块都要重看一遍进度条。
故 `_compositeWork` 额外输出**补边坐标系下的前景 RGBA 与 alpha**，
`PipelineResult` 一并持有，换底只需 `recolorWorker` 做一次 O(n) alpha 混合
（几十毫秒），用户已调好的取景框与效果强度全部保留。代价是处理页多驻留约
8MB（前景 4B/px + alpha 1B/px）。

`DeliveryRequest` / `PreviewRequest` 里带了 `dart:ui` 的 `Rect`。跨 isolate
传参契约由 `test/isolate_delivery_test.dart` 用**真实 `compute`** 覆盖——
纯函数单测和静态分析都发现不了序列化问题。

MODNet 另有一个**常驻 worker isolate**（`ModnetSegmenter`）：spawn 一次、
`OrtEnv`/`OrtSession` 各建一次并复用，任务经 `ReceivePort` 串行处理。
`ModnetSegmenter.warmUp()` 在启动页 6 秒空闲期预热（落盘 26MB 模型 +
建会话），首张照片的等待感因此大幅缩短。

### 2.2 动效的性能写法

`scan_effect.dart` 里的全部动效都用 `CustomPaint` +
`super(repaint: controller)`，并包 `RepaintBoundary`：

- 只触发**重绘**，不触发 rebuild / relayout；
- 渐变着色器按尺寸缓存，动画期间不重建。

反例（已被替换）：用 `AnimatedBuilder` 每帧重建 `Container` +
`BoxDecoration(LinearGradient)`，等于每帧新建并编译一次 shader，
还脏化整棵子树。

**三个组件的分工**：

| 组件 | 用途 | 形态 |
| --- | --- | --- |
| `ScanRevealEffect` | 流水线处理中（照片卡） | **包裹** child：灰度层作底，原色层按进度自上而下 `ClipRect` 揭开 + 光带 + 四角括号 |
| `ScanOverlayEffect` | 效果重算中（预览区） | 只**覆盖**：同一套光带/括号，未扫区压暗，不做灰→彩 |
| `SmoothProgressBar` | 步骤进度 | 向目标值缓动，≤0.97 |

「灰度 → 彩色」的方向天然隐喻「原始 → 已修好」，同时把「正在处理」与
「处理到哪了」两层信息一并给到用户，**不依赖任何文字**。

重算中的预览区**不能**用 `ScanRevealEffect`：它需要把 child 实例化两份
（灰度底 + 原色层），而底下是自带 `key`、内部持有手势与解码状态的
`CropEditor`，复制会导致状态错乱。故拆出只覆盖不包裹的
`ScanOverlayEffect`。

### 2.3 抠图与构图算法

#### 抠图前粗裁 ROI（决定掩码质量的上限）

MODNet 输入**恒为 512×512**。整张全身照直接压过去，头肩在 512 图里可能
只剩几十像素——模型分不清「黑裙子」和「草地阴影」，换底后画面里残留成片
的地面色块；而且这些块与人体连通，`keepMainSubject()` 也清不掉。

所以顺序必须是**先人脸、后抠图**：`matteRoiFor()` 按人脸尺度框出 ROI，
`cropRgbaWorker` 裁出来再送模型。人像在模型输入里的占比提升数倍，边缘判别
是量级差异。代价是人脸检测与抠图由并行改串行（人脸检测通常百毫秒级，值得）。

**ROI 必须按人脸尺度取，不能按构图框取。** 曾经写成「构图框 × 1.45」，
结果把肩膀裁掉了——构图框宽只有其高的 0.75（证件照比例），乘 1.45 依然窄于
人的肩宽，ROI 边界从肩膀中间切过，掩码在边界被硬切，成片里人物两侧被削平成
纯底色（用户反馈「没有肩膀」）。人体比例是稳定的，所以按脸给足：

```
横向：中线左右各 3.2 个脸宽（总宽 6.4 脸宽，肩宽约 2.5–3 脸宽）
纵向：头顶上方 1.6 个脸高、下巴下方 4.0 个脸高
```

两条保守约束：

- **只裁不补**：ROI 一定钳进源图内。越界补边是构图阶段的语义，提前混进来
  会让坐标系含义不清；
- **收益不足就不裁**：人脸已占源图 **36%** 以上（本就是证件照/半身照），或
  ROI 面积 > 源图 72%，均返回 null 走原路径——裁了不改善精度，还多一重
  切到人体的风险。

这个阈值**刻意取宽**。原本是 28%，但手机广角镜头 + 自拍距离下人脸宽度常落在
28%–35% 之间，于是近景自拍也被粗裁，ROI 边界从肩膀上切过去——用户看到的就是
「处理后肩膀全没了」。同理横向余量从 2.6 提到 3.2 个脸宽。判断标准是：**宁可
不裁（顶多掩码精度差一点），也绝不能切到人体**。

#### 掩码精修：不腐蚀，但必须高端饱和

`refineAlpha()` 做三件事：3×3 均值轻羽化（抹掉 512→原尺寸上采样的阶梯）
→ **膝点映射** → `keepMainSubject()`。

**不做形态学腐蚀**。曾经的「消白边三件套」是 `(a-0.35)/0.5` 激进截断 + 3×3
min-filter 腐蚀 1px + 羽化，后果是全局腐蚀把人像轮廓向内啃掉一圈（发丝、
耳廓、肩线本就只有 1–2px，直接消失），激进截断又把半透明发丝带整体归零
——而**半透明过渡带恰恰是 MODNet 的价值所在**。用户侧表现是「头发没了」。

但「不腐蚀」不等于「映射可以对称」。修复上述问题时曾把映射放宽成
`[0.06, 0.94]` 线性拉伸，结果 MODNet 在衣服/肩背这类低对比区域输出的
`a≈0.7` 被原样保留成半透明，观感是**人物从胸口往下溶解进底色**。正确的
映射是**不对称的膝点**：

```
低端 lo=0.05  —— 只清背景残噪，发丝半透明带必须活着
高端 knee=0.60 —— 以上一律 255，人体主体不允许半透明
```

即旧版「高端饱和」是对的，只有「低端截断 + 腐蚀」是错的，两者必须分开判断。

#### 只留主体 + 填孔洞

`keepMainSubject()` 原地修正两类 MODNet 误判：

- **飞地**：画面角落的建筑、地面色块被判成前景，换底后成漂浮残块 →
  4 邻域 BFS 标连通域，面积不足最大域 25% 的整体归零；
- **孔洞**：躯干内部被判成背景，换底后身体上出现底色斑点 → 从图像四边
  flood fill 背景，未触达的背景像素即为洞，填 255。

注意连通域过滤**治不了与人体相连的误判**（如裙摆连着草地），那属于模型
输入精度问题，靠上面的 ROI 粗裁解决。

回归用例见 `test/matting_framing_test.dart`。

#### 消白边：在颜色层面解混，而非削 alpha

白边的物理成因是边缘像素本身混合了原背景色（常是白墙），直接按 alpha
合成会把原背景带进新底色。`decontaminate()` 的做法是把半透明边缘像素的
**颜色**替换为邻域内高不透明度像素的 alpha³ 加权平均色，**alpha 完全不动**：
两趟半径 2，开销可忽略，发丝通透感完整保留。

两条约束缺一不可，否则会产生**「头发外一圈白色光晕」**（曾经的线上回归）：

1. **只处理真正的边缘带**（`24 ≤ a ≤ 200`，取色只认 `a ≥ 224` 的实心前景）。
   放宽到 `[8, 240]` 会把大片中间调区域卷进来，等于拿邻域最亮色向外涂抹；
2. **只允许把颜色拉暗**（且强度上限 0.6）。白边是「被背景提亮」造成的，
   解混的物理方向只能是变暗；允许变亮就是在造光晕。

#### 构图：允许越界 + 底色补边

`cropRectFor()` 的关键设计是**裁剪框允许越出源图**，越界部分在交付时用底色
补齐。换底后背景是纯色，补边完全不可见；而旧版把框 `clamp` 进图内，
在人物顶天立地时必然切掉头顶或肩膀。

- 头顶定位优先用掩码测得的**真实发际线**（`detectHeadTop()`：自上而下
  第一条前景像素数达阈值、且连续 2 行命中的扫描线），人脸框只作兜底
  ——ML Kit 的框上沿在额头中部，直接用会切掉头发；
- **两道防线保证头高可信**（缺了会让人物在成片里又小又偏）：
  1. `detectHeadTop()` 命中行贴着上边缘（y ≤ 1）时返回 null——说明人像被
     画面或 ROI 截断，真实头顶在画外，此时用 0 会把头高严重高估；
  2. `cropRectFor()` 无条件把「头顶→下巴」钳进 `[1.15, 1.85] × 脸框高`。
     ML Kit 脸框（额头中部→下巴）与真实头高的比例本就稳定在这个区间；
     掩码若因误判（帽子、举手、背景残留连着头发）给出过高的 crown，
     画幅会按比例放大，人物随之缩小并偏移；
- 头部（头顶→下巴）占成片高 62%，头顶留白 11%；
- **底边不补色**：身体下方悬空一块纯色很假，底边超出时整体上移；
  顶边与两侧可自由补边（纯背景，不可见）；
- 画幅上限为源图 1.5 倍，防补边过量与内存放大。

补边发生在 `_compositeWork`（合成阶段）而非交付阶段，这样工作图坐标系里的
`autoCrop` 永远落在图内——`CropEditor` 是「窗口固定、图片可缩放平移」的
模型，表达不了越界的裁剪框，否则编辑器显示的初始构图会与实际成片对不上。

#### 一个易踩的坑

`img.Image(backgroundColor:)` **只是记录属性，不会真的写像素**，直接用会
得到全黑底（补边/补齐区域出现黑边）。必须显式 `img.fill()`——
见 `ImagePipeline._filled()`。

### 2.4 效果通道（photo_effects.dart）

两条**互相独立**的通道，均默认 0（不开启时字节级等同原图）：

| 通道 | 作用范围 | 算法 |
| --- | --- | --- |
| `retouchFace` 美颜 | 人脸椭圆内，按肤色权重加权 | **边缘保护表面模糊** + 匀肤 + 提亮 + 暖肤 + 轻度瘦脸 |
| `enhanceClarity` 清晰度 | 整图 | **亮度通道** USM + 局部对比 + S 曲线 + 鲜艳度 |
| `resizeSharpen` 缩放补偿 | 整图（交付前） | 半径 1 的亮度 USM，**无开关** |

**为什么拆两条**：它们解决的是两类问题，混在一个滑杆里必然互相拖累——
想让皮肤更干净就会连带把整图糊掉。

#### 磨皮：边缘判据必须用「局部梯度」，不能用「原图 vs 模糊图」

这一条踩了三次坑，每次的用户反馈都一样：**「拉满了也看不出效果」**。

1. 最早是「整图高斯 × 混合系数」，强度一大就糊五官，上限只能压到 75%；
2. 改单尺度频率分离，把「幅度 > 26」一律当五官结构**全额保留**——恰好把
   最刺眼的色斑排除在处理之外；
3. 改双尺度频率分离 + 阈值随强度放大，仍然要靠「幅度」区分瑕疵与五官。
   阈值定高了漏色斑，定低了糊五官，两次调参都没能同时满足。

根因是**判据选错了**。前三版都在用「幅度」或「原图与模糊图的差」判断
「这里是不是该保护的结构」，但一块色斑的内部与模糊图的差异同样很大
（它整体偏暗），于是**色斑自己被判成了边缘并保护起来**——最该磨掉的东西
恰恰是最被保护的，怎么调系数都没用。

现在改用 **surface blur**（姊妹项目 ImagePilot 三期迭代后的方案），并把
边缘判据换成**局部梯度**——即当前像素与四邻（步长 `radius/3`）的最大亮度
落差：

- 色斑、痘印、肤色不匀的**内部梯度 ≈ 0** → 全额混合，被周围皮肤色填平；
- 眼睑、唇线、鼻翼、发际这类结构**梯度大** → 混合权重压到 0，保持锐利；
- 眼球、眉毛内部梯度也小，但它们**非肤色**，`_skinWeight` 已置 0。

两道判据正交互补，因此不再存在「既要磨干净又不糊五官」的矛盾，也不存在
阈值悬崖（梯度是连续量）。最大混合比 `0.45 + 0.33 × intensity`（满强 0.78）。

此外还加了**提亮**（暗部抬得多、亮部几乎不动）与**暖肤**（红通道单独微增
`4 × intensity`）。人对「气色好」的判断主要来自肤色暖度而非光滑度，这两项
的可感知收益比继续加大磨皮强度高得多，且不损失任何细节。

#### 肤色判据必须用色度域软权重

`_skinWeight()` 走 YCbCr：`Cb ∈ [77,127]`、`Cr ∈ [133,177]` 的经典肤色窗口，
边界各留 8 的软过渡带（防权重突变造成色块），再乘一个亮度门控
（`Y < 50` 完全不动——头发缝隙、鼻孔、瞳孔的色度不可信）。

**色度与亮度基本无关**，所以阴影里的皮肤同样能识别。旧版是经典 RGB 硬判据
（`r > 95 && g > 40 && …`），它把阴影侧皮肤、偏暗肤色**整片排除**——而那些
区域恰恰最需要匀肤，结果侧脸与逆光照几乎看不出效果。窗口要刻意取宽：偏红、
偏黄、偏冷的肤色都得覆盖，漏掉就等于「没效果」。眼/眉/唇/发的色度明显偏离
该窗口，权重仍为 0。

#### 清晰度：只锐化亮度，用 S 曲线而非线性对比

三条硬约束（早期观感「过锐、发假、暗部发脏」的根因）：

1. **只锐化亮度通道**。对 R/G/B 分别做 USM 会让互补色在边缘分离，产生
   彩色描边（紫边/绿边），在发丝与眼镜框上尤其明显。改为算出亮度增量后
   三通道等量施加；
2. **S 曲线代替线性对比**。`128 + (v-128) × k` 会把暗部压死、高光顶死；
   S 曲线只拉开中间调，两端自然收敛——这才是「通透」而非「对比大」；
3. **用鲜艳度（vibrance）代替饱和度**。线性饱和对所有像素等比放大，肤色
   本就偏饱和，一放大立刻发橙，所以系数只能给到 0.05 级别 ——「调了跟没调
   一样」。鲜艳度按 `amount × (1-sat)²` 加权：增益让给灰淡区域（衣服、
   背景过渡），对已饱和的肤色自动收手，因此可以给到 **0.30**（6 倍）而依然
   安全。衰减用**平方**而非线性——线性下 sat=0.45 的肤色仍拿到 55% 增益，
   还是会橙；平方后只剩 30%，而近中性区几乎不受影响（0.92），两者增益差
   被明显拉开。

#### 成片清晰度的真正瓶颈在缩放链路，不在锐化参数

用户反馈「清晰度还是不够」时，第一反应往往是去加大 USM 强度——**这是错的**，
信息已经在缩放时丢了，再锐化只会放大噪点。实际挖出两处硬伤：

1. **`img.copyResize` 的默认插值是 `Interpolation.nearest`（最近邻）**。
   工作图限边缩放与 ML 输入编码都在裸用默认值，4000px 的手机原图缩到
   2400 等于直接丢弃 40% 的像素且不做任何平均，细节在**第一步**就没了。
   凡调用 `copyResize` 必须显式指定插值。
2. **成片是从 2000+px 一步 cubic 缩到 295×413**。cubic 是点采样插值，只看
   目标像素周围 4×4 个源像素；跨度 7 个像素取 1 个时，中间的信息根本没参与
   计算——这是无抗混叠抽样，发丝、布纹会丢失甚至出摩尔纹。

修法是 `ImagePipeline.downscaleStepwise`：只要还大于目标 2 倍就用**区域平均
逐步减半**（mipmap 思路，每个源像素都对结果有贡献），最后一步才用 cubic
对齐尺寸。缩放后再无条件补一道 `PhotoEffects.resizeSharpen`——区域平均本质
是低通，必然软化边缘，行业惯例是缩放后补一道轻 USM 把锐度拉回来。

注意 `resizeSharpen` 与清晰度滑杆是两回事：滑杆是主观风格，这一步是**还原
缩放前就有的锐度**，所以不给开关，固定 0.45。

> 曾经这里按「高精修 / 普通版」分 0.55 / 0.35 两档。那个开关是**名不副实**的
> 历史遗留：`MattingEngine` 枚举在整条流水线里唯一的作用就是决定这个系数，
> 两档的抠图都无条件走 MODNet（`segmentRgba` 里没有任何分支），ML Kit 只用于
> 人脸检测。切一次档却要重跑整条流水线。v0.7.1 已连同枚举、`sharpen` 字段、
> UI 开关与两条 l10n 文案一并删除。

瘦脸幅度刻意压在 4.5% 以内：证件照审核关注「与本人一致」，明显改脸型有
合规风险，这里只做视觉上收紧下颌线的程度。

底层算子是自研的**三趟分离式盒子模糊**（≈高斯，复杂度 O(w·h) 与半径无关），
直接跑在 RGBA 原始缓冲区上，比逐像素 `getPixel/setPixel` 快一个量级——
这是把效果重算压进「一次扫描动效」时长内的前提。

## 3. 关键类说明

### PhotoSpec（lib/models/photo_spec.dart）
证件照规格模型，JSON 可反序列化。字段：`id / name / pixelWidth /
pixelHeight / minFileKb / maxFileKb / minWidth / maxWidth / minHeight /
maxHeight / minRatio / maxRatio / background(SpecBackground) / requirements`。
`SpecBackground` 为 `name + RGB`。文件内还定义五色常量
（`idPhotoBlue/White/Red/Gray/DarkBlue`，`idPhotoBackgrounds` 即 UI 顺序）与
内置学生报名照 `studentPhotoSpec`（id: `student_edu_id`，480×640）。

### ImagePipeline（lib/services/image_pipeline.dart）
处理流水线核心。`run()` 返回 `PipelineResult`：最终 jpg 字节、原图预览字节、
换底后工作图（`compositedRgba` + 宽高，供交互裁剪与效果重算复用）、
自动构图框与人脸框。步骤枚举 `PipelineStep` 用于进度展示；
`PipelineException` 携带语义化 `code`。全流程无网络请求。

静态工具（纯函数、可单测）：`cropRectFor` 构图、`paddedCrop` 底色补边裁剪、
`resizeToSpecUniform` 等比缩放到规格、`encodeToKbRange` 二分压缩。
顶层 isolate 入口与掩码算法（`refineAlpha` / `keepMainSubject` /
`decontaminate` / `detectHeadTop` / `deliverWorker` / `previewWorker`）
见 §2.1–2.3。

### ModnetSegmenter（lib/services/modnet_segmenter.dart）
MODNet 发丝级抠图（`hivision_modnet`，HivisionIDPhotos 自训练，MIT）。
常驻 worker isolate，`OrtEnv`/`OrtSession` 复用。模型固定 512×512 输入
（真机实证非 512 报 invalid dimensions），预处理/后处理都用双线性重采样
直接跑在缓冲区上。`segmentRgba()` 是流水线主路径，`warmUp()` 供启动页预热。

早期曾用 ML Kit Selfie Segmentation，但在部分机型原生崩溃杀进程，已整体
切换到 MODNet；`google_mlkit_selfie_segmentation` 依赖也已移除。

### PhotoEffects（lib/services/photo_effects.dart）
面部精修与画质清晰度两条效果通道，纯函数、可在 isolate 内调用，
两个强度都为 0 时短路返回原对象。算法说明见 §2.4。

### ComplianceService（lib/services/compliance_service.dart）
对**最终 jpg 字节**做合规检测。产出 `ComplianceReport`（`List<CheckItem>`），
`hardAllPass` 表示硬性项全过。`CheckItem.id` 是稳定语义标识
（format/fileSize/…/eyesOpen），`fixId` 是修复建议标识，`soft` 标记软指标；
`detail` 为实测值（如「486KB」）。底色检测（id 沿用 `blueBg` 历史名，但
**逻辑已泛化**）：四角 8% 区域均值（短边比例取样防越界采到黑像素）→ RGB
转 HSV → 与 `spec.background` 目标色按容差比对，分两分支——

- **低饱和目标**（白/灰，S ≤ 0.25）：实测 S ≤ 0.35 且明度差 ≤ 0.25；
- **彩色目标**（蓝/红/深蓝）：色相环形差 ≤ 20°、实测 S > 0.2 且明度差
  ≤ 0.3。

UI 文案经 `Tr` 按目标色名输出：`checkBgColor({bg})` / `fixBgMismatch({bg})`。

### SpecLibrary（lib/services/spec_library.dart）
内置规格库访问入口。`load()` 从 `assets/photo_specs.json` 解析并缓存；
`search(keyword)` 按名称过滤。纯端侧，无网络。

### AlbumService（lib/services/album_service.dart）
本地相册：成片双写一份到应用私有目录（`<documents>/album`），文件名
`{yyyyMMdd_HHmmss}_{baseName}.jpg`，`baseName` 通常为教育 ID 或原图名；
`list()` 按修改时间倒序，`delete(path)` 按路径删除。系统相册写入由
`gal` 完成（在 result_page 中调用）。

### UpdateService（lib/services/update_service.dart）
GitHub Release 自升级。`checkUpdate()` 请求
`api.github.com/repos/chunguangwei/photoid/releases/latest`（15s 超时），
`parseRelease()` 解析出版本号（去 v 前缀）、APK 下载地址、release notes、
是否强制更新；`isNewer()` 做分段数字 semver 比较。**仅 Android**：
iOS 直接返回 null（走 App Store）。静默失败——任何异常返回 null 不打扰用户。

双触发：
- **自动**：`main.dart` 启动 3 秒后 `Timer` 静默检查一次，有新版本弹
  `showUpdateDialog`；
- **手动**：`settings_page.dart`「检查更新」入口（仅 Android 显示），
  无更新时 snackbar 提示「已是最新」，有更新弹升级框。

下载与安装在 `update_dialog.dart`：「立即更新」后流式下载 APK 到临时目录，
经 `open_filex`（FileProvider）触发系统安装。

### HomePage（lib/pages/home_page.dart）
主页骨架为底部 `NavigationBar` 双 Tab（首页 / 我的，`IndexedStack` 保持
两页状态）。**首页 Tab** 自上而下：品牌渐变头（appTitle + privacySlogan）
→ 2×2 主功能大卡（拍证件照→滚动定位到热门规格区，规格即拍摄入口；换底色
→以 `studentPhotoSpec` 进相册选图复用流水线；改 KB；我的相册）→ 次级小工具
（自定义规格）→ 黄色隐私横幅（锁图标 + 隐私文案）→ 搜索框 → 近期热门
（🔥 图标；`_hotIdKeys` 锚定 student / one_inch / two_inch / cet_english /
gaokao，**按锚点顺序各取一条**，学生照置顶，避免被寸照变体挤占；无匹配则取
列表前 5）→ 「全部规格(N)」ExpansionTile 默认折叠。非搜索态下学生报名照
（`studentPhotoSpec`）置顶进入规格流。搜索时整列表按名称过滤替换热门区。
相册选图统一 `imageQuality: 99`（Android quality=100 按字节拷贝原文件，
HEIC 会漏入；99 强制转 JPG 且质量损失可忽略）。

### SettingsPage（lib/pages/settings_page.dart）
「我的」Tab：我的相册入口 → 检查更新（`Platform.isAndroid` 才显示）→
隐私说明 → 关于区（版本号取自 `PackageInfo` / 许可 / 联系邮箱）。

### CameraPage（lib/pages/camera_page.dart）
拍摄页：实时预览 + 半透明遮罩 3:4 取景框 + **人像轮廓虚线参考框**
（CustomPainter：头部圆 + 颈肩剪影虚线，头部约占框高 40%、肩部展开至框宽
62%，替代旧版椭圆参考线）；前后置切换按钮（`_cameras.length > 1` 才显示，
默认后置，面向家长替孩子拍摄场景），切换时释放旧控制器按新镜头方向重建。

### SpecDetailPage（lib/pages/spec_detail_page.dart）
规格详情：三栏参数卡（像素尺寸 / DPI 300 / 文件大小区间）→ 五色底色选择
`ChoiceChip` 区（`idPhotoBackgrounds` 顺序：蓝/白/红/灰/深蓝；规格默认色带
「· 推荐」标记）→ 要求清单（经 `Tr.requirements` 翻译）。选中底色替换
`_spec.background` 后贯穿拍摄与上传；底部「上传照片」/「立即拍摄」双按钮。

### EditPage（lib/pages/edit_page.dart）
处理页，也是交互最密集的一页：

- 按 `PipelineStep` 展示流水线进度（照片卡 + 扫描光带 + 体感进度条）；
- 底色 chips 切换 → `recolorWorker` 秒切（**不重跑流水线**）；
- **美颜 / 清晰度双滑杆**，两者**每次进页面都从 0 开始且不持久化**——用户
  看到的第一版成片必须是「原样处理」的结果。曾经这两个值会存进
  SharedPreferences 并在下次进入时恢复，导致换了一张照片仍在套用上次的
  强度，而界面没有任何提示；
- 滑杆拖动只更新数字，松手后 250ms 防抖再进 isolate
  重算预览，重算期间在预览上叠扫描动效表明「正在处理」；请求带序号，
  只认最新一次结果，快速拖动不会出现旧结果覆盖新结果；
- 「保存」走 `compute(deliverWorker)` 异步出片，期间按钮转圈并禁用，
  防重复点击。

`CropEditor` 的 `key` 绑定 `_resultVersion`（**只在重跑流水线时自增**），
效果重算不动它——底图字节变化由 `CropEditor.didUpdateWidget` 处理，
只重新解码、保留用户已调好的缩放与位移。早期靠外部换 `key` 强制重建来刷新
底图，副作用是每动一次滑杆就把用户裁好的框打回自动构图。

### CropEditor（lib/pages/crop_editor.dart）
图版截取式裁剪（同微信头像交互）：视口内固定规格比例的取图窗，用户双指
等比缩放 + 单指拖动照片。状态只有 `_scale` 与 `_offset`，导出裁剪框的高由
宽 ÷ `aspect` 推导——结构上不可能产生非等比拉伸。

### SplashPage（lib/pages/splash_page.dart）
启动页：全 Dart 矢量绘制的品牌吉祥物（`CustomPainter`），双眼同步眨动
（2.2–5.2s 随机间隔、偶发连眨）、呼吸浮动、光晕流动、影子随浮动联动。
6 秒倒计时可跳过，底部预留广告位槽。同时在这段空闲期调用
`ModnetSegmenter.warmUp()` 预热抠图模型。

原先是一张 1.59MB 的 `splash_loading.png`：撑包体、高分屏发糊、且静态图
做不了眨眼。改矢量后包体直接减 1.59MB，任意分辨率锐利。

## 4. i18n 架构

```
lib/l10n/app_zh.arb / app_en.arb        # 翻译源（唯一真源，唯一可编辑）
        │  flutter gen-l10n（l10n.yaml 配置，构建时自动生成）
        ▼
AppLocalizations（app_localizations*.dart，生成物勿手改）
        │  页面层直接取用；服务层/模型层不依赖它
        ▼
Tr（lib/l10n/l10n_helpers.dart）
        服务层与规格模型输出的语义标识（PipelineStep、PipelineException.code、
        CheckItem.id/fixId、底色名、规格 requirements）→ l10n 键的映射层
```

规则：
- 新增 UI 文案：只改 ARB 文件（中英两份），运行 `flutter gen-l10n` 或热重载生成。
- 服务层/模型层**不 import flutter material**；输出语义标识，由 pages 层
  `Tr.of(context).checkLabel(...)` 翻译。语义标识改动会破坏翻译映射，视为接口变更。
- 规格名/底色名等模型层中文数据，在 `Tr` 中按需映射（如 `student_edu_id`）。

## 5. 添加新规格

规格存放在 `assets/photo_specs.json`（数组，33+ 条），模型为 `PhotoSpec`：

```json
{
  "id": "one_inch",            // 唯一标识（snake_case）
  "name": "一寸",               // 展示名
  "pixelWidth": 295,           // 成片宽（px）
  "pixelHeight": 413,          // 成片高（px）
  "minFileKb": 0,              // 文件大小下限（KB）
  "maxFileKb": 10240,          // 文件大小上限（KB）
  "minWidth": 295, "maxWidth": 295,    // 允许像素宽范围
  "minHeight": 413, "maxHeight": 413,  // 允许像素高范围
  "minRatio": 1.35, "maxRatio": 1.45,  // 高/宽比例范围
  "background": { "name": "蓝底", "r": 67, "g": 142, "b": 219 },
  "requirements": ["冲印尺寸 25×35mm", "最佳尺寸 295×413 像素"]
}
```

新增条目追加到数组即可，`SpecLibrary.load()` 启动时自动加载。若规格需要
双语名称，在 `Tr` 中按 `spec.id` 增加映射。

## 6. 构建与运行

```bash
flutter pub get
flutter run                     # 调试运行（连接设备/模拟器）

# Android 发布
flutter build apk --release     # build/app/outputs/flutter-apk/app-release.apk

# iOS（需 macOS + Xcode；--no-codesign 仅构建不签名）
flutter build ios --no-codesign
```

iOS 已加入隐私清单 `ios/Runner/PrivacyInfo.xcprivacy`，声明四类受访问
API：UserDefaults（CA92.1）、FileTimestamp（C617.1）、DiskSpace（E174.1）、
SystemBootTime（35F9.1），满足 App Store 隐私清单要求。

### 应用图标

设计源是 `logo/*.svg`（矢量，改这里），PNG 是渲染产物：

| 文件 | 用途 |
| --- | --- |
| `logo/logo.svg` → `logo/icon.png` | iOS / Android 旧版全幅图标 |
| `logo/logo_foreground.svg` → `logo/icon_foreground.png` | Android 自适应图标前景（**透明底**） |
| `logo/logo_background.svg` → `logo/icon_background.png` | Android 自适应图标背景（渐变） |

改完 SVG 后重新光栅化再生成图标：

```bash
node logo/render.mjs .          # SVG → PNG（需 npm i sharp）
dart run flutter_launcher_icons # PNG → 各平台图标
```

两点约束，改动时勿回退：

- 图标 PNG **不要**加进 `flutter: assets:`。它们只是构建期输入，应用代码
  从不 `load`，列进去会白白多打 1.4MB 进包体。
- 自适应图标前景必须是透明底且标记落在安全区内。曾经前景直接复用了
  全幅图（背景烤在里面），结果被系统圆形遮罩切掉取景框四角。

## 7. 测试

```bash
flutter test            # 全部单测
dart analyze            # 静态检查
```

> **注意**：若仓库路径含中文（如 `个人文件/开发/`），`flutter analyze`
> 会因 analysis server 的 LSP JSON 被 URL 编码后截断而崩溃
> （`FormatException: Unterminated string`）。这是工具链问题，与代码无关，
> 改用 `dart analyze` 即可，结果等价。

现有测试（`test/`）：

| 文件 | 覆盖 |
| --- | --- |
| `splash_golden_test` | 启动页吉祥物的**视觉基线**。这页全靠 `CustomPainter` 手绘，改坐标不会有任何编译或断言错误，只会「画歪」，只有 golden 拦得住。更新基线用 `flutter test --update-goldens`，提交前务必**肉眼看过**产物 |
| `matting_framing_test` | **ROI 粗裁契约**（不越界/收益不足不裁/**横向留够肩宽**）、**头高高估时不缩小人物**、按框裁像素、掩码精修不腐蚀轮廓、发丝带存活、**中高置信区判实心**（防人物溶解）、**飞地清除/孔洞填实**、真实头顶探测、构图越界补边、消白边不改 alpha 且**单向变暗**（防白色光晕） |
| `isolate_delivery_test` | **真实 `compute`** 跑通交付/预览/换底，验证跨 isolate 传参契约与补边底色 |
| `effects_test` | 美颜/清晰度强度契约：0 短路、不外溢人脸外、保五官、不溢出回绕、**中频色斑被压制**、**强度单调可感知**、**阴影肤色参与**、**暖肤提亮生效**、**无彩色描边**、**暗部高光不死**、**鲜艳度不使肤色发橙** |
| `image_pipeline_test` | `encodeToKbRange` 区间命中与 EOI 填充 |
| `crop_editor_test` | 裁剪编辑器不抛异常 |
| `splash_detail_test` | 启动页倒计时/跳过、规格详情页渲染 |
| `photo_spec_test` | 规格模型不变量与 JSON 反序列化 |
| `album_service_test` / `custom_spec_store_test` | 本地存储 CRUD |
| `update_service_test` / `update_dialog_test` | 升级检查与对话框 |

新逻辑优先写在 services 层并配套单测。涉及 isolate 的改动务必补一条
真实 `compute` 用例——序列化问题静态分析发现不了。

**画质类改动无法靠单测保证**：抠图边缘、构图松紧、磨皮观感必须真机回归，
建议固定一组样张（顶天立地、深色头发、浅色背景、侧脸、戴眼镜）。

## 8. 发布流程（GitHub Release 自升级）

### 8.1 release 正式签名（Android）

release 构建的签名由 `android/key.properties` 控制（`build.gradle.kts`）：

```properties
storeFile=/Users/<you>/.android/photoid-release.keystore
storePassword=******
keyAlias=photoid
keyPassword=******
```

- `key.properties` **本地存放、gitignored**，四个字段：`storeFile` /
  `storePassword` / `keyAlias` / `keyPassword`。
- 文件存在 → release 用正式 keystore（`~/.android/photoid-release.keystore`）
  签名；**不存在 → 回退 debug 签名（仅限本地调试，不可分发）**。
- ⚠️ **keystore 与密码必须备份**（keystore 文件 + key.properties 各存一份
  异地）。应用内自升级是**同签名覆盖安装**——签名断裂（keystore 丢失、
  误用 debug 包发布）= 老用户无法升级，只能卸载重装，相册数据一并丢失。
- 换签名（新 keystore）对存量用户等效于签名断裂：**需用户卸载重装一次**。

### 8.2 发布步骤

Android 端应用内自升级完全依赖 GitHub Release。⚠️ **铁律：`pubspec.yaml`
的 `version`（应用内显示与比较基准）必须与 Release tag 严格对齐**——tag 是
远程版本唯一来源，pubspec 是本地版本唯一来源，两者不一致会导致
`isNewer()` 比较失准，已发版本被反复提示升级（v0.1.0 vs v0.2.0 教训：
发布新版本前 pubspec 忘了同步抬版本，旧包用户收到的「最新版」比较基准错乱，
形成升级循环）。发布步骤：

1. **先改 `pubspec.yaml` 版本号**：`version: X.Y.Z+N`（如 `0.2.0+2`）——
   应用内显示的当前版本取自这里（`PackageInfo`），升级比较是
   `Release tag` 对该版本做分段数字比较，远程必须**严格大于**它。
   发布 v0.2.0 前 pubspec 必须先写到 `0.2.0+2`，与 tag 对齐。
2. 构建 APK：`flutter build apk --release`（构建前确认 `key.properties`
   就位，见 8.1——误出 debug 签名包会导致老用户无法覆盖升级）。
3. 提交并打 tag：`git tag vX.Y.Z`（如 `v0.2.0`）并推送——**远程版本号取自
   tag 名**（自动去掉 `v` 前缀），故 tag 与 pubspec 版本保持一致。
4. 在 GitHub 上基于该 tag 创建 Release：
   - Release 正文（body）即应用内展示的 release notes；
   - **必须上传 APK 作为 Release asset**（文件名含 `apk`，大小写不敏感），
     `UpdateService` 取第一个匹配的 asset 作为下载地址；无 APK asset 时
     升级检查返回 null；
   - `isForceUpdate` 目前固定为 `false`（预留字段，未实现强制更新逻辑）。
5. iOS 不发 APK：`UpdateService` 在 iOS 直接返回 null，走 App Store 流程。

版本比较规则：按 `.` 分段取各段前导数字比较，远程版本必须严格大于当前
版本才提示更新（`1.2` == `1.2.0`，`3-beta` 视为 `3`）。

---

## 相关文档

- [README](../README.md) — 项目介绍与功能列表
- [product.md](product.md) — 当前产品文档（定位/功能/规格体系/合规检测）
- [CONTRIBUTING](../CONTRIBUTING.md) — 贡献指南
- [LICENSE](../LICENSE) — 非商业许可证（个人免费，商用需书面授权）
