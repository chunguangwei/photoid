import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/photo_spec.dart';
import '../services/image_pipeline.dart';
import 'crop_editor.dart';
import 'result_page.dart';
import 'scan_effect.dart';

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
  static const _beautyPrefKey = 'beauty_intensity_v3';
  static const _clarityPrefKey = 'clarity_intensity_v3';

  /// 面部精修强度 0–1（磨皮/去皱/匀肤/轻度瘦脸）。默认 0 = 不开启。
  double _beauty = 0;

  /// 画质清晰度强度 0–1（锐化/局部对比/通透度）。默认 0 = 不开启。
  double _clarity = 0;

  /// 预览用合成图缓存（效果重算产物）
  Uint8List? _previewJpg;

  /// 流水线结果版本号：**只在重跑流水线时自增**，用于重建裁剪编辑器。
  /// 效果重算不动它——底图字节变了由 CropEditor.didUpdateWidget 处理，
  /// 用户已调好的取景框得以保留。
  int _resultVersion = 0;

  /// 效果重算：只认最新一次请求（序号比对），避免快速拖动时旧结果覆盖新结果
  int _effectsSeq = 0;
  bool _effectsBusy = false;
  Timer? _effectsDebounce;

  /// 导出中（生成成片跑在 isolate，期间禁用保存按钮防重复点击）
  bool _exporting = false;

  /// 高精修版（MODNet 发丝级抠图）开关；持久化到 SharedPreferences。
  bool _hd = false;

  final GlobalKey<CropEditorState> _editorKey = GlobalKey<CropEditorState>();
  Rect? _currentCrop;

  @override
  void initState() {
    super.initState();
    _spec = widget.spec;
    _loadPrefs().then((_) => _run());
  }

  @override
  void dispose() {
    _effectsDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final hd = prefs.getBool(_hdPrefKey);
    final b = prefs.getInt(_beautyPrefKey);
    final c = prefs.getInt(_clarityPrefKey);
    if (!mounted) return;
    setState(() {
      if (hd != null) _hd = hd;
      if (b != null) _beauty = (b / 100).clamp(0.0, 1.0);
      if (c != null) _clarity = (c / 100).clamp(0.0, 1.0);
    });
  }

  /// 效果变化（滑杆松手）：250ms 防抖后在 isolate 重算预览。
  ///
  /// 防抖的意义：用户连续微调时只跑最后一次，避免堆积 isolate 任务；
  /// 序号比对再兜一层，保证界面最终一定收敛到当前滑杆值。
  void _scheduleEffects() {
    _effectsDebounce?.cancel();
    _effectsDebounce =
        Timer(const Duration(milliseconds: 250), _refreshEffects);
    SharedPreferences.getInstance().then((p) {
      p.setInt(_beautyPrefKey, (_beauty * 100).round());
      p.setInt(_clarityPrefKey, (_clarity * 100).round());
    });
  }

  Future<void> _refreshEffects() async {
    final r = _result;
    if (r == null) return;
    final seq = ++_effectsSeq;
    final beauty = _beauty, clarity = _clarity;

    // 两项都为 0：直接用原合成图，不必进 isolate（拖回 0 时立刻还原）
    if (beauty <= 0 && clarity <= 0) {
      if (!mounted || seq != _effectsSeq) return;
      setState(() {
        _effectsBusy = false;
        _previewJpg = null;
      });
      return;
    }

    setState(() => _effectsBusy = true);
    Uint8List jpg;
    try {
      jpg = await compute(
        previewWorker,
        PreviewRequest(
          rgba: r.compositedRgba,
          width: r.compositedWidth,
          height: r.compositedHeight,
          faceRect: r.faceRect,
          beauty: beauty,
          clarity: clarity,
        ),
      );
    } catch (e) {
      if (mounted && seq == _effectsSeq) setState(() => _effectsBusy = false);
      return;
    }
    // 期间用户又调了滑杆 / 换了底色 → 丢弃这次结果
    if (!mounted || seq != _effectsSeq || _result != r) return;
    setState(() {
      _effectsBusy = false;
      _previewJpg = jpg;
    });
  }

  /// 换底色：**不重跑流水线**。
  ///
  /// 抠图掩码、解混后的前景色、构图框都与底色无关，重跑等于白白再做一次
  /// MODNet 推理（最贵的一步）。这里只在 isolate 里做一次 alpha 混合，
  /// 几十毫秒返回；用户已调好的取景框与效果强度全部原样保留。
  Future<void> _switchBackground(SpecBackground bg) async {
    final r = _result;
    if (bg.name == _spec.background.name || r == null) return;
    setState(() {
      _spec = _spec.copyWith(background: bg);
      _effectsBusy = true;
    });
    try {
      final recolored = await compute(
        recolorWorker,
        RecolorRequest(
          foreground: r.foreground,
          alpha: r.alpha,
          width: r.compositedWidth,
          height: r.compositedHeight,
          bg: Uint8List.fromList([bg.r, bg.g, bg.b]),
        ),
      );
      // 期间用户又换了色 / 重跑了流水线 → 丢弃
      if (!mounted || _result != r) return;
      setState(() {
        _result = r.withBackground(recolored);
        _previewJpg = null;
      });
      // 底图换了，效果预览需按新底色重算（两项为 0 时会立即短路返回）
      await _refreshEffects();
    } catch (_) {
      // 换底失败（极端 OOM）：退回整条流水线重跑，保证界面不停在半路
      if (!mounted) return;
      setState(() => _regenerating = true);
      await _run();
      if (mounted) setState(() => _regenerating = false);
    } finally {
      if (mounted) setState(() => _effectsBusy = false);
    }
  }

  /// 高精修/普通版切换：按引擎重跑流水线
  void _switchHd(bool hd) {
    if (hd == _hd || _result == null) return;
    setState(() => _hd = hd);
    SharedPreferences.getInstance().then((p) => p.setBool(_hdPrefKey, hd));
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _error = null;
      _result = null;
      _previewJpg = null;
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
          engine: _hd ? MattingEngine.modnet : MattingEngine.mlkit,
          beauty: _beauty,
          clarity: _clarity);
      if (!mounted) return;
      setState(() {
        _result = result;
        _previewJpg = null;
        _resultVersion++;
      });
      // 出片已带上效果；预览图还要单独渲染一份（未裁剪的完整工作图）
      _refreshEffects();
    } on PipelineException catch (e) {
      if (mounted) setState(() => _error = Tr.of(context).pipelineError(e));
    } on PlatformException {
      // ML Kit 双通路均失败（如华为无 GMS 设备）：给可读提示而非堆栈
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).errMlkit);
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = AppLocalizations.of(context).processFailed('$e'));
      }
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
            onPressed: (result == null || _exporting) ? null : _goResult,
            child: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(AppLocalizations.of(context).saveAction,
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

  /// 生成最终交付 jpg（按当前裁剪框与效果强度）并进入检测/保存页。
  ///
  /// 裁剪/缩放/精修/二分压缩全在 isolate：旧版在主线程同步跑，
  /// 点「保存」瞬间会整页冻结数秒。
  Future<void> _goResult() async {
    final r = _result;
    if (r == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      final jpg = await compute(
        deliverWorker,
        DeliveryRequest(
          rgba: r.compositedRgba,
          width: r.compositedWidth,
          height: r.compositedHeight,
          crop: _currentCrop ?? r.autoCrop,
          faceRect: r.faceRect,
          targetWidth: _spec.pixelWidth,
          targetHeight: _spec.pixelHeight,
          bg: Uint8List.fromList(
              [_spec.background.r, _spec.background.g, _spec.background.b]),
          minKb: _spec.minFileKb,
          maxKb: _spec.maxFileKb,
          beauty: _beauty,
          clarity: _clarity,
          sharpen: _hd,
        ),
      );
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResultPage(jpgBytes: jpg, spec: _spec),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(AppLocalizations.of(context).processFailed('$e'))));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
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
            // 照片卡 + 扫描揭色（灰→彩，无需文字即表达处理进度）
            Card(
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: 160,
                height: 213,
                child: ScanRevealEffect(
                  child: Image.file(
                    File(widget.sourcePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.expand(),
                  ),
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
            SizedBox(width: 180, child: SmoothProgressBar(step: _step)),
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
        // 版本切换：高精修版（MODNet 发丝级）/ 原图普通版
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
                          key: ValueKey(_resultVersion),
                          imageBytes: _previewJpg ?? result.compositedJpg,
                          imageWidth: result.compositedWidth,
                          imageHeight: result.compositedHeight,
                          autoCrop: result.autoCrop,
                          aspect: _spec.aspect,
                          onChanged: (r) => _currentCrop = r,
                        ),
                        // 效果重算中：扫描动效表明「正在处理图片」
                        if (_effectsBusy)
                          const IgnorePointer(child: ScanOverlayEffect()),
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
                label: Text(l.chipPreview),
                selected: !_showOriginal,
                onSelected: (_) => setState(() => _showOriginal = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(l.chipOriginal),
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
              Text(l.editSwitchBg,
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
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
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

  /// 效果调节区：**面部精修**与**画质清晰度**两条独立通道，均默认 0。
  ///
  /// 拆成两条是因为它们解决的是两类问题：前者针对人脸（磨皮/去皱/匀肤/
  /// 轻度瘦脸），后者针对整图观感（锐度/通透度）。混在一个滑杆里
  /// 必然互相拖累——想要皮肤更干净就会连带把整图糊掉。
  Widget _effectsBar() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _slider(
            icon: Icons.face_retouching_natural,
            label: l.beautyLabel,
            value: _beauty,
            onChanged: (v) => setState(() => _beauty = v),
          ),
          _slider(
            icon: Icons.auto_awesome,
            label: l.clarityLabel,
            value: _clarity,
            onChanged: (v) => setState(() => _clarity = v),
          ),
        ],
      ),
    );
  }

  Widget _slider({
    required IconData icon,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon,
            size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        SizedBox(
          width: 52,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(
            value: value,
            divisions: 20,
            // 拖动中只更新数字（不触发重算），松手后防抖再进 isolate
            onChanged: onChanged,
            onChangeEnd: (_) => _scheduleEffects(),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text('${(value * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
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
          Text(_bgLabel(bg), style: Theme.of(context).textTheme.labelSmall),
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
