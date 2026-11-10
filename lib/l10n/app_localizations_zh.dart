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
  String get specStudentName => '学生报名照';

  @override
  String get bgBlue => '蓝底';

  @override
  String get requirementsTitle => '照片要求';

  @override
  String get reqEduIdName => '文件可自定义命名（jpg 格式）';

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
  String get complianceCheckSave => '检测照片并保存';

  @override
  String get resultTitle => '照片检测';

  @override
  String get checkItemsTitle => '检测项';

  @override
  String get verdictPass => '文件项目已通过';

  @override
  String get verdictFail => '请检查未通过项';

  @override
  String get fileNameLabel => '文件名';

  @override
  String get fileNameHint => '请输入文件名';

  @override
  String get fileNameRequired => '请先输入文件名';

  @override
  String get fileNameRegenerate => '随机生成文件名';

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
  String get homeCustomSpec => '填写照片要求';

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
  String get editSwitchBg => '切换底色';

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
  String get privacySlogan => '照片处理在本机完成';

  @override
  String get hotNow => '常用规格';

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

  @override
  String get updateNeedInstallPermission => '需要「安装未知应用」权限：已打开系统设置，请允许后返回点击重试';

  @override
  String get updateRetryInstall => '重试安装';

  @override
  String get beautyLabel => '美颜';

  @override
  String get clarityLabel => '清晰度';

  @override
  String get customUnitPx => 'PX';

  @override
  String get customUnitMm => 'mm';

  @override
  String get customDpi => '分辨率（DPI）';

  @override
  String get customReset => '重置';

  @override
  String get customTapToSwitch => '点击切换单位';

  @override
  String get customWidthMm => '宽度（mm）';

  @override
  String get customHeightMm => '高度（mm）';

  @override
  String splashSkip(Object seconds) {
    return '跳过 ${seconds}s';
  }

  @override
  String get splashAdPlaceholder => '广告位';

  @override
  String get specPrintSize => '冲印尺寸';

  @override
  String get specFileFormat => '文件格式';

  @override
  String get specKbEditable => '可设置大小';

  @override
  String get specKbDialogTitle => '设置文件大小（KB）';

  @override
  String specKbUnreachable(Object kb) {
    return '该规格图片最大约 ${kb}KB，最小值不能超过它';
  }

  @override
  String get dialogCancel => '取消';

  @override
  String get homeCustomSaved => '我的自定义规格';

  @override
  String get customDeleteTitle => '删除自定义规格';

  @override
  String customDeleteConfirm(Object name) {
    return '确定删除「$name」吗？';
  }

  @override
  String get customDelete => '删除';

  @override
  String get privacyPolicyTitle => '隐私政策';

  @override
  String get privacyPolicyBody =>
      '更新日期：2026年11月10日\n\n照片与人脸检测结果在设备本地处理，不为处理而上传。无需账号，不含广告 SDK。\n\n相机权限用于拍照；照片库权限用于选择照片和保存成片，仅在使用相应功能时请求。\n\n保存的成片也保留在 App 私有相册，可在「我的相册」删除。导出的系统照片库副本需单独删除。系统照片同步与备份遵循设备设置。语言与自定义规格保存在本地。\n\nGoogle ML Kit 在本机检测人脸，但可向 Google 发送技术诊断与使用指标，包括设备和应用信息、安装级标识符、API 事件、性能与错误数据。这些指标不包含输入照片或检测结果。ONNX Runtime 在本机运行内置抠图模型。\n\nAndroid 会检查 GitHub 更新，并按用户选择下载；iOS 通过 App Store 更新。打开在线政策会使用系统浏览器。\n\n联系：chunguangwee@gmail.com。在线政策提供详细说明及 Google SDK 数据披露链接。\n\n为便于接收应用读取，临时导出副本会保留在 App 缓存中。超过一天的副本会在下次启动或导出时清理。\n\n报名任务及其中的备注、要求来源、可选截图、原图和各版本成片保存在本机。你记录的来源未经应用独立验证。删除任务会删除应用内副本，系统原图及已导出的文件会保留。已有照片检查只读取所选字节，不改写文件。ZIP 交付包包含照片与要求/检查报告，请仅分享给你选择的接收方。\n\n要求截图文字识别在本机进行：iOS 使用 Apple Vision，Android 使用随包的 ML Kit 文字识别模型。仅处理你选择的截图；识别文字不上传作识别。确认后的要求摘录保存在任务中，并随你主动导出的报告分享。修改要求或更换截图后需重新核对；识别和用户确认均不代表机构认证。\n\n可选的「加强版找照片」使用约 287MB 的 EmbeddingGemma 图像语义模型。模型文件由你确认后从 Hugging Face（含国内镜像）或 ModelScope 下载到 App 私有目录，可随时删除；下载仅传输模型文件，不上传你的照片。开启后仅对你当前选择的照片批次在设备本地生成语义向量并按相似度重排候选，不建立全相册索引、不上传向量或照片；关闭或清除会话即释放。';

  @override
  String get linkOpenFailed => '无法打开链接，可复制后在浏览器中访问。';

  @override
  String get photoChecksNote =>
      '检测仅涵盖部分文件属性与通用构图估计，不是合规认证，也不保证被接收。请核对接收机构的最新要求。';

  @override
  String get checkFailedRetry => '未能完成检测，请重试。';

  @override
  String get homeNoResults => '没有匹配的规格，请换个名称搜索或创建自定义规格。';

  @override
  String get loadFailed => '加载失败，请重试。';

  @override
  String get kbLimitUnreachable => '在保留像素尺寸的情况下无法达到此 KB 上限，请增大目标值。';

  @override
  String get homeHeroTitle => '把照片准备成\n报名需要的文件。';

  @override
  String get homeEyebrow => '报名照片工作台';

  @override
  String get homeCustomDesc => '先设定像素、底色与 KB 范围';

  @override
  String get deliveryExport => '导出 JPEG 与检测报告';

  @override
  String get deliveryExportHint =>
      '导出原始 JPEG 与 JSON 检测报告。报名上传建议在系统面板选择「存储到文件」；其他接收方式可能修改图片。';

  @override
  String get tasksTitle => '报名任务';

  @override
  String get tasksDesc => '保存要求、制作多个版本，一次导出';

  @override
  String get taskNew => '新建任务';

  @override
  String get taskEmpty => '从下一份报名要求开始';

  @override
  String get taskEmptyHint => '保存报名要求，再准备需要的各份照片文件。';

  @override
  String get taskDetails => '任务信息';

  @override
  String get taskName => '任务名称';

  @override
  String get taskNotes => '要求与备注';

  @override
  String get taskSourceReference => '要求来源（链接或出处）';

  @override
  String get taskVerifiedDate => '你核对要求的日期';

  @override
  String get taskReferenceNote => '来源仅供你留存参考，应用不验证其内容。';

  @override
  String get taskSave => '保存任务';

  @override
  String get taskRequiredName => '请填写任务名称';

  @override
  String get taskOriginal => '共用一张原图';

  @override
  String get taskChooseSource => '选择原图';

  @override
  String get taskReplaceSource => '更换原图';

  @override
  String get taskReplaceWarning => '更换原图后，各版本需重新制作。不会删除系统原图。';

  @override
  String get taskEvidence => '要求截图';

  @override
  String get taskAttachEvidence => '附上截图';

  @override
  String get taskViewEvidence => '查看截图';

  @override
  String get taskOutputs => '需要交付的文件';

  @override
  String get taskAddOutput => '添加文件要求';

  @override
  String get taskFilename => '输出文件名';

  @override
  String get taskFilenameHelp => '1–80 位字母、数字、下划线或连字符，每份文件名称须不同。';

  @override
  String get taskOutputLimit => '每个任务最多五份文件';

  @override
  String get taskPrepare => '制作文件';

  @override
  String get taskRedo => '重新制作';

  @override
  String get taskEditRequirement => '编辑要求';

  @override
  String get taskRemoveOutput => '移除文件要求';

  @override
  String get taskRequirementsChanged => '修改要求后，这份文件需重新制作。';

  @override
  String get taskExport => '导出交付包 ZIP';

  @override
  String get taskExportHint => '完成各版本后，一次导出 JPEG、逐份 JSON 报告及可读交付清单。';

  @override
  String get taskReady => '已制作';

  @override
  String get taskPending => '待制作';

  @override
  String get taskBusy => '处理中…';

  @override
  String get taskDelete => '删除任务';

  @override
  String get taskDeleteConfirm => '删除任务及其中保存的照片副本？已导出的文件和系统原图会保留。';

  @override
  String get taskChanged => '原图或要求已改变，请回到任务重新制作这个版本。';

  @override
  String get taskSaveOutput => '将成片存入任务';

  @override
  String get taskOutputSaved => '成片已存入任务';

  @override
  String get taskSaveOutputHint => '把这一版成片存入任务，再继续制作其他版本或导出交付包。';

  @override
  String get taskFixedRequirements => '底色与文件要求以任务为准，可回任务页修改。';

  @override
  String get taskNoSource => '先选一张原图，再制作各版本。';

  @override
  String get taskExportFailed => '无法导出，请检查各份成片是否存在并符合当前要求。';

  @override
  String get taskInvalidName => '请使用不重复的字母、数字、下划线或连字符作为文件名。';

  @override
  String get taskInvalidFile => '请选择可读取、30 MB 及 2400 万像素以内的照片。';

  @override
  String get taskActionFailed => '操作未完成，请重试。';

  @override
  String get taskOutputMismatch => '这份文件未达到任务要求，请调整后再保存。';

  @override
  String get checkExistingTitle => '已有照片能否使用？';

  @override
  String get checkExistingDesc => '检查手里的照片文件，无需重新制作';

  @override
  String get checkChooseFile => '选择照片文件';

  @override
  String get checkRequirements => '照片要求';

  @override
  String get checkSetRequirements => '填写照片要求';

  @override
  String get checkRun => '检查所选文件';

  @override
  String get checkNoFile => '选择文件并填写要求后开始检查。';

  @override
  String get checkByteNote => '检查只读取、不修改所选文件。从“文件”读取所选字节；图库或相机可能由系统提供转换副本。';

  @override
  String get checkScope => '仅检查文件属性，不验证人像、底色、身份或机构是否接收。';

  @override
  String get checkMakeCopy => '制作新的副本';

  @override
  String get checkActual => '实际文件';

  @override
  String get checkRequired => '要求';

  @override
  String get checkPassed => '所检查的文件属性符合要求';

  @override
  String get checkFailed => '部分文件属性未符合要求';

  @override
  String get chooseFiles => '文件';

  @override
  String get choosePhotos => '图库';

  @override
  String get chooseCamera => '相机';

  @override
  String get taskChooseDate => '选择日期';

  @override
  String get taskClearDate => '清除日期';

  @override
  String get taskEdit => '编辑任务';

  @override
  String get taskRemoveConfirm => '移除此要求及对应的本地成片？';

  @override
  String get taskFilesCount => '份已制作';

  @override
  String get taskNoOutputs => '为需要的每份文件添加尺寸、KB 范围和文件名。';

  @override
  String get taskDeliveryTitle => '按报名要求准备文件';

  @override
  String get workflowDemo => '体验示例任务';

  @override
  String get workflowDemoNote => '虚构要求 · 真实制作与导出';

  @override
  String get workflowOverview => '交付总览';

  @override
  String get workflowRefresh => '重新检查文件';

  @override
  String get workflowRequired => '要求的文件属性';

  @override
  String get workflowActual => '实测文件属性';

  @override
  String get workflowBackground => '所选底色（非实测）';

  @override
  String get workflowUnprepared => '未制作';

  @override
  String get workflowMissing => '文件缺失，请重新制作';

  @override
  String get workflowFailed => '文件检查未通过，请核对或重新制作';

  @override
  String get workflowPassed => '文件属性检查通过';

  @override
  String get workflowExcerpt => '要求摘录（来源未经独立验证）';

  @override
  String get workflowConfirmed => '你已核对确认';

  @override
  String get workflowStale => '要求或来源已变更，请重新核对';

  @override
  String get workflowPrepare => '制作这份文件';

  @override
  String get workflowEdit => '修改要求';

  @override
  String get workflowExtract => '从截图提取要求';

  @override
  String get workflowRecognizing => '正在本机识别文字…';

  @override
  String get workflowRetry => '重新识别';

  @override
  String get workflowOcrFailed => '文字识别不可用或失败。可重试或手动填写要求。';

  @override
  String get workflowNoText => '未找到可读取的文字。请换清晰截图或手动填写要求。';

  @override
  String get workflowOcrNote => '请逐项对照截图核对。点击确认前不会保存任何规格。1 KB = 1024 字节。';

  @override
  String get workflowOriginalText => '识别原文';

  @override
  String get workflowDimensions => '尺寸候选，请确认宽与高';

  @override
  String get workflowSize => '文件大小候选';

  @override
  String get workflowWidth => '宽度（像素）';

  @override
  String get workflowHeight => '高度（像素）';

  @override
  String get workflowMinimum => '最小 KB（留空表示无下限）';

  @override
  String get workflowMaximum => '最大 KB（留空表示无上限）';

  @override
  String get workflowFilename => '文件名（不含 .jpg）';

  @override
  String get workflowChooseBackground => '选择要求的底色';

  @override
  String get workflowJpeg => '我已核对可以使用 JPEG 格式';

  @override
  String get workflowConfirmValues => '我已对照来源核对宽高及全部要求';

  @override
  String get workflowAdd => '确认并添加要求';

  @override
  String get workflowInvalid =>
      '请填写并确认有效要求：50–2000 像素，宽高比 0.5–2，KB 不超过 2048；使用不重复的英文字母、数字、下划线或短横线文件名。';

  @override
  String get workflowUnsupported =>
      '部分原文要求无法自动应用。请核对原文；此处仅支持明确的像素尺寸、整数 KB 范围和 JPEG。';

  @override
  String get workflowManual => '手动填写要求';

  @override
  String get workflowReconfirm => '对照当前截图重新确认';

  @override
  String get workflowReconfirmNote => '请对照当前截图核对这份要求，再确认。这是你的核对记录，不是机构认证。';

  @override
  String get workflowRecent => '继续最近任务';

  @override
  String get workflowInProgress => '个待完成任务';

  @override
  String get workflowDetectedBackgrounds => '识别到的底色候选，请选择并核对';

  @override
  String get workflowExcerptExport => '仅下方短摘录会保存到任务并包含在导出报告中，请移除无关内容或个人信息。';

  @override
  String get finderTitle => 'AI 找照片';

  @override
  String get finderIntro => '从指定文件夹或所选文件中，寻找适合当前任务的候选照片，由你决定采用哪张。';

  @override
  String get finderManual => '人工选图 / 拍照';

  @override
  String get finderFolder => '选择本地文件夹';

  @override
  String get finderFiles => '多选照片文件';

  @override
  String get finderDemo => '体验示例照片';

  @override
  String get finderRecursive => '包含子文件夹';

  @override
  String get finderScope => '仅读取你选择的范围，在设备上检测人脸，不识别身份、不上传照片。';

  @override
  String get finderProvider =>
      '请使用已下载的本地文件。Android 11 及以上无法选择“下载”根目录，可选子文件夹或多选文件。文件提供方可能下载你明确选择的文件；文件夹中未下载或无法确认本地状态的项目会跳过。';

  @override
  String get finderLimits =>
      '上限：2000 个目录项目、500 张照片、5 层目录；单张 30 MB、2400 万像素。支持 JPEG、PNG 及可解码的 HEIC。';

  @override
  String get finderNeedRequirements => '先在任务中添加至少一份照片要求，再开始筛选。现在仍可人工选图。';

  @override
  String get finderDisclaimer =>
      '筛选仅供制作参考，不代表合规或获准受理。姿态和画质估计可能有误，请自行核对服装、表情及接收方要求。';

  @override
  String get finderStop => '停止筛选';

  @override
  String get finderClear => '清除结果并结束访问';

  @override
  String get finderPartial => '本次未完整扫描：已保留完成的结果，可能已达上限或被停止。';

  @override
  String get finderSearch => '搜索文件名或相对路径';

  @override
  String get finderAll => '全部结果';

  @override
  String get finderPriority => '优先查看';

  @override
  String get finderManualGroup => '人工判断';

  @override
  String get finderPixels => '裁剪像素不足';

  @override
  String get finderUnknown => '未知 / 已跳过';

  @override
  String get finderUse => '采用此照片';

  @override
  String get finderEmpty => '暂无结果。请选择来源，或体验示例照片。';

  @override
  String get finderNoMatches => '没有匹配的结果，请调整筛选或搜索词。';

  @override
  String get finderCrops => '各项任务的裁剪估计';

  @override
  String get finderCropNote => '根据人脸位置估计裁剪区域，并非完整头部检测或机构构图评估，最终仍可手动调整。';

  @override
  String get finderStale => '任务要求或原图已改变，请退出并重新筛选后再采用。';

  @override
  String get finderFailed => '操作未能完成。请改用本地文件夹、重试或人工选图。';

  @override
  String get finderChanged => '原始文件已改变或不可访问，请重新筛选。';

  @override
  String get finderSingle => '单人脸，姿态估计在参考范围内';

  @override
  String get finderMultiple => '检测到多个人脸，请人工选择及裁剪';

  @override
  String get finderPoseUnknown => '无法估计人脸姿态';

  @override
  String get finderTurned => '估计头部有转向或倾斜，请复核';

  @override
  String get finderSmallFace => '人脸区域的原始像素偏少';

  @override
  String get finderQualityUnknown => '无法测量人脸区域画质';

  @override
  String get finderSoft => '人脸区域可能不够清晰';

  @override
  String get finderExposure => '人脸区域可能过暗或过亮';

  @override
  String get finderNoFace => '未检测到人脸，无法判断是否适合';

  @override
  String get finderUnsupported => '暂不支持此格式';

  @override
  String get finderOversized => '文件大小或像素超过上限';

  @override
  String get finderRemote => '未确认已下载到本地，已跳过';

  @override
  String get finderUnreadable => '无法读取或分析此文件';

  @override
  String get finderCacheLimit => '已达缩略图缓存上限';

  @override
  String get finderDemoNote => '示例使用已授权肖像及人工处理变体，每张均实际运行检测，结果可能因设备而异。';

  @override
  String get finderFaces => '个检测到的人脸';

  @override
  String get finderItems => '已检查目录项目';

  @override
  String get finderPreview => '照片预览（最长边 1280 像素）';

  @override
  String get finderCropFraming => '预估裁剪可能切到脸部，请人工调整构图';

  @override
  String get startupContinue => '进入首页';

  @override
  String get finderPickSize => '选择证件照尺寸';

  @override
  String get finderSizeSearch => '搜索尺寸、考试或用途';

  @override
  String get finderCustomSize => '手动填写尺寸 / KB 要求';

  @override
  String get finderChooseTarget => '需要制作什么尺寸？';

  @override
  String get finderChooseSizeFirst => '先选尺寸，再选照片。';

  @override
  String get finderBatchPhotos => '从相册批量选择';

  @override
  String get finderOtherSources => '文件夹或照片文件';

  @override
  String get finderSourceHint => '可在系统选择器中批量勾选照片，连续选择手势以系统支持为准。';

  @override
  String get finderShortPrivacy => '本机分析，仅读取你选中的范围。';

  @override
  String get finderAdvanced => '支持格式与使用说明';

  @override
  String get finderRecommend => '优先查看';

  @override
  String get finderAllPhotos => '全部照片';

  @override
  String get finderAnalyzing => '正在挑选合适的照片…';

  @override
  String get finderNoRecommended => '暂未找到明显合适的照片，你仍可自行挑选。';

  @override
  String get finderStartHint => '选好尺寸和一批照片，帮你挑出适合制作的原图。';

  @override
  String get finderDetails => '查看判断依据';

  @override
  String get finderPrepare => '用这张制作';

  @override
  String get finderSaveRecords => '制作记录';

  @override
  String get finderSimpleIntro => '选尺寸 → 选一批照片 → 开始制作';

  @override
  String get finderShortCaution => '筛选仅供参考，最终是否接收由接收方决定。';

  @override
  String get finderProviderIos => '请使用已下载的本地文件夹。系统可能下载你从相册或文件提供方明确选择的照片。';

  @override
  String get finderChangePhotos => '重新选择照片';

  @override
  String get finderPreparingSource => '正在准备原图…';

  @override
  String get finderNoPhotos => '这里没有找到支持的照片，试试其他文件夹或从相册选择。';

  @override
  String get modelTitle => '图片处理模型';

  @override
  String get modelDesc => '加强版找照片需要下载语义模型。照片只在本机分析，不会上传。';

  @override
  String get modelSizeApprox => '约 287 MB';

  @override
  String get modelStatusReady => '已安装';

  @override
  String get modelStatusMissing => '未下载';

  @override
  String get modelStatusPartial => '已下载部分，可继续';

  @override
  String get modelStatusDownloading => '下载中';

  @override
  String get modelStatusCorrupt => '模型不完整，请删除后重新下载';

  @override
  String get modelDownload => '下载模型';

  @override
  String get modelPause => '暂停';

  @override
  String get modelResume => '继续下载';

  @override
  String get modelDelete => '删除模型';

  @override
  String get modelDeleteConfirm => '删除已下载的模型？加强版将不可用，直到重新下载。';

  @override
  String get modelOnlyWifi => '仅在 Wi-Fi 下载';

  @override
  String get modelWifiHint => '建议使用 Wi-Fi；流量下载可能产生费用。';

  @override
  String modelProgress(Object received, Object total) {
    return '$received / $total MB';
  }

  @override
  String modelInstalledAt(Object size) {
    return '已安装 $size MB';
  }

  @override
  String get enhancedTitle => '加强版';

  @override
  String get enhancedIntro => '用一句话描述，给本批照片做语义排序';

  @override
  String get enhancedEnableTitle => '开启加强版？';

  @override
  String get enhancedEnableBody => '需要先下载约 287 MB 语义模型，之后离线可用。照片仅在本机处理，不会上传。';

  @override
  String get enhancedSearchHint => '例如：在办公室穿正装的照片';

  @override
  String enhancedSorting(Object done, Object total) {
    return '语义排序中…（$done/$total）';
  }

  @override
  String get enhancedStop => '停止排序';

  @override
  String get enhancedDisclaimer => '语义参考排序，不保证检索结果；证件照检测不受影响。';

  @override
  String get enhancedModelMissing => '模型未安装，先在「我的-图片处理模型」下载';

  @override
  String get modelWifiBlocked => '当前非 Wi-Fi，已按开关暂停下载。';
}
