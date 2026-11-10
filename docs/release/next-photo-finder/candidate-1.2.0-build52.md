# 1.2.0 候选 build 52：相册批量滑动多选修复

## 问题

用户报告「从相册批量无法滑动多选」。build 51 的相册批量入口直接呈现
PHPicker，系统仅提供逐个点选，连续滑动手势不可用（Apple 文档：
`selection = .ordered/.continuous` 不引入滑动手势）。

## 修复（e1fb32f）

- 新增 App 自有 PhotoKit 网格选择器（`ios/Runner/PhotoSwipePickerController.swift`）：
  单指横向滑动连选、长按后拖动连选、反向拖动恢复基线、再次滑过取消选择、
  500 张上限、边缘自动滚动；纵向滑动仍正常浏览。
- 选择核心 `ios/Runner/PhotoSweepSelection.swift` 为纯逻辑，
  `test/native/photo_selection_tests.swift` 覆盖前进/反向/收缩/取消/上限/既有选择保留。
- 权限：`.readWrite` 请求，拒绝/受限时回退系统 PHPicker（「使用系统选图」按钮），
  受限访问提供「管理可见照片」入口；只加载可见缩略图，确认后逐张有界读取原图
  （30MB 上限流式取消，保留指纹校验），不上传、不后台扫描整库。
- 界面为中文手势提示 + 已选计数 + 显式完成/取消；语言由 Flutter 侧
  `languageCode` 传入（`photo_finder_session.dart`/`photo_finder_page.dart`）。
- 手势修正：长按拖动时 pan 越过阈值不再取消长按扫选
  （`shouldRecognizeSimultaneouslyWith` + `allowableMovement` 放开）；
  `presentLimitedLibraryPicker` 用 iOS 14 无 completion 变体（deployment 15.5）。
- 版本号 1.2.0（52）。

## 验证

- 纯 Swift 扫选测试通过（forward/reverse/shrink/deselect/baseline/500 cap）。
- `xcrun swiftc -typecheck -target arm64-apple-ios15.5` 通过。
- `flutter build ios --debug --no-codesign` 通过；`flutter analyze` 无问题。
- 既有 finder Flutter 测试 25 项全部通过。
- 真机手势体验：见下方设备验证记录。
