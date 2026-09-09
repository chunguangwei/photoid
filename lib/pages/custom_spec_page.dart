import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/photo_spec.dart';
import 'spec_detail_page.dart';

/// 自定义规格表单：命名/像素/文件大小/底色 → 构造 PhotoSpec 进详情页。
class CustomSpecPage extends StatefulWidget {
  const CustomSpecPage({super.key});

  @override
  State<CustomSpecPage> createState() => _CustomSpecPageState();
}

class _CustomSpecPageState extends State<CustomSpecPage> {
  final _name = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  final _minKb = TextEditingController();
  final _maxKb = TextEditingController();
  SpecBackground _bg = idPhotoBackgrounds.first;

  @override
  void dispose() {
    _name.dispose();
    _width.dispose();
    _height.dispose();
    _minKb.dispose();
    _maxKb.dispose();
    super.dispose();
  }

  void _create() {
    final l = AppLocalizations.of(context);
    final w = int.tryParse(_width.text.trim());
    final h = int.tryParse(_height.text.trim());
    final minKb = int.tryParse(_minKb.text.trim());
    final maxKb = int.tryParse(_maxKb.text.trim());
    final valid = w != null &&
        h != null &&
        w >= 50 &&
        w <= 2000 &&
        h >= 50 &&
        h <= 2000 &&
        minKb != null &&
        maxKb != null &&
        minKb >= 5 &&
        minKb <= 2048 &&
        maxKb >= 5 &&
        maxKb <= 2048 &&
        minKb <= maxKb;
    if (!valid) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.customInvalid)));
      return;
    }
    final ratio = h / w;
    final name = _name.text.trim();
    final spec = PhotoSpec(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name.isEmpty ? '$w×$h' : name,
      pixelWidth: w,
      pixelHeight: h,
      minFileKb: minKb,
      maxFileKb: maxKb,
      minWidth: w,
      maxWidth: w,
      minHeight: h,
      maxHeight: h,
      minRatio: ratio - 0.05,
      maxRatio: ratio + 0.05,
      background: _bg,
    );
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => SpecDetailPage(spec: spec),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.customTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: l.customName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _width,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l.customWidth,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _height,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l.customHeight,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minKb,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l.customMinKb,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxKb,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l.customMaxKb,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SpecBackground>(
              initialValue: _bg,
              decoration: InputDecoration(
                labelText: l.specBgColor,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final bg in idPhotoBackgrounds)
                  DropdownMenuItem(
                    value: bg,
                    child: Text(localizedBgName(context, bg)),
                  ),
              ],
              onChanged: (v) => setState(() => _bg = v ?? _bg),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _create,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(l.customCreate),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
