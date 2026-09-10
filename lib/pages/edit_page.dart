
import 'dart:io';

import 'package:flutter/foundation.dart' show compute;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/photo_spec.dart';
import '../services/image_pipeline.dart';
import 'crop_editor.dart';
import 'result_page.dart';

/// 处理页：执行流水线（抠图→换底→裁剪→压缩），展示效果预览。
class EditPage extends StatefulWidget {
  const EditPage(
      {super.key,
      required this.sourcePath,
      required this.spec,
      this.flipHorizontal = false});

  final String sourcePath;
  final PhotoSpec spec;

  /// 前置摄像头拍摄时为 true（补偿预览镜像）
  final bool flipHorizontal;

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late PhotoSpec _spec;
  PipelineStep _step = PipelineStep.preparing;
  PipelineResult? _result;
  String? _error;
  bool _showOriginal = false;
  bool _regenerating = false;

  static const _hdPrefKey = 'hd_mode_enabled_v2';
  static const _beautyPrefKey = 'beauty_intensity';

  /// 美颜强度 0–1（滑杆，持久化）
  double _beauty = 0.5;

  /// 预览用合成图缓存：应用美颜后的 compositedJpg；版本号驱动编辑器重建
  Uint8List? _previewJpg;
  int _previewVersion = 0;

  /// 效果重算中（滑杆松手后 isolate 磨皮）：预览叠扫描动效 + 挡连拖
  bool _effectsBusy = false;

  /// 高精修版（MODNet 发丝级抠图）开关；默认 false=普通版（ML Kit 快速），
  /// 用户主动选高精才走慢速精细模型。持久化到 SharedPreferences。
  bool _hd = false;

  /// 交互裁剪编辑器状态与用户调整后的裁剪框（null=未调整，用自动构图）
  final GlobalKey<CropEditorState> _editorKey = GlobalKey<CropEditorState>();
  Rect? _currentCrop;

  @override
  void initState() {
    super.initState();
    _spec = widget.spec;
    _loadHdPref().then((_) => _run());
  }

