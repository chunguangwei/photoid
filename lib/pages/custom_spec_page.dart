import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/photo_spec.dart';
import '../services/custom_spec_store.dart';
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
  final _dpi = TextEditingController(text: '300');
  SpecBackground _bg = idPhotoBackgrounds.first;

  /// 尺寸输入单位：true=PX，false=mm（mm 经 DPI 换算 px）
  bool _unitPx = true;

  /// mm → px（DPI 换算）；非法/空返回 null
  int? _toPx(String raw) {
    final v = double.tryParse(raw.trim());
    if (v == null || v <= 0) return null;
    if (_unitPx) return v.round();
    final dpi = int.tryParse(_dpi.text.trim()) ?? 300;
    return (v / 25.4 * dpi).round();
  }

  /// 单位切换：换算已填数值（px⇄mm，经 DPI），避免用户重输
  void _switchUnit() {
    final dpi = int.tryParse(_dpi.text.trim()) ?? 300;
    double? conv(String raw) {
      final v = double.tryParse(raw.trim());
      if (v == null || v <= 0) return null;
      // 切到 mm：px→mm；切到 px：mm→px（_unitPx 为切换前状态）
      return _unitPx ? v * 25.4 / dpi : v / 25.4 * dpi;
    }

    String fmt(double v) {
      final r = _unitPx ? v : v.roundToDouble();
      return r == r.roundToDouble()
          ? r.toInt().toString()
          : r.toStringAsFixed(1);
    }

    setState(() {
      final w = conv(_width.text);
      final h = conv(_height.text);
      if (w != null) _width.text = fmt(w);
      if (h != null) _height.text = fmt(h);
      _unitPx = !_unitPx;
    });
  }

  void _reset() {
    setState(() {
      _name.clear();
      _width.clear();
      _height.clear();
      _minKb.clear();
      _maxKb.clear();
      _dpi.text = '300';
      _unitPx = true;
      _bg = idPhotoBackgrounds.first;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _width.dispose();
    _height.dispose();
    _minKb.dispose();
    _maxKb.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l = AppLocalizations.of(context);
    final w = _toPx(_width.text);
    final h = _toPx(_height.text);
    final minKb = int.tryParse(_minKb.text.trim());
    final maxKb = int.tryParse(_maxKb.text.trim());
    final valid = w != null &&
        h != null &&
        w >= 50 &&
        w <= 2000 &&
        h >= 50 &&
        h <= 2000 &&
        // aspect（宽/高）限制在 [0.5, 2]：构图算法的扩边画布按 cropH 设计，
        // 超出该范围的极端比例会导致裁剪越界
        w / h >= 0.5 &&
        w / h <= 2.0 &&
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
    // 持久化保存（首页可复用/删除）
    await CustomSpecStore.save(spec);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => SpecDetailPage(spec: spec),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.customTitle),
        actions: [
          TextButton(onPressed: _reset, child: Text(l.customReset)),
        ],
      ),
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
                    decoration: InputDecoration(
                      labelText: _unitPx ? l.customWidth : l.customWidthMm,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _height,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _unitPx ? l.customHeight : l.customHeightMm,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 单位切换（PX ⇄ mm）
                Tooltip(
                  message: l.customTapToSwitch,
                  child: InkWell(
                    onTap: _switchUnit,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        Text(_unitPx ? l.customUnitPx : l.customUnitMm,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary)),
                        const Icon(Icons.swap_horiz, size: 18),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dpi,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l.customDpi,
                border: const OutlineInputBorder(),
              ),
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
