// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '智能证件照';

  @override
  String get privacyNote => '全部处理在本机完成，照片不上传服务器';

  @override
  String get specStudentName => '学生报名照（教育ID）';

  @override
  String get bgBlue => '蓝底';

  @override
  String get requirementsTitle => '照片要求';

  @override
  String get reqEduIdName => '照片文件用教育ID命名（jpg 格式）';

  @override
  String get reqFileSize => '文件大小在 10KB–500KB 之间';

  @override
  String get reqBlueBg => '照片底色为蓝底';

  @override
  String get reqBestSize => '最佳尺寸 480×640 像素（宽 380–580，高 540–740）';

  @override
  String get reqRatio => '照片比例（高/宽）在 1.2–1.4 之间';

  @override
  String get reqClothing => '外穿秋季校服外套，里穿白色夏季半袖';

  @override
  String get takePhoto => '拍摄证件照';

  @override
  String get pickFromGallery => '从相册选择';

  @override
  String get cameraNotFound => '未找到可用相机';

  @override
  String cameraInitFailed(String detail) {
    return '相机初始化失败：$detail';
  }

  @override
  String captureFailed(String detail) {
    return '拍摄失败：$detail';
  }

  @override
  String get cameraGuide => '请正对镜头，露出双耳，头部对齐椭圆框';

  @override
  String get stepPreparing => '准备中…';

  @override
  String get stepReading => '正在读取照片…';

  @override
  String get stepSegmenting => '正在智能抠图…';

  @override
  String stepCompositing(String bg) {
    return '正在合成$bg…';
  }

  @override
  String get stepDetectingFace => '正在检测人脸并构图…';

  @override
  String get stepCompressing => '正在压缩导出…';

  @override
  String get errReadPhoto => '无法读取该照片，请换一张 JPG/PNG 图片';

  @override
  String get errNoPerson => '抠图失败，未识别到人物，请使用单人正脸照片';

  @override
  String get errNoFace => '未检测到正脸，请重新拍摄：正对镜头、面部无遮挡';

  @override
  String processFailed(String detail) {
    return '处理失败：$detail';
  }

  @override
  String get retakeOrPick => '重新拍摄/选择';

  @override
  String get retry => '重试';

  @override
  String get chipPreview => '效果图';

  @override
  String get chipOriginal => '原图';

  @override
  String get complianceCheckSave => '合规检测并保存';

  @override
  String get resultTitle => '合规检测';

  @override
  String get checkItemsTitle => '检测项';

  @override
  String get verdictPass => '符合学校要求';

  @override
  String get verdictFail => '存在不合规项';

  @override
  String get eduIdLabel => '教育ID（用作文件名）';

  @override
  String get eduIdHint => '如 2026010101';

  @override
  String get eduIdRequired => '请先输入教育ID作为文件名';

  @override
  String get galleryPermissionDenied => '未授予相册写入权限';

  @override
  String savedToGallery(String fileName) {
    return '已保存到相册：$fileName';
  }

  @override
  String saveFailed(String detail) {
    return '保存失败：$detail';
  }

  @override
  String get saveToGallery => '保存到相册';

  @override
  String get doneRetake => '完成，再拍一张';

  @override
  String get referenceSuffix => '（参考）';

  @override
  String get referenceJoiner => '；';

  @override
  String get checkJpgFormat => '文件格式为 JPG';

  @override
  String checkFileSizeRange(int min, int max) {
    return '文件大小 $min–${max}KB';
  }

  @override
  String get checkDecodable => '图片可解码';

  @override
  String checkPixelSize(int minW, int maxW, int minH, int maxH) {
    return '像素尺寸 宽$minW–$maxW 高$minH–$maxH';
  }

  @override
  String checkBestSize(int w, int h) {
    return '最佳尺寸 $w×$h';
  }

  @override
  String checkRatio(String min, String max) {
    return '比例（高/宽）$min–$max';
  }

  @override
  String get checkBlueBg => '底色为蓝底';

  @override
  String get checkFaceDetected => '检测到正脸';

  @override
  String get checkHeadRatio => '头部占比 45%–85%';

  @override
  String get checkHeadCentered => '头部水平居中';

  @override
  String get checkEyesOpen => '双眼睁开';

  @override
  String get fixFileTooLarge => '文件过大，请重新生成压缩';

  @override
  String get fixFileTooSmall => '文件过小，请提高导出质量';

  @override
  String get fixFileCorrupt => '文件损坏，请重新生成';

  @override
  String get fixSizeOutOfRange => '尺寸越界，请重新生成';

  @override
  String get fixRatioMismatch => '比例不符，请重新裁剪';

  @override
  String get fixNotBlue => '检测到底色不是蓝色，请使用换底功能重新生成';

  @override
  String get fixNoFace => '未检测到人脸，建议使用正脸免冠照片重新拍摄';

  @override
  String get fixHeadRatio => '头部占比不合适，请调整拍摄距离';

  @override
  String get fixNotCentered => '人物未居中，请重新构图';

  @override
  String get fixEyesClosed => '检测到闭眼，请重新拍摄';

  @override
  String deviationPercent(String n) {
    return '偏差 $n';
  }

  @override
  String get updateTitle => '发现新版本';

  @override
  String get updateLater => '稍后';

  @override
  String get updateNow => '立即更新';

  @override
  String get updateDownloadFailed => '下载失败，请稍后重试';

  @override
  String get homeTakePhoto => '拍证件照';

  @override
  String get homeChangeBg => '换底色';

  @override
  String get homeChangeKb => '改KB';

  @override
  String get homeMyAlbum => '我的相册';

  @override
  String get homeCustomSpec => '自定义规格';

  @override
  String get homeHotSpecs => '热门规格';

  @override
  String get homeSearchHint => '搜索场景或规格名';

  @override
  String get homeAllSpecs => '全部规格';

  @override
  String get specPixelSize => '像素大小';

  @override
  String get specDpi => '分辨率';

  @override
  String get specFileSize => '文件大小';

  @override
  String get specBgColor => '背景色';

  @override
  String get specNoLimit => '无要求';

  @override
  String specKbRange(String min, String max) {
    return '$min–${max}KB';
  }

  @override
  String get specUpload => '上传照片';

  @override
  String get specShoot => '直接拍摄';

  @override
  String get bgWhite => '白底';

  @override
  String get bgRed => '红底';

  @override
  String get bgGray => '灰底';

  @override
  String get bgDarkBlue => '深蓝底';

  @override
  String get kbToolTitle => '修改文件大小';

  @override
  String get kbToolPick => '选择照片';

  @override
  String get kbToolTargetKb => '目标大小（KB）';

  @override
  String get kbToolCompress => '开始压缩';

  @override
  String kbToolResult(String kb, String w, String h) {
    return '结果：${kb}KB（$w×$h）';
  }

  @override
  String get kbToolSave => '保存到相册';

  @override
  String get kbToolSaved => '已保存到相册';

  @override
  String get kbToolInvalidKb => '请输入 5–2048 之间的数字';

  @override
  String kbToolFailed(String detail) {
    return '压缩失败：$detail';
  }

  @override
  String get albumTitle => '我的相册';

  @override
  String get albumEmpty => '暂无成片，去拍一张吧';

  @override
  String get albumDelete => '删除';

  @override
  String get albumDeleted => '已删除';

  @override
  String get customTitle => '自定义规格';

  @override
  String get customName => '规格名称';

  @override
  String get customWidth => '宽度（px）';

  @override
  String get customHeight => '高度（px）';

  @override
  String get customMinKb => '最小文件（KB）';

  @override
  String get customMaxKb => '最大文件（KB）';

  @override
  String get customCreate => '创建并使用';

  @override
  String get customInvalid => '请填写合法数值（宽/高 50–2000，宽高比 0.5–2，KB 5–2048，且最小≤最大）';

  @override
  String get editSwitchBg => '切换底色（重新生成）';

  @override
  String get editRegenerating => '正在按新底色重新生成…';

  @override
  String get updateLatest => '已是最新版本';

  @override
  String get updateCheckFailed => '检查失败，请稍后重试';

  @override
  String get updateCheck => '检查更新';

  @override
  String get homeStart => '开始制作';

  @override
  String get bgRecommended => '推荐';

  @override
  String get homeTools => '常用工具';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsAbout => '关于';

  @override
  String settingsVersion(String v) {
    return '版本 $v';
  }

  @override
  String get settingsLicense => '个人使用免费，商业使用需获得作者授权';

  @override
  String get settingsContact => '联系作者：chunguangwee@gmail.com';

  @override
  String get cameraSwitch => '切换摄像头';

  @override
  String get cameraGuidePerson => '请正对镜头，露出双耳，身体对齐人像框';

  @override
  String get tabHome => '首页';

  @override
  String get tabMine => '我的';

  @override
  String get privacySlogan => '照片不出机 · 全部本地处理';

  @override
  String get hotNow => '近期热门';

  @override
  String checkBgColor(String bg) {
    return '底色为$bg';
  }

  @override
  String fixBgMismatch(String bg) {
    return '检测到底色不是$bg，请使用换底功能重新生成';
  }

  @override
  String get updateBgStarted => '已开始后台下载，进度见通知栏；完成后点击通知安装';

  @override
  String get settingsLanguage => '语言';

  @override
  String get langSystem => '跟随系统';

  @override
  String get langZh => '中文';

  @override
  String get langEn => 'English';

  @override
  String get errMlkit => 'AI 处理在当前设备上不可用，请重试或更换照片';

  @override
  String get updateRetryMirror => '用镜像重试';

  @override
  String get updateCopyLink => '复制下载链接';

  @override
  String get updateLinkCopied => '链接已复制，请用浏览器打开下载';

  @override
  String get editZoomHint => '双指缩放、拖动调整构图';

  @override
  String get editCropReset => '还原';

  @override
  String get editTitle => '编辑';

  @override
  String get saveAction => '保存';

  @override
  String get editHd => '高清精修版';

  @override
  String get editNormal => '原图普通版';

  @override
  String get processingTitle => '正在智能调整制作您的照片';

  @override
  String get processingDesc =>
      '我们将使用AI人像识别技术扫描您的照片，并将它调整至最佳状态，这可能需要一些时间，请耐心等待。';

  @override
  String get processingBusy => '制作中…';

  @override
  String cameraSelected(String name) {
    return '已选：$name';
  }

  @override
  String get retake => '重拍';

  @override
  String get confirm => '确认';

  @override
  String get pickGalleryShort => '相册';

  @override
  String get specBgColorPick => '选择背景色';

  @override
  String updateProgress(Object percent, Object received, Object total) {
    return '正在下载 $percent%（$received / $total MB）';
  }

  @override
  String updateProgressUnknown(Object received) {
    return '正在下载…已下载 $received MB';
  }

  @override
  String get updateDone => '下载完成，请在系统弹窗中确认安装';

  @override
  String get updateCancel => '取消下载';

  @override
  String get updateRetry => '重试';

  @override
  String get updateInstall => '完成';
}
