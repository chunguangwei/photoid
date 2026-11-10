// build55 商店素材采集：加强版真机界面（首页/加强版排序/模型页）。
// 集成测试重装会清空容器：测试等待 devicectl 重推模型包（按字节判齐）。
// 运行：flutter test integration_test/enhanced_capture_test.dart -d <device>
// 采集落 Documents/captures/，用 devicectl copy from 拉回。
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photoid/l10n/app_localizations.dart';
import 'package:photoid/pages/embedding_model_page.dart';
import 'package:photoid/pages/home_page.dart';
import 'package:photoid/pages/photo_finder_page.dart';
import 'package:photoid/services/application_task_store.dart';
import 'package:photoid/services/embedding_model_store.dart';
import 'package:photoid/services/photo_finder_demo.dart';
import 'package:photoid/services/photo_finder_session.dart';
import 'package:photoid/theme/app_theme.dart';

class FixturePhotoGateway implements FinderGateway {
  FixturePhotoGateway(this.paths);
  final List<String> paths;
  final native = NativeFinderGateway();
  @override
  Future<dynamic> call(String method, Map<String, dynamic> args) =>
      ['choosePhotos', 'chooseFiles', 'chooseDirectory'].contains(method)
          ? native.call(
              'openDemo', {'paths': paths, 'asPhotoProviders': Platform.isIOS})
          : native.call(method, args);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture enhanced finder screens for store assets',
      (tester) async {
    final temp = await getTemporaryDirectory();
    final captures =
        await Directory('${temp.path}/enhanced_captures').create(recursive: true);
    // 等模型包重推（App 文档目录 embedding_model/，5 文件字节齐）。
    final store = await EmbeddingModelStore.open();
    for (var i = 0;
        i < 200 && store.status != EmbeddingModelStatus.ready;
        i++) {
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    expect(store.status, EmbeddingModelStatus.ready,
        reason: 'push model pack to Documents/embedding_model/');
    final root = await temp.createTemp('cap_task_');
    final taskStore = ApplicationTaskStore(root);
    final paths = await writeFinderDemo(root);
    final queries = {'en': 'blue sky with clouds', 'zh': '证件照 人像'};
    try {
      for (final lang in ['en', 'zh']) {
        // 1) 首页（找照片入口所在）。
        await tester.pumpWidget(MaterialApp(
            key: ValueKey('home$lang'),
            debugShowCheckedModeBanner: false,
            locale: Locale(lang),
            theme: photoIdTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomePage()));
        await tester.pumpAndSettle();
        await File('${captures.path}/01_home-$lang.png')
            .writeAsBytes(await binding.takeScreenshot('home-$lang'));
        // 2) 加强版排序结果。
        await tester.pumpWidget(MaterialApp(
            key: ValueKey('finder$lang'),
            debugShowCheckedModeBanner: false,
            locale: Locale(lang),
            theme: photoIdTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PhotoFinderPage(
                store: taskStore,
                gateway: FixturePhotoGateway(paths),
                embeddingStore: store)));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        await tester.tap(find.byKey(const Key('finder-size')));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }
        await File('${captures.path}/02_sizes-$lang.png')
            .writeAsBytes(await binding.takeScreenshot('sizes-$lang'));
        await tester.tap(find.byKey(const ValueKey('preset-one_inch')));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }
        await File('${captures.path}/03_sources-$lang.png')
            .writeAsBytes(await binding.takeScreenshot('sources-$lang'));
        await tester.tap(find.byKey(const Key('finder-photos')));
        await tester.pump(const Duration(milliseconds: 300));
        // 等结果网格渲染（toggle 出现即批次完成）；不依赖进度条出现时机。
        for (var n = 0;
            n < 600 &&
                find
                    .byKey(const Key('enhanced-toggle'))
                    .evaluate()
                    .isEmpty;
            n++) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byKey(const Key('enhanced-toggle')), findsOneWidget);
        await tester.tap(find.byKey(const Key('enhanced-toggle')));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }
        expect(find.byKey(const Key('enhanced-input')), findsOneWidget);
        await tester.enterText(
            find.byKey(const Key('enhanced-input')), queries[lang]!);
        await tester.pump();
        await tester.tap(find.byIcon(Icons.arrow_forward));
        final stopLabel = lang == 'zh' ? '停止排序' : 'Stop ranking';
        for (var i = 0;
            i < 20 && find.text(stopLabel).evaluate().isEmpty;
            i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        for (var n = 0;
            n < 480 && find.text(stopLabel).evaluate().isNotEmpty;
            n++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 120));
        }
        await tester.pump(const Duration(milliseconds: 600));
        await File('${captures.path}/04_enhanced-$lang.png')
            .writeAsBytes(await binding.takeScreenshot('enhanced-$lang'));
        // 3) 模型管理页（已装状态）。
        await tester.pumpWidget(MaterialApp(
            key: ValueKey('model$lang'),
            debugShowCheckedModeBanner: false,
            locale: Locale(lang),
            theme: photoIdTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: EmbeddingModelPage(store: store)));
        await tester.pumpAndSettle();
        await File('${captures.path}/05_model-$lang.png')
            .writeAsBytes(await binding.takeScreenshot('model-$lang'));
      }
    } finally {
      // 复制到 Documents/enhanced_captures（tmp 目录 devicectl 拉不到）。
      final docs = await getApplicationDocumentsDirectory();
      final out =
          Directory('${docs.path}/enhanced_captures');
      await out.create(recursive: true);
      for (final f in captures.listSync().whereType<File>()) {
        await f.copy('${out.path}/${f.uri.pathSegments.last}');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 25)));
}
