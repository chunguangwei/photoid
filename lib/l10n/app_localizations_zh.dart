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
}
