import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../services/album_service.dart';

/// 我的相册：浏览 App 内保存的成片，点击查看、长按删除。
class MyAlbumPage extends StatefulWidget {
  const MyAlbumPage({super.key});

  @override
  State<MyAlbumPage> createState() => _MyAlbumPageState();
}

class _MyAlbumPageState extends State<MyAlbumPage> {
  late Future<List<File>> _future;

  @override
  void initState() {
    super.initState();
    _future = AlbumService.list();
  }

  void _reload() => setState(() => _future = AlbumService.list());

  Future<void> _confirmDelete(File file) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p.basename(file.path)),
        content: Text(l.albumDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.albumDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AlbumService.delete(file.path);
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.albumDeleted)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.albumTitle)),
      body: SafeArea(
        child: FutureBuilder<List<File>>(
          future: _future,
          builder: (context, snapshot) {
            final files = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (files == null || files.isEmpty) {
              return Center(child: Text(l.albumEmpty));
            }
            return GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              padding: const EdgeInsets.all(4),
              children: [
                for (final file in files)
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _AlbumViewerPage(file: file),
                    )),
                    onLongPress: () => _confirmDelete(file),
                    child: Hero(
                      tag: file.path,
                      child: Image.file(file,
                          fit: BoxFit.cover, cacheWidth: 360),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 全屏查看：双指缩放 + 平移。
class _AlbumViewerPage extends StatelessWidget {
  const _AlbumViewerPage({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(p.basename(file.path)),
      ),
      body: InteractiveViewer(
        maxScale: 8,
        child: Center(
          child: Hero(
            tag: file.path,
            child: Image.file(file),
          ),
        ),
      ),
    );
  }
}
