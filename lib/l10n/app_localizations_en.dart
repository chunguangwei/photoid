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
  String get specStudentName => 'Student application photo (Edu ID)';

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
}
