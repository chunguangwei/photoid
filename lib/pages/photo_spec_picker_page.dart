import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/photo_spec.dart';
import '../services/spec_library.dart';
import 'custom_spec_page.dart';

class PhotoSpecPickerPage extends StatefulWidget {
  const PhotoSpecPickerPage({super.key, this.initialSpec});
  final PhotoSpec? initialSpec;
  @override
  State<PhotoSpecPickerPage> createState() => _PhotoSpecPickerPageState();
}

class _PhotoSpecPickerPageState extends State<PhotoSpecPickerPage> {
  final _specs = SpecLibrary.load();
  String _query = '';
  Future<void> _custom() async {
    final spec = await Navigator.push<PhotoSpec>(
        context,
        MaterialPageRoute(
            builder: (_) => CustomSpecPage(
                returnSpec: true, initialSpec: widget.initialSpec)));
    if (spec != null && mounted) Navigator.pop(context, spec);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), tr = Tr.of(context);
    return Scaffold(
        appBar: AppBar(title: Text(l.finderPickSize)),
        body: SafeArea(
            child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                  key: const Key('spec-search'),
                  decoration: InputDecoration(
                      labelText: l.finderSizeSearch,
                      prefixIcon: const Icon(Icons.search)),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                      key: const Key('spec-custom'),
                      onPressed: _custom,
                      icon: const Icon(Icons.tune),
                      label: Text(l.finderCustomSize)))),
          Expanded(
              child: FutureBuilder<List<PhotoSpec>>(
                  future: _specs,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text(l.finderFailed));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final specs = snapshot.data!
                        .where((s) =>
                            '${s.name} ${s.nameEn ?? ''} ${s.pixelWidth} ${s.pixelHeight}'
                                .toLowerCase()
                                .contains(_query))
                        .toList();
                    return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: specs.length,
                        itemBuilder: (context, index) {
                          final spec = specs[index];
                          return Card(
                              child: ListTile(
                                  key: ValueKey('preset-${spec.id}'),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  title: Text(tr.specName(spec)),
                                  subtitle: Text(
                                      '${spec.pixelWidth} × ${spec.pixelHeight} px · ${spec.minFileKb}–${spec.maxFileKb == 0 ? "∞" : spec.maxFileKb} KB'),
                                  trailing: Icon(
                                      spec.id == widget.initialSpec?.id
                                          ? Icons.check_circle
                                          : Icons.chevron_right),
                                  onTap: () => Navigator.pop(context, spec)));
                        });
                  })),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.finderShortCaution,
                  style: Theme.of(context).textTheme.bodySmall)),
        ])));
  }
}