  Future<void> _loadHdPref() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool(_hdPrefKey);
    final b = prefs.getInt(_beautyPrefKey);
    if (mounted) {
      setState(() {
        if (v != null) _hd = v;
        if (b != null) _beauty = (b / 100).clamp(0.0, 1.0);
      });
    }
  }

  /// 美颜变化（滑杆松手）：重算预览合成图（编辑器回自动构图，与成片同参数）。
  /// 磨皮是高斯模糊重活，放后台 isolate 防 UI 卡顿。
  Future<void> _refreshEffects({bool persistBeauty = false}) async {
    if (persistBeauty) {
      SharedPreferences.getInstance()
          .then((p) => p.setInt(_beautyPrefKey, (_beauty * 100).round()));
    }
    final r = _result;
    if (r == null || _effectsBusy) return; // 重算中忽略新触发
    final beauty = _beauty; // 入口快照：滑杆连发时只认最新值
    setState(() => _effectsBusy = true);
    Uint8List jpg;
    try {
      if (beauty > 0) {
        jpg = await compute(
            _beautifyWorker, _BeautyTask(r.compositedJpg, r.faceRect, beauty));
      } else {
        jpg = r.compositedJpg;
      }
    } finally {
      if (mounted) setState(() => _effectsBusy = false);
    }
    if (!mounted || _result != r || _beauty != beauty) return; // 新流水线/新强度优先
    setState(() {
      _previewJpg = jpg;
      _previewVersion++;
      _currentCrop = null; // 预览重算后回自动构图，避免用户框与效果错位
    });
  }

  /// 换底色：更新规格后重跑流水线，预览与 KB 随之刷新。
  Future<void> _switchBackground(SpecBackground bg) async {
    if (bg.name == _spec.background.name) return;
    setState(() {
      _spec = _spec.copyWith(background: bg);
      _regenerating = true;
    });
    await _run();
    if (mounted) setState(() => _regenerating = false);
  }

  /// 高精修/普通版切换：按引擎重跑流水线
  void _switchHd(bool hd) {
    if (hd == _hd || _result == null) return;
    setState(() => _hd = hd);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_hdPrefKey, hd));
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _error = null;
      _result = null;
      _step = PipelineStep.preparing;
      _currentCrop = null;
    });
    try {
      final result = await ImagePipeline(
        onProgress: (s) {
          if (!mounted) return;
          setState(() {
            _step = s;
            _regenerating = false;
          });
        },
      ).run(widget.sourcePath, _spec,
          flipHorizontal: widget.flipHorizontal,
          engine: _hd ? MattingEngine.modnet : MattingEngine.mlkit);
      if (!mounted) return;
      setState(() {
        _result = result;
        _previewJpg = null;
      });
      _refreshEffects();
    } on PipelineException catch (e) {
      if (mounted) setState(() => _error = Tr.of(context).pipelineError(e));
    } on PlatformException {
      // ML Kit 双通路均失败（如华为无 GMS 设备）：给可读提示而非堆栈
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).errMlkit);
      }
    } catch (e) {
      if (mounted) setState(() => _error = AppLocalizations.of(context).processFailed('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).editTitle),
        actions: [
          TextButton(
            onPressed: result == null ? null : _goResult,
            child: Text(AppLocalizations.of(context).saveAction,
                style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _error != null
            ? _buildError()
            : result == null
                ? _buildProgress()
                : _buildPreview(result),
      ),
    );
  }

  /// 生成最终交付 jpg（按当前裁剪框与精修开关）并进入检测/保存页
  void _goResult() {
    final r = _result!;
    final jpg = _finalizeCrop(r, _currentCrop ?? r.autoCrop);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultPage(jpgBytes: jpg, spec: _spec),
    ));
  }

  /// 按用户调整的裁剪框（图像坐标系）生成最终交付 jpg：
  /// 框出界则平移回界内，框比图大则等比缩到能放下，再缩放+二分压缩。
  Uint8List _finalizeCrop(PipelineResult r, Rect crop) {
    final cw = r.composited.width;
    final ch = r.composited.height;
    // 高由宽 ÷ 比例推导（比例锁定）；钳制后回推，杜绝非等比
    var w = crop.width.round().clamp(1, cw);
    var h = (w / _spec.aspect).round().clamp(1, ch);
    w = (h * _spec.aspect).round().clamp(1, cw);
    h = (w / _spec.aspect).round().clamp(1, ch);
    final x = crop.left.round().clamp(0, cw - w);
    final y = crop.top.round().clamp(0, ch - h);
    final c = img.copyCrop(r.composited, x: x, y: y, width: w, height: h);
    var out = ImagePipeline.resizeToSpecUniform(
        c,
        _spec.pixelWidth,
        _spec.pixelHeight,
        img.ColorRgb8(
            _spec.background.r, _spec.background.g, _spec.background.b));
    // 人脸框：composited 坐标 → 裁剪后输出坐标
    final sx = _spec.pixelWidth / w;
    final sy = _spec.pixelHeight / h;
    final face = Rect.fromLTRB(
        (r.faceRect.left - x) * sx,
        (r.faceRect.top - y) * sy,
        (r.faceRect.right - x) * sx,
        (r.faceRect.bottom - y) * sy);
    if (_beauty > 0) {
      out = ImagePipeline.beautify(out, face, _beauty);
    }
    return ImagePipeline.encodeToKbRange(out, _spec.minFileKb, _spec.maxFileKb);
  }

  /// 处理中页（照片卡 + 智能制作文案 + 进度 + 取消）
  Widget _buildProgress() {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 照片卡 + 科技感扫描线（上下来回，体现 AI 修整过程）
            Card(
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: 160,
                height: 213,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(widget.sourcePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox.expand(),
                    ),
                    const _ScanLineEffect(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(l.processingTitle,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(l.processingDesc,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(width: 180, child: _SmoothProgress(step: _step)),
            const SizedBox(height: 12),
            Text(_regenerating
                ? l.editRegenerating
                : '${l.processingBusy} · ${Tr.of(context).step(_step)}'),
            const SizedBox(height: 8),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l.retakeOrPick,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context).retakeOrPick),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _run,
                child: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ),
        ),
      );

  Widget _buildPreview(PipelineResult result) {
    final l = AppLocalizations.of(context);
    final kb = result.jpgBytes.lengthInBytes / 1024;
    return Column(
      children: [
        // 版本切换：高精修版（MODNet 发丝级）/ 原图普通版（ML Kit 快速）
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(l.editHd)),
              ButtonSegment(value: false, label: Text(l.editNormal)),
            ],
            selected: {_hd},
            onSelectionChanged: (s) => _switchHd(s.first),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: _showOriginal
                  ? Image.memory(result.originalBytes, fit: BoxFit.contain)
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        CropEditor(
                          key: ValueKey(_previewVersion),
                          imageBytes: _previewJpg ?? result.compositedJpg,
                          imageWidth: result.composited.width,
                          imageHeight: result.composited.height,
                          autoCrop: result.autoCrop,
                          aspect: _spec.aspect,
                          onChanged: (r) => _currentCrop = r,
                        ),
                        // 效果重算中：扫描动效（与处理中页同一套）
                        if (_effectsBusy)
                          const IgnorePointer(
                            child: _ScanLineEffect(),
                          ),
                      ],
                    ),
            ),
          ),
        ),
        if (!_showOriginal)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.crop_free,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(l.editZoomHint,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _editorKey.currentState?.reset(),
                  child: Text(l.editCropReset,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary)),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: Text(AppLocalizations.of(context).chipPreview),
                selected: !_showOriginal,
                onSelected: (_) => setState(() => _showOriginal = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(AppLocalizations.of(context).chipOriginal),
                selected: _showOriginal,
                onSelected: (_) => setState(() => _showOriginal = true),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Text(AppLocalizations.of(context).editSwitchBg,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final bg in idPhotoBackgrounds)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: _bgSwatch(bg),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _effectsBar(),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '${_spec.pixelWidth}×${_spec.pixelHeight}px · '
            '${_bgLabel(_spec.background)} · '
            '${kb.toStringAsFixed(0)}KB',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  /// 美颜强度滑杆（拖拽实时看数值，松手重算预览；与成片同参数）
  Widget _effectsBar() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Text(l.beautyLabel, style: Theme.of(context).textTheme.bodySmall),
        Expanded(
          child: Slider(
            value: _beauty,
            divisions: 20,
            onChanged: (v) => setState(() => _beauty = v),
            onChangeEnd: (_) => _refreshEffects(persistBeauty: true),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text('${(_beauty * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ]),
    );
  }

  /// 色块选底（对标行业交互：圆角色块 + 选中描边✓ + 名称）
  Widget _bgSwatch(SpecBackground bg) {
    final selected = bg.name == _spec.background.name;
    return GestureDetector(
      onTap: (_result == null && _error == null)
          ? null
          : () => _switchBackground(bg),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color.fromARGB(255, bg.r, bg.g, bg.b),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black26,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: selected
                ? Icon(Icons.check,
                    size: 20,
                    color: bg.r > 200 && bg.g > 200
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white)
                : null,
          ),
          const SizedBox(height: 4),
          Text(_bgLabel(bg),
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  /// 底色名 → l10n（backgroundL10nKeys 映射，无键时原样展示）。
  String _bgLabel(SpecBackground bg) {
    final l = AppLocalizations.of(context);
    switch (backgroundL10nKeys[bg.name]) {
      case 'bgBlue':
        return l.bgBlue;
      case 'bgWhite':
        return l.bgWhite;
      case 'bgRed':
        return l.bgRed;
      case 'bgGray':
        return l.bgGray;
      case 'bgDarkBlue':
        return l.bgDarkBlue;
      default:
        return bg.name;
    }
  }
}

/// 体感进度条：随流水线步骤向目标值缓动前进（6s easeOut），
/// 避免处理中界面「卡死」感；始终 ≤0.95，完成由页面切换表达。
class _SmoothProgress extends StatefulWidget {
  const _SmoothProgress({required this.step});

  final PipelineStep step;

  @override
  State<_SmoothProgress> createState() => _SmoothProgressState();
}

class _SmoothProgressState extends State<_SmoothProgress>
    with SingleTickerProviderStateMixin {
  static const _targets = {
    PipelineStep.preparing: 0.10,
    PipelineStep.reading: 0.22,
    PipelineStep.segmenting: 0.55,
    PipelineStep.compositing: 0.72,
    PipelineStep.framing: 0.85,
    PipelineStep.compressing: 0.95,
  };

  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(seconds: 6));
  late Animation<double> _animation =
      AlwaysStoppedAnimation(_targets[widget.step] ?? 0.1);
  double _current = 0;

  @override
  void initState() {
    super.initState();
    _animateTo(_targets[widget.step] ?? 0.1);
  }

  @override
  void didUpdateWidget(_SmoothProgress old) {
    super.didUpdateWidget(old);
    if (old.step != widget.step) {
      _animateTo(_targets[widget.step] ?? 0.95);
    }
  }

  void _animateTo(double target) {
    _animation = Tween<double>(begin: _current, end: target)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        _current = _animation.value;
        return LinearProgressIndicator(value: _current);
      },
    );
  }
}

