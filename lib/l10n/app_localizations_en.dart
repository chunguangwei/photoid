// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Smart ID Photo';

  @override
  String get privacyNote =>
      'All processing happens on this device. Photos are never uploaded to a server.';

  @override
  String get specStudentName => 'Student Enrollment Photo';

  @override
  String get bgBlue => 'Blue background';

  @override
  String get requirementsTitle => 'Photo requirements';

  @override
  String get reqEduIdName =>
      'Name the file with your Education ID (JPG format)';

  @override
  String get reqFileSize => 'File size between 10KB and 500KB';

  @override
  String get reqBlueBg => 'Photo background must be blue';

  @override
  String get reqBestSize =>
      'Best size 480×640 px (width 380–580, height 540–740)';

  @override
  String get reqRatio => 'Aspect ratio (height/width) between 1.2 and 1.4';

  @override
  String get reqClothing =>
      'Wear the autumn school uniform jacket over a white short-sleeve shirt';

  @override
  String get takePhoto => 'Take ID photo';

  @override
  String get pickFromGallery => 'Choose from gallery';

  @override
  String get cameraNotFound => 'No available camera found';

  @override
  String cameraInitFailed(String detail) {
    return 'Camera initialization failed: $detail';
  }

  @override
  String captureFailed(String detail) {
    return 'Capture failed: $detail';
  }

  @override
  String get cameraGuide =>
      'Face the camera, show both ears, align your head with the oval frame';

  @override
  String get stepPreparing => 'Preparing…';

  @override
  String get stepReading => 'Reading photo…';

  @override
  String get stepSegmenting => 'Cutting out portrait…';

  @override
  String stepCompositing(String bg) {
    return 'Compositing $bg…';
  }

  @override
  String get stepDetectingFace => 'Detecting face and composing…';

  @override
  String get stepCompressing => 'Compressing and exporting…';

  @override
  String get errReadPhoto =>
      'Cannot read this photo. Please choose another JPG/PNG image.';

  @override
  String get errNoPerson =>
      'Cutout failed: no person detected. Please use a single-person front-facing photo.';

  @override
  String get errNoFace =>
      'No front-facing face detected. Please retake: face the camera, keep your face unobstructed.';

  @override
  String processFailed(String detail) {
    return 'Processing failed: $detail';
  }

  @override
  String get retakeOrPick => 'Retake / choose again';

  @override
  String get retry => 'Retry';

  @override
  String get chipPreview => 'Result';

  @override
  String get chipOriginal => 'Original';

  @override
  String get complianceCheckSave => 'Run compliance check & save';

  @override
  String get resultTitle => 'Compliance check';

  @override
  String get checkItemsTitle => 'Checks';

  @override
  String get verdictPass => 'Meets school requirements';

  @override
  String get verdictFail => 'Some checks failed';

  @override
  String get eduIdLabel => 'Education ID (used as file name)';

  @override
  String get eduIdHint => 'e.g. 2026010101';

  @override
  String get eduIdRequired => 'Enter your Education ID as the file name first';

  @override
  String get galleryPermissionDenied =>
      'Photo library write permission not granted';

  @override
  String savedToGallery(String fileName) {
    return 'Saved to gallery: $fileName';
  }

  @override
  String saveFailed(String detail) {
    return 'Save failed: $detail';
  }

  @override
  String get saveToGallery => 'Save to gallery';

  @override
  String get doneRetake => 'Done, take another';

  @override
  String get referenceSuffix => ' (reference)';

  @override
  String get referenceJoiner => '; ';

  @override
  String get checkJpgFormat => 'File format is JPG';

  @override
  String checkFileSizeRange(int min, int max) {
    return 'File size $min–${max}KB';
  }

  @override
  String get checkDecodable => 'Image decodable';

  @override
  String checkPixelSize(int minW, int maxW, int minH, int maxH) {
    return 'Pixel size width $minW–$maxW, height $minH–$maxH';
  }

  @override
  String checkBestSize(int w, int h) {
    return 'Best size $w×$h';
  }

  @override
  String checkRatio(String min, String max) {
    return 'Ratio (height/width) $min–$max';
  }

  @override
  String get checkBlueBg => 'Background is blue';

  @override
  String get checkFaceDetected => 'Front-facing face detected';

  @override
  String get checkHeadRatio => 'Head ratio 45%–85%';

  @override
  String get checkHeadCentered => 'Head horizontally centered';

  @override
  String get checkEyesOpen => 'Eyes open';

  @override
  String get fixFileTooLarge =>
      'File too large. Regenerate with stronger compression.';

  @override
  String get fixFileTooSmall => 'File too small. Export with higher quality.';

  @override
  String get fixFileCorrupt => 'File corrupted. Please regenerate.';

  @override
  String get fixSizeOutOfRange => 'Size out of range. Please regenerate.';

  @override
  String get fixRatioMismatch => 'Ratio mismatch. Please re-crop.';

  @override
  String get fixNotBlue =>
      'Background is not blue. Use background replacement to regenerate.';

  @override
  String get fixNoFace =>
      'No face detected. Use a front-facing hatless photo and retake.';

  @override
  String get fixHeadRatio =>
      'Head ratio out of range. Adjust the shooting distance.';

  @override
  String get fixNotCentered => 'Person not centered. Recompose the shot.';

  @override
  String get fixEyesClosed => 'Eyes closed detected. Please retake.';

  @override
  String deviationPercent(String n) {
    return 'Deviation $n';
  }

  @override
  String get updateTitle => 'New version available';

  @override
  String get updateLater => 'Later';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateDownloadFailed => 'Download failed. Please try again later.';

  @override
  String get homeTakePhoto => 'ID Photo';

  @override
  String get homeChangeBg => 'Background';

  @override
  String get homeChangeKb => 'Resize KB';

  @override
  String get homeMyAlbum => 'My Photos';

  @override
  String get homeCustomSpec => 'Custom';

  @override
  String get homeHotSpecs => 'Popular specs';

  @override
  String get homeSearchHint => 'Search scenes or specs';

  @override
  String get homeAllSpecs => 'All specs';

  @override
  String get specPixelSize => 'Pixels';

  @override
  String get specDpi => 'DPI';

  @override
  String get specFileSize => 'File size';

  @override
  String get specBgColor => 'Background';

  @override
  String get specNoLimit => 'No requirement';

  @override
  String specKbRange(String min, String max) {
    return '$min–${max}KB';
  }

  @override
  String get specUpload => 'Upload photo';

  @override
  String get specShoot => 'Take photo';

  @override
  String get bgWhite => 'White';

  @override
  String get bgRed => 'Red';

  @override
  String get bgGray => 'Gray';

  @override
  String get bgDarkBlue => 'Dark blue';

  @override
  String get kbToolTitle => 'Resize file (KB)';

  @override
  String get kbToolPick => 'Choose photo';

  @override
  String get kbToolTargetKb => 'Target size (KB)';

  @override
  String get kbToolCompress => 'Compress';

  @override
  String kbToolResult(String kb, String w, String h) {
    return 'Result: ${kb}KB ($w×$h)';
  }

  @override
  String get kbToolSave => 'Save to gallery';

  @override
  String get kbToolSaved => 'Saved to gallery';

  @override
  String get kbToolInvalidKb => 'Enter a number between 5 and 2048';

  @override
  String kbToolFailed(String detail) {
    return 'Compression failed: $detail';
  }

  @override
  String get albumTitle => 'My Photos';

  @override
  String get albumEmpty => 'No photos yet. Take one!';

  @override
  String get albumDelete => 'Delete';

  @override
  String get albumDeleted => 'Deleted';

  @override
  String get customTitle => 'Custom spec';

  @override
  String get customName => 'Spec name';

  @override
  String get customWidth => 'Width (px)';

  @override
  String get customHeight => 'Height (px)';

  @override
  String get customMinKb => 'Min file (KB)';

  @override
  String get customMaxKb => 'Max file (KB)';

  @override
  String get customCreate => 'Create & use';

  @override
  String get customInvalid =>
      'Enter valid values (W/H 50–2000, aspect 0.5–2, KB 5–2048, min ≤ max)';

  @override
  String get editSwitchBg => 'Switch background (regenerate)';

  @override
  String get editRegenerating => 'Regenerating with new background…';

  @override
  String get updateLatest => 'You\'re up to date';

  @override
  String get updateCheckFailed => 'Check failed. Try again later.';

  @override
  String get updateCheck => 'Check for updates';

  @override
  String get homeStart => 'Start';

  @override
  String get bgRecommended => 'Recommended';

  @override
  String get homeTools => 'Tools';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAbout => 'About';

  @override
  String settingsVersion(String v) {
    return 'Version $v';
  }

  @override
  String get settingsLicense =>
      'Free for personal use. Commercial use requires the author\'s permission.';

  @override
  String get settingsContact => 'Contact: chunguangwee@gmail.com';

  @override
  String get cameraSwitch => 'Switch camera';

  @override
  String get cameraGuidePerson =>
      'Face the camera, show both ears, align with the outline';

  @override
  String get tabHome => 'Home';

  @override
  String get tabMine => 'Mine';

  @override
  String get privacySlogan => 'Photos never leave your device';

  @override
  String get hotNow => 'Trending';

  @override
  String checkBgColor(String bg) {
    return 'Background is $bg';
  }

  @override
  String fixBgMismatch(String bg) {
    return 'Background is not $bg. Regenerate with background replacement.';
  }

  @override
  String get updateBgStarted =>
      'Downloading in background — progress in the notification bar. Tap it to install when done.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get langSystem => 'System';

  @override
  String get langZh => '中文';

  @override
  String get langEn => 'English';

  @override
  String get errMlkit =>
      'AI processing is unavailable on this device. Retry or use another photo.';

  @override
  String get updateRetryMirror => 'Retry via mirror';

  @override
  String get updateCopyLink => 'Copy download link';

  @override
  String get updateLinkCopied =>
      'Link copied. Open it in your browser to download.';

  @override
  String get editZoomHint => 'Pinch & drag to adjust';

  @override
  String get editCropReset => 'Reset';

  @override
  String get editTitle => 'Edit';

  @override
  String get saveAction => 'Save';

  @override
  String get editHd => 'HD Enhanced';

  @override
  String get editNormal => 'Standard';

  @override
  String get processingTitle => 'Creating your photo with AI';

  @override
  String get processingDesc =>
      'We use AI portrait recognition to scan and optimize your photo. This may take a moment, please wait.';

  @override
  String get processingBusy => 'Processing…';

  @override
  String cameraSelected(String name) {
    return 'Selected: $name';
  }

  @override
  String get retake => 'Retake';

  @override
  String get confirm => 'Confirm';

  @override
  String get pickGalleryShort => 'Gallery';

  @override
  String get specBgColorPick => 'Background';

  @override
  String updateProgress(Object percent, Object received, Object total) {
    return 'Downloading $percent% ($received / $total MB)';
  }

  @override
  String updateProgressUnknown(Object received) {
    return 'Downloading… $received MB';
  }

  @override
  String get updateDone =>
      'Download complete. Confirm in the system installer.';

  @override
  String get updateCancel => 'Cancel';

  @override
  String get updateRetry => 'Retry';

  @override
  String get updateInstall => 'Done';

  @override
  String get updateNeedInstallPermission =>
      'Install permission required: system settings opened. Allow it, then come back and retry.';

  @override
  String get updateRetryInstall => 'Retry install';
}
