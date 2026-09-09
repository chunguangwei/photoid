
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/photo_spec.dart';
import '../services/image_pipeline.dart';
import 'result_page.dart';

/// 处理页：执行流水线（抠图→换底→裁剪→压缩），展示效果预览。
class EditPage extends StatefulWidget {
  const EditPage({super.key, required this.sourcePath, required this.spec});

  final String sourcePath;
  final PhotoSpec spec;

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

  @override
  void initState() {
    super.initState();
    _spec = widget.spec;
    _run();
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

  Future<void> _run() async {
    setState(() {
      _error = null;
      _result = null;
      _step = PipelineStep.preparing;
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
      ).run(widget.sourcePath, _spec);
      if (!mounted) return;
      setState(() => _result = result);
    } on PipelineException catch (e) {
      if (mounted) setState(() => _error = Tr.of(context).pipelineError(e));
    } catch (e) {
      if (mounted) setState(() => _error = AppLocalizations.of(context).processFailed('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: Text(Tr.of(context).specName(spec))),
      body: SafeArea(
        child: _error != null
            ? _buildError()
            : result == null
                ? _buildProgress()
                : _buildPreview(result),
      ),
      bottomNavigationBar: result == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ResultPage(
                      jpgBytes: result.jpgBytes,
                      spec: spec,
                    ),
                  )),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(AppLocalizations.of(context).complianceCheckSave,
                        style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildProgress() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_regenerating
                ? AppLocalizations.of(context).editRegenerating
                : Tr.of(context).step(_step)),
          ],
        ),
      );

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
    final kb = result.jpgBytes.lengthInBytes / 1024;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Image.memory(
                _showOriginal ? result.originalBytes : result.jpgBytes,
                fit: BoxFit.contain,
              ),
            ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          avatar: CircleAvatar(
                            radius: 8,
                            backgroundColor:
                                Color.fromARGB(255, bg.r, bg.g, bg.b),
                          ),
                          label: Text(_bgLabel(bg)),
                          selected: bg.name == _spec.background.name,
                          // 处理中禁用，避免多条流水线竞态（last-finisher-wins）
                          onSelected: (_result == null && _error == null)
                              ? null
                              : (_) => _switchBackground(bg),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
