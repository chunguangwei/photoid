
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/photo_spec.dart';
import '../services/image_pipeline.dart';
import '../services/suit_compositor.dart';
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

  static const _hdPrefKey = 'hd_mode_enabled';
  static const _beautyPrefKey = 'beauty_level';

  /// 美颜档位（持久化）；正装样式（会话内）
  BeautyLevel _beauty = BeautyLevel.standard;
  SuitStyle _suit = SuitStyle.none;

  /// 预览用合成图缓存：应用美颜/正装后的 compositedJpg
  Uint8List? _previewJpg;

  /// 高精修版（MODNet 发丝级抠图+磨皮）开关；false=普通版（ML Kit 快速）。
  /// 持久化到 SharedPreferences，下次进编辑页保持上次选择。
  bool _hd = true;

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
        if (b != null && b >= 0 && b < BeautyLevel.values.length) {
          _beauty = BeautyLevel.values[b];
        }
      });
    }
  }

  /// 美颜/正装变化：重算预览合成图（编辑器回到自动构图，与成片参数一致）
  void _refreshEffects({bool persistBeauty = false}) {
    if (persistBeauty) {
      SharedPreferences.getInstance()
          .then((p) => p.setInt(_beautyPrefKey, _beauty.index));
    }
    final r = _result;
    if (r == null) return;
    var imgOut = r.composited.clone();
    if (_suit != SuitStyle.none) {
      imgOut = SuitCompositor.apply(imgOut, r.faceRect, _suit);
    }
    if (_beauty != BeautyLevel.off) {
      imgOut = ImagePipeline.beautify(imgOut, r.faceRect, _beauty);
    }
    setState(() {
      _previewJpg = img.encodeJpg(imgOut, quality: 90);
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
    if (_suit != SuitStyle.none) {
      out = SuitCompositor.apply(out, face, _suit);
    }
    if (_beauty != BeautyLevel.off) {
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
            Card(
              clipBehavior: Clip.antiAlias,
              child: Image.file(
                File(widget.sourcePath),
                width: 160,
                height: 213,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const SizedBox(width: 160, height: 213),
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
            const SizedBox(
                width: 180, child: LinearProgressIndicator()),
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
                  : CropEditor(
                      key: ValueKey(_previewJpg?.length),
                      imageBytes: _previewJpg ?? result.compositedJpg,
                      imageWidth: result.composited.width,
                      imageHeight: result.composited.height,
                      autoCrop: result.autoCrop,
                      aspect: _spec.aspect,
                      onChanged: (r) => _currentCrop = r,
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

  /// 美颜档位 + 正装选择行（与成片同参数，预览实时生效）
  Widget _effectsBar() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(l.beautyLabel,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final lv in BeautyLevel.values)
                    _miniChip(_beautyLabel(lv, l), _beauty == lv, () {
                      _beauty = lv;
                      _refreshEffects(persistBeauty: true);
                    }),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Text(l.suitLabel,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final st in SuitStyle.values)
                    _miniChip(_suitLabel(st, l), _suit == st, () {
                      _suit = st;
                      _refreshEffects();
                    }),
                ]),
              ),
            ),
          ]),
          if (_suit != SuitStyle.none)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l.suitComplianceHint,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }

  Widget _miniChip(String label, bool selected, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          labelStyle: const TextStyle(fontSize: 12),
          visualDensity: VisualDensity.compact,
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );

  String _beautyLabel(BeautyLevel lv, AppLocalizations l) => switch (lv) {
        BeautyLevel.off => l.beautyOff,
        BeautyLevel.light => l.beautyLight,
        BeautyLevel.standard => l.beautyStandard,
        BeautyLevel.strong => l.beautyStrong,
      };

  String _suitLabel(SuitStyle st, AppLocalizations l) => switch (st) {
        SuitStyle.none => l.suitNone,
        SuitStyle.menNavy => l.suitMenNavy,
        SuitStyle.menCharcoal => l.suitMenCharcoal,
        SuitStyle.womenNavy => l.suitWomen,
      };

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
