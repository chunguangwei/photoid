# 真机验收脚本模板

尚未完成真机验收：已连接设备的 VM Service 持续重置连接，未取得完整流程截图。

Flutter 3.47 当前 Android Release 会排除 dev 插件依赖，但插件注册器仍引用 integration_test，导致编译失败。因此将测试工具隔离为模板，不作为生产依赖。

仅在独立测试工作区执行：

1. `flutter pub add --dev integration_test --sdk=flutter`。
2. 将 `review_flow_test.dart.template` 复制到根目录 `integration_test/review_flow_test.dart`，将 `review_driver.dart.template` 复制到 `test_driver/review_driver.dart`。
3. 把仓库示例图复制到已安装应用的 Documents/photoid_review_fixture.png；不使用用户照片。
4. 解锁真机后执行 `flutter drive --profile --driver=test_driver/review_driver.dart --target=integration_test/review_flow_test.dart --timeout=360 -d <device-id>`。
5. 测试后撤销测试工作区，不要在该工作区打发布包；发布工作区不得含 integration_test 依赖。

脚本覆盖自定义规格、编辑、裁剪重置、文件检查；相机/相册授权、系统导出、离线及 iPad 兼容模式仍需手动验收。
