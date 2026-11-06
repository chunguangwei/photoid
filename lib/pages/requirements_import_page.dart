import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/photo_spec.dart';
import '../services/requirements_ocr.dart';
import '../services/requirements_parser.dart';

class RequirementImportResult {
  const RequirementImportResult(this.spec, this.fileName, this.excerpt)
      : manual = false;
  const RequirementImportResult.manual()
      : spec = null,
        fileName = '',
        excerpt = '',
        manual = true;
  final bool manual;
  final PhotoSpec? spec;
  final String fileName, excerpt;
}

class RequirementsImportPage extends StatefulWidget {
  const RequirementsImportPage(
      {super.key, required this.imagePath, this.recognize});
  final String imagePath;
  final Future<String> Function(String)? recognize;
  @override
  State<RequirementsImportPage> createState() => _RequirementsImportPageState();
}

class _RequirementsImportPageState extends State<RequirementsImportPage> {
  RequirementsDraft? _draft;
  bool _loading = true, _failed = false, _jpeg = false, _confirmed = false;
  int _sequence = 0;
  SpecBackground? _background;
  final _width = TextEditingController(),
      _height = TextEditingController(),
      _min = TextEditingController(),
      _max = TextEditingController(),
      _name = TextEditingController(),
      _excerpt = TextEditingController();
  String _dimensionExcerpt = '', _sizeExcerpt = '', _backgroundExcerpt = '';
  String? _validation;
  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void dispose() {
    _sequence++;
    for (final c in [_width, _height, _min, _max, _name, _excerpt]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _read() async {
    final seq = ++_sequence;
    setState(() {
      _loading = true;
      _failed = false;
      _draft = null;
      _validation = null;
      _confirmed = false;
      _jpeg = false;
    });
    try {
      final text = await (widget.recognize ??
          RequirementsOcr.recognize)(widget.imagePath);
      final draft = parseRequirements(text);
      if (!mounted || seq != _sequence) return;
      _width.clear();
      _height.clear();
      _min.clear();
      _max.clear();
      _background = null;
      _excerpt.clear();
      _dimensionExcerpt = '';
      _sizeExcerpt = '';
      _backgroundExcerpt = '';
      _draft = draft;
      if (draft.dimensions.length == 1 && !draft.dimensions.single.ambiguous) {
        _chooseDimensions(draft.dimensions.single);
      }
      if (draft.sizes.length == 1) {
        _chooseSize(draft.sizes.single);
      }
      setState(() => _draft = draft);
    } catch (_) {
      if (mounted && seq == _sequence) setState(() => _failed = true);
    } finally {
      if (mounted && seq == _sequence) setState(() => _loading = false);
    }
  }

  void _chooseDimensions(DimensionCandidate d) {
    _dimensionExcerpt = d.excerpt;
    _width.text = '${d.width}';
    _height.text = '${d.height}';
    _confirmed = false;
    _updateExcerpt();
  }

  void _chooseSize(SizeCandidate s) {
    _sizeExcerpt = s.excerpt;
    _min.text = s.min?.toString() ?? '';
    _max.text = s.max?.toString() ?? '';
    _confirmed = false;
    _updateExcerpt();
  }

  void _updateExcerpt() {
    _excerpt.text = [_dimensionExcerpt, _sizeExcerpt, _backgroundExcerpt]
        .where((v) => v.isNotEmpty)
        .join('\n');
  }

  String _colorExcerpt(String color) {
    final expression = {
      'blue': r'蓝(?:色)?(?:底|背景)|\bblue(?:\s+background)?\b',
      'white': r'白(?:色)?(?:底|背景)|\bwhite(?:\s+background)?\b',
      'red': r'红(?:色)?(?:底|背景)|\bred(?:\s+background)?\b',
      'gray': r'灰(?:色)?(?:底|背景)|\bgr[ae]y(?:\s+background)?\b'
    }[color]!;
    return RegExp(expression, caseSensitive: false)
            .firstMatch(_draft?.text ?? '')
            ?.group(0) ??
        '';
  }

  static const _colors = {
    'blue': idPhotoBlue,
    'white': idPhotoWhite,
    'red': idPhotoRed,
    'gray': idPhotoGray
  };
  void _chooseBackground(String color) {
    _background = _colors[color];
    _backgroundExcerpt = _colorExcerpt(color);
    _confirmed = false;
    _updateExcerpt();
  }

  void _save() {
    final l = AppLocalizations.of(context);
    final w = int.tryParse(_width.text), h = int.tryParse(_height.text);
    final min = _min.text.trim().isEmpty ? 0 : int.tryParse(_min.text),
        max = _max.text.trim().isEmpty ? 0 : int.tryParse(_max.text);
    final name = _name.text.trim();
    if (!_jpeg ||
        !_confirmed ||
        _excerpt.text.trim().isEmpty ||
        _excerpt.text.length > 4000 ||
        _background == null ||
        w == null ||
        h == null ||
        w < 50 ||
        h < 50 ||
        w > 2000 ||
        h > 2000 ||
        w / h < 0.5 ||
        w / h > 2 ||
        min == null ||
        max == null ||
        min < 0 ||
        max < 0 ||
        min > 2048 ||
        max > 2048 ||
        (max > 0 && min > max) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(name)) {
      setState(() => _validation = l.workflowInvalid);
      return;
    }
    final text = _excerpt.text.trim();
    Navigator.pop(
        context,
        RequirementImportResult(
            PhotoSpec(
                id: 'imported',
                name: l.workflowExtract,
                pixelWidth: w,
                pixelHeight: h,
                minFileKb: min,
                maxFileKb: max,
                minWidth: w,
                maxWidth: w,
                minHeight: h,
                maxHeight: h,
                minRatio: h / w - 0.05,
                maxRatio: h / w + 0.05,
                background: _background!),
            name,
            text));
  }

  Widget _field(TextEditingController controller, String label,
          {bool number = true, String? fieldKey}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextFormField(
              key: fieldKey == null ? null : Key(fieldKey),
              controller: controller,
              decoration: InputDecoration(
                  labelText: label, border: const OutlineInputBorder()),
              keyboardType: number ? TextInputType.number : TextInputType.text,
              maxLength: number ? 5 : 80,
              onChanged: (_) {
                if (_confirmed) setState(() => _confirmed = false);
              }));
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), tr = Tr.of(context);
    final d = _draft;
    return Scaffold(
        appBar: AppBar(title: Text(l.workflowExtract)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Image.file(File(widget.imagePath),
              height: 180,
              cacheWidth: 1000,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.image_not_supported_outlined, size: 48)),
          const SizedBox(height: 12),
          Text(l.workflowOcrNote),
          if (_loading) ...[
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator())),
            Text(l.workflowRecognizing)
          ] else if (_failed || d == null || d.text.trim().isEmpty) ...[
            Text(_failed ? l.workflowOcrFailed : l.workflowNoText),
            TextButton(onPressed: _read, child: Text(l.workflowRetry)),
            TextButton(
                onPressed: () => Navigator.pop(
                    context, const RequirementImportResult.manual()),
                child: Text(l.workflowManual))
          ] else ...[
            ExpansionTile(
                title: Text(l.workflowOriginalText),
                children: [SelectableText(d.text)]),
            if (d.warnings.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l.workflowUnsupported,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            Text(l.workflowDimensions),
            for (final c in d.dimensions)
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.excerpt),
                  subtitle: Text('${c.width} × ${c.height} px'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() => _chooseDimensions(c))),
            _field(_width, l.workflowWidth, fieldKey: 'import-width'),
            _field(_height, l.workflowHeight, fieldKey: 'import-height'),
            Text(l.workflowSize),
            for (final c in d.sizes)
              TextButton(
                  onPressed: () => setState(() => _chooseSize(c)),
                  child: Text(c.excerpt)),
            _field(_min, l.workflowMinimum),
            _field(_max, l.workflowMaximum),
            _field(_name, l.workflowFilename,
                number: false, fieldKey: 'import-name'),
            if (d.backgrounds.isNotEmpty) ...[
              Text(l.workflowDetectedBackgrounds),
              Wrap(spacing: 8, children: [
                for (final color in d.backgrounds)
                  ActionChip(
                      label: Text(_colorExcerpt(color)),
                      onPressed: () => setState(() => _chooseBackground(color)))
              ]),
            ],
            DropdownButtonFormField<SpecBackground>(
                key: ValueKey(_background),
                initialValue: _background,
                isExpanded: true,
                decoration:
                    InputDecoration(labelText: l.workflowChooseBackground),
                items: [
                  for (final bg in _colors.values)
                    DropdownMenuItem(value: bg, child: Text(tr.bgName(bg)))
                ],
                onChanged: (bg) => setState(() {
                      if (bg != null) {
                        _chooseBackground(_colors.entries
                            .firstWhere((e) => identical(e.value, bg))
                            .key);
                      }
                    })),
            const SizedBox(height: 12),
            Text(l.workflowExcerptExport),
            TextFormField(
                key: const Key('import-excerpt'),
                controller: _excerpt,
                minLines: 2,
                maxLines: 5,
                maxLength: 4000,
                decoration: InputDecoration(
                    labelText: l.workflowExcerpt,
                    border: const OutlineInputBorder()),
                onChanged: (_) => setState(() => _confirmed = false)),
            CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _jpeg,
                onChanged: (v) => setState(() => _jpeg = v ?? false),
                title: Text(l.workflowJpeg)),
            CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _confirmed,
                onChanged: (v) => setState(() => _confirmed = v ?? false),
                title: Text(l.workflowConfirmValues)),
            if (_validation != null)
              Text(_validation!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            FilledButton(
                key: const Key('import-confirm'),
                onPressed: _save,
                child: Text(l.workflowAdd)),
          ],
          const SizedBox(height: 24)
        ]));
  }
}
