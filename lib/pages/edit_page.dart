
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
  String _step = '准备中…';
  PipelineResult? _result;
  String? _error;
  bool _showOriginal = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _error = null;
      _result = null;
      _step = '准备中…';
    });
    try {
      final result = await ImagePipeline(
        onProgress: (s) {
          if (mounted) setState(() => _step = s);
        },
      ).run(widget.sourcePath, widget.spec);
      if (!mounted) return;
      setState(() => _result = result);
    } on PipelineException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = AppLocalizations.of(context).processFailed('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
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
            Text(Tr.of(context).step(_step)),
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
              Text(Tr.of(context).pipelineError(_error!),
                  textAlign: TextAlign.center),
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
          padding: const EdgeInsets.all(12),
          child: Text(
            '${widget.spec.pixelWidth}×${widget.spec.pixelHeight}px · '
            '${Tr.of(context).bgName(widget.spec.background)} · '
            '${kb.toStringAsFixed(0)}KB',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
