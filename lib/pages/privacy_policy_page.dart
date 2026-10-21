import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

/// 可离线阅读的政策说明，并提供系统浏览器中的完整政策链接。
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static final policyUri =
      Uri.parse('https://chunguangwei.github.io/photoid/privacy-policy');

  Future<void> _openPolicy(BuildContext context) async {
    try {
      if (await launchUrl(policyUri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // 未安装浏览器或系统拒绝时保留可复制的地址。
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).linkOpenFailed)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.privacyPolicyTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextButton.icon(
              onPressed: () => _openPolicy(context),
              icon: const Icon(Icons.open_in_new),
              label: Text(l.privacyPolicyTitle),
            ),
            SelectableText(policyUri.toString()),
            const SizedBox(height: 16),
            SelectableText(l.privacyPolicyBody),
          ],
        ),
      ),
    );
  }
}
