// build55 商店素材采集：加强版真机界面（首页/规格/来源/加强版排序/模型页）。
// 集成测试重装会清空容器：测试等待 devicectl 重推模型包（按字节判齐）。
// 运行：flutter test integration_test/enhanced_capture_test.dart -d <device>
// 采集落 Documents/enhanced_captures/，测试结束后立即用 devicectl copy from 拉回。
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
import 'package:photoid/services/demo_task.dart';
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
    // 步骤日志：外部每 20s 拉 Documents/enhanced_captures/status.txt 定位卡点。
    final docs0 = await getApplicationDocumentsDirectory();
    final statusDir =
        Directory('${docs0.path}/enhanced_captures')
      ..createSync(recursive: true);
    final statusFile = File('${statusDir.path}/status.txt');
    void note(String s) =>
        statusFile.writeAsStringSync('${DateTime.now().toIso8601String()} $s\n',
            mode: FileMode.append);
    note('test-start');
    // 不设前台守卫：run11 实证 lifecycleState 非 resumed 时
    // takeScreenshot 仍输出真实页面，skip 会误伤整轮采集。
    // 等模型包重推（App 文档目录 embedding_model/，5 文件字节齐）。
    final store = await EmbeddingModelStore.open();
    for (var i = 0;
        i < 300 && store.status != EmbeddingModelStatus.ready;
        i++) {
      if (i % 10 == 9) {
        final docDir = (await getApplicationDocumentsDirectory()).path;
        final sz = await Future.wait(['model_q4f16.onnx', 'model_q4f16.onnx_data', 'vision_encoder_q4f16.onnx', 'vision_encoder_q4f16.onnx_data', 'tokenizer.json'].map((f) async {
          try { return await File('$docDir/embedding_model/$f').length(); } catch (_) { return -1; }
        }));
        note('model-wait-$i:${sz.join("/")}');
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    note('model-status:${store.status.name}');
    expect(store.status, EmbeddingModelStatus.ready,
        reason: 'push model pack to Documents/embedding_model/');
    final root = await temp.createTemp('cap_task_');
    final taskStore = ApplicationTaskStore(root);
    final paths = await writeFinderDemo(root);
    final docsDir = await getApplicationDocumentsDirectory();
    final staleFlag = File('${docsDir.path}/_captures_pulled');
    if (staleFlag.existsSync()) await staleFlag.delete();
    Future<void> export(String lang, String name, List<int> bytes) async {
      await File('${captures.path}/$name-$lang.png').writeAsBytes(bytes);
      await File('${statusDir.path}/$name-$lang.png').writeAsBytes(bytes);
      note('export-$name-$lang');
    }
    final queries = {
      'en': 'office photo in a business suit',
      'zh': '穿西装的职业照'
    };
    Object? bodyError;
    try {
      for (final lang in ['en', 'zh']) {
        Widget wrap(Widget home) => MaterialApp(
            key: ValueKey('$home$lang'),
            debugShowCheckedModeBanner: false,
            locale: Locale(lang),
            theme: photoIdTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: home);
        // 1) 首页（找照片入口所在）。
        await tester.pumpWidget(wrap(const HomePage()));
        await tester.pumpAndSettle();
        await export(lang, '01_home', await binding.takeScreenshot('home-$lang'));
        note('shot-01-$lang');
        // 2) 规格选择 + 来源区（draft 页，不依赖分析结果）。
        await tester.pumpWidget(wrap(PhotoFinderPage(
            store: taskStore,
            gateway: FixturePhotoGateway(paths),
            embeddingStore: store)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('finder-size')));
        await tester.pumpAndSettle();
        await export(lang, '02_sizes', await binding.takeScreenshot('sizes-$lang'));
        note('shot-02-$lang');
        await tester.tap(find.byKey(const ValueKey('preset-one_inch')));
        await tester.pumpAndSettle();
        await export(lang, '03_sources', await binding.takeScreenshot('sources-$lang'));
        note('shot-03-$lang');
        // 3) 加强版排序（run1 验证过：taskId 模式，规格已在任务内）。
        final task = await DemoTask.open(taskStore, lang);
        await tester.pumpWidget(wrap(PhotoFinderPage(
            key: UniqueKey(),
            taskId: task.id,
            store: taskStore,
            gateway: FixturePhotoGateway(paths),
            embeddingStore: store)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('finder-photos')));
        final analysisT0 = DateTime.now();
        // settle 一律 20s 有界：设备侧分析挂起要快失败、留痕，勿烧 10 分钟。
        try {
          await tester.pumpAndSettle(
              const Duration(milliseconds: 100),
              EnginePhase.sendSemanticsUpdate, const Duration(seconds: 2));
        } catch (e) {
          note('settle-timeout-post-tap');
        }
        note('post-tap-progress:${find.byType(LinearProgressIndicator).evaluate().length}');
        for (var n = 0;
            n < 240 &&
                find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
            n++) {
          if (DateTime.now().difference(analysisT0) >
              const Duration(seconds: 150)) {
            note('analysis-deadline-hit');
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 250));
          if (n % 40 == 39) note('analysis-wait-$n');
          try {
            await tester.pumpAndSettle(const Duration(milliseconds: 100),
                EnginePhase.sendSemanticsUpdate,
                const Duration(seconds: 2));
          } catch (_) {}
        }
        note('analysis-done-$lang:${find.byKey(const Key("enhanced-toggle")).evaluate().length}');
        expect(find.byKey(const Key('enhanced-toggle')), findsOneWidget,
            reason: 'batch analysis must finish and render result grid');
        await tester.tap(find.byKey(const Key('enhanced-toggle')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('enhanced-input')), findsOneWidget);
        await tester.enterText(
            find.byKey(const Key('enhanced-input')), queries[lang]!);
        await tester.pump();
        await tester.tap(find.byIcon(Icons.arrow_forward));
        final stopLabel = lang == 'zh' ? '停止排序' : 'Stop ranking';
        for (var i = 0;
            i < 40 && find.text(stopLabel).evaluate().isEmpty;
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
        // 结果网格在输入框下方；点「全部照片」让整批重排结果入镜。
        final allChip = find.textContaining(
            lang == 'zh' ? '全部照片' : 'All photos');
        note('allchip:${allChip.evaluate().length}');
        if (allChip.evaluate().isNotEmpty) {
          await tester.tap(allChip.first);
          await tester.pump(const Duration(milliseconds: 400));
        }
        final firstCard =
            find.byKey(const ValueKey('finder-result-portrait.jpg'));
        // 懒构建网格：evaluate 对屏外恒空，必须真滚才建卡。滚到首卡
        // 入镜后回拉一点，让查询输入框与首行网格同屏（run34/36 复盘）。
        try {
          await tester.scrollUntilVisible(firstCard, 300,
              scrollable: find.byType(Scrollable).first);
          await tester.pump(const Duration(milliseconds: 400));
          await tester.drag(find.byType(Scrollable).first,
              const Offset(0, 150));
          await tester.pump(const Duration(milliseconds: 400));
        } catch (_) {
          // 滚不到首卡时保持当前画面截图，不中断整轮采集。
        }
        note('rank-done-$lang');
        await export(lang, '04_enhanced', await binding.takeScreenshot('enhanced-$lang'));
        note('shot-04-$lang');
        // 4) 模型管理页（已装状态）。
        await tester.pumpWidget(wrap(EmbeddingModelPage(store: store)));
        await tester.pumpAndSettle();
        await export(lang, '05_model', await binding.takeScreenshot('model-$lang'));
        note('shot-05-$lang');
      }
    } catch (e, st) {
      bodyError = e;
      note('body-error:$e');
      // ignore: unused_local_variable
      final stackTrace = st.toString().split('\n').take(4).join(' <- ');
      note('body-stack:$stackTrace');
    } finally {
      // 复制到 Documents/enhanced_captures（tmp 目录 devicectl 拉不到）。
      final docs = await getApplicationDocumentsDirectory();
      final out = Directory('${docs.path}/enhanced_captures');
      await out.create(recursive: true);
      for (final f in captures.listSync().whereType<File>()) {
        await f.copy('${out.path}/${f.uri.pathSegments.last}');
      }
      note('exported-${captures.listSync().length}');
      // 等外部把图拉走（flutter test 结束会卸载 App 连带清容器）：
      // 外部 copy from 成功后回写 Documents/_captures_pulled 作放行标志。
      final gate = File('${docs.path}/_captures_pulled');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      await root.delete(recursive: true);
      // 正文失败时无全量可拉：立即抛原始异常，不等闸门。
      if (bodyError != null) throw bodyError;
      for (var i = 0; i < 96 && !gate.existsSync(); i++) {
        await Future<void>.delayed(const Duration(seconds: 5));
      }
      note('gate-checked:${gate.existsSync()}');
      expect(gate.existsSync(), isTrue, reason: 'captures not pulled in 8min');
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}