/// 后台 isolate 美颜任务参数
class _BeautyTask {
  const _BeautyTask(this.jpg, this.face, this.intensity);

  final Uint8List jpg;
  final Rect face;
  final double intensity;
}

/// isolate 入口：解码 → 美颜 → 重编码
Uint8List _beautifyWorker(_BeautyTask t) {
  final im = img.decodeJpg(t.jpg);
  if (im == null) return t.jpg;
  return img.encodeJpg(ImagePipeline.beautify(im, t.face, t.intensity),
      quality: 90);
}

/// 科技感扫描动效：渐变光带自上而下再从下到上循环，
/// 叠加微呼吸亮度，体现「AI 正在修整」。
class _ScanLineEffect extends StatefulWidget {
  const _ScanLineEffect();

  @override
  State<_ScanLineEffect> createState() => _ScanLineEffectState();
}

class _ScanLineEffectState extends State<_ScanLineEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final y = Curves.easeInOut.transform(_c.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            // 微呼吸亮度
            Container(
                color: Colors.white
                    .withValues(alpha: 0.06 + 0.05 * y)),
            // 扫描光带
            Align(
              alignment: Alignment(0, -1 + 2 * y),
              child: Container(
                height: 26,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0),
                      color.withValues(alpha: 0.55),
                      Colors.white.withValues(alpha: 0.85),
                      color.withValues(alpha: 0.55),
                      color.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
