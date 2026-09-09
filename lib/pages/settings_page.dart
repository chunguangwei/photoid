import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/update_service.dart';
import 'update_dialog.dart';
import 'my_album_page.dart';

/// 设置页（「我的」Tab）：我的相册 + 检查更新 + 隐私说明 + 关于。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.showAlbumEntry = false});

  final bool showAlbumEntry;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((p) => mounted ? setState(() => _version = p.version) : null);
  }

  Future<void> _checkUpdate() async {
    final l = AppLocalizations.of(context);
    setState(() => _checking = true);
    try {
      // 严格版：网络失败抛异常 → 明确提示「检查失败」，而非误报「已是最新」
      final info = await UpdateService().checkUpdateStrict();
      if (!mounted) return;
      if (info != null) {
        showUpdateDialog(context, info);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.updateLatest)));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.updateCheckFailed)));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        children: [
          if (widget.showAlbumEntry)
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.homeMyAlbum),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const MyAlbumPage(),
              )),
            ),
          if (Platform.isAndroid)
            ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: Text(l.updateCheck),
              trailing: _checking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _checking ? null : _checkUpdate,
            ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l.privacyNote),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(l.settingsAbout,
                style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l.settingsVersion(_version)),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: Text(l.settingsLicense),
            subtitle: Text(l.settingsContact),
          ),
        ],
      ),
    );
  }
}
