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
  String get bgBlue => 'Blue';

  @override
  String get requirementsTitle => 'Photo requirements';

  @override
  String get reqEduIdName => 'File name is customizable (JPG format)';

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
  String get complianceCheckSave => 'Check photo & save';

  @override
  String get resultTitle => 'Photo checks';

  @override
  String get checkItemsTitle => 'Checks';

  @override
  String get verdictPass => 'File checks passed';

  @override
  String get verdictFail => 'Review failed checks';

  @override
  String get fileNameLabel => 'File name';

  @override
  String get fileNameHint => 'Enter a file name';

  @override
  String get fileNameRequired => 'Enter a file name first';

  @override
  String get fileNameRegenerate => 'Generate a random name';

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
  String get homeCustomSpec => 'Set photo requirements';

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
  String get editSwitchBg => 'Switch background';

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
  String get privacySlogan => 'Photo processing stays on your device';

  @override
  String get hotNow => 'Common specifications';

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

  @override
  String get beautyLabel => 'Beauty';

  @override
  String get clarityLabel => 'Clarity';

  @override
  String get customUnitPx => 'PX';

  @override
  String get customUnitMm => 'mm';

  @override
  String get customDpi => 'DPI';

  @override
  String get customReset => 'Reset';

  @override
  String get customTapToSwitch => 'Tap to switch unit';

  @override
  String get customWidthMm => 'Width (mm)';

  @override
  String get customHeightMm => 'Height (mm)';

  @override
  String splashSkip(Object seconds) {
    return 'Skip ${seconds}s';
  }

  @override
  String get splashAdPlaceholder => 'Ad';

  @override
  String get specPrintSize => 'Print size';

  @override
  String get specFileFormat => 'Format';

  @override
  String get specKbEditable => 'Set size';

  @override
  String get specKbDialogTitle => 'Set file size (KB)';

  @override
  String specKbUnreachable(Object kb) {
    return 'This spec yields ~${kb}KB max; minimum cannot exceed it';
  }

  @override
  String get dialogCancel => 'Cancel';

  @override
  String get homeCustomSaved => 'My Custom Specs';

  @override
  String get customDeleteTitle => 'Delete custom spec';

  @override
  String customDeleteConfirm(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get customDelete => 'Delete';

  @override
  String get privacyPolicyTitle => 'Privacy policy';

  @override
  String get privacyPolicyBody =>
      'Updated November 10, 2026\n\nPhotos and face detection results are processed on your device and are not uploaded for processing. No account is required, and the app has no advertising SDK.\n\nCamera access is used to take photos. Photo library access is used to choose photos and save finished images, only when you use those features.\n\nSaved results are also stored in the app’s private album. Delete them in My Photos. Exported copies must be deleted separately in the system photo library. System photo syncing and backups follow your device settings. Language and custom specifications are stored locally.\n\nGoogle ML Kit performs face detection locally, but can send technical diagnostics and usage metrics to Google, including device/app information, per-installation identifiers, API events, performance and errors. These metrics do not include your input photos or detection results. ONNX Runtime runs the bundled background-removal model locally.\n\nAndroid checks GitHub for app updates and downloads updates on request. iOS updates come from the App Store. Opening the online policy uses your browser.\n\nQuestions: chunguangwee@gmail.com. The online policy provides further details and links to Google’s SDK disclosures.\n\nTemporary export copies are kept in the app cache so receiving apps can read them. Copies older than one day are removed at the next app launch or export.\n\nApplication tasks are stored locally with your notes, requirement references, optional screenshots, source photo and prepared versions. Sources you record are not independently verified. Delete a task to remove its app-owned copies; system originals and files you already exported are kept. Existing-file checks read the selected bytes without changing them. ZIP delivery packages contain photo files and requirement/check reports; only share them with recipients you choose.\n\nRequirement screenshots are read locally using Apple Vision on iOS and bundled ML Kit text recognition on Android. Only selected images are processed; text is not uploaded for recognition. Confirmed excerpts remain in your task and are shared in reports only when you export them. Changed requirements or screenshots require rechecking. Recognition and user confirmation are not institutional certification.\n\nThe optional Enhanced photo finder uses a ~287MB EmbeddingGemma image-semantics model. After your confirmation, model files download from Hugging Face (including its China mirror) or ModelScope into the app\'s private storage and can be deleted anytime; downloads transfer model files only and never upload your photos. When enabled, embeddings are computed on-device for the current photo batch only and used solely to reorder candidates; there is no full-library index and nothing is uploaded. Turning it off or clearing the session releases the data.';

  @override
  String get linkOpenFailed =>
      'Unable to open this link. You can copy it and open it in your browser.';

  @override
  String get photoChecksNote =>
      'These checks cover selected file properties and general framing estimates. They do not certify compliance or guarantee acceptance. Check the receiving organization’s current requirements.';

  @override
  String get checkFailedRetry => 'Checks could not be completed. Please retry.';

  @override
  String get homeNoResults =>
      'No matching specifications. Try another name or create a custom spec.';

  @override
  String get loadFailed => 'Unable to load. Please retry.';

  @override
  String get kbLimitUnreachable =>
      'This KB limit cannot be reached while preserving the image dimensions. Choose a larger limit.';

  @override
  String get homeHeroTitle => 'Prepare your photo\nfor your application.';

  @override
  String get homeEyebrow => 'APPLICATION PHOTO WORKSPACE';

  @override
  String get homeCustomDesc => 'Set dimensions, background and KB limits';

  @override
  String get deliveryExport => 'Export JPEG + report';

  @override
  String get deliveryExportHint =>
      'Export the unchanged JPEG and a JSON check report. Choose Save to Files in the system sheet for file upload. Other destinations may alter images.';

  @override
  String get tasksTitle => 'Application tasks';

  @override
  String get tasksDesc =>
      'Keep requirements, prepare versions and export together';

  @override
  String get taskNew => 'New task';

  @override
  String get taskEmpty => 'Your next application starts here';

  @override
  String get taskEmptyHint =>
      'Save the requirements once, then prepare every photo file you need.';

  @override
  String get taskDetails => 'Task details';

  @override
  String get taskName => 'Task name';

  @override
  String get taskNotes => 'Requirements and notes';

  @override
  String get taskSourceReference => 'Requirements source (link or reference)';

  @override
  String get taskVerifiedDate => 'Date you checked the requirements';

  @override
  String get taskReferenceNote =>
      'Sources are saved as your reference; the app does not verify them.';

  @override
  String get taskSave => 'Save task';

  @override
  String get taskRequiredName => 'Enter a task name';

  @override
  String get taskOriginal => 'One source photo';

  @override
  String get taskChooseSource => 'Choose source photo';

  @override
  String get taskReplaceSource => 'Replace source photo';

  @override
  String get taskReplaceWarning =>
      'Replacing the source resets all completed versions. Your system photo is not deleted.';

  @override
  String get taskEvidence => 'Requirements screenshot';

  @override
  String get taskAttachEvidence => 'Attach screenshot';

  @override
  String get taskViewEvidence => 'View screenshot';

  @override
  String get taskOutputs => 'Files to prepare';

  @override
  String get taskAddOutput => 'Add file requirements';

  @override
  String get taskFilename => 'Output file name';

  @override
  String get taskFilenameHelp =>
      '1–80 letters, numbers, underscores or hyphens. Each name must be unique.';

  @override
  String get taskOutputLimit => 'Up to five files per task';

  @override
  String get taskPrepare => 'Prepare file';

  @override
  String get taskRedo => 'Prepare again';

  @override
  String get taskEditRequirement => 'Edit requirements';

  @override
  String get taskRemoveOutput => 'Remove file requirements';

  @override
  String get taskRequirementsChanged =>
      'Changing requirements resets this completed file.';

  @override
  String get taskExport => 'Export delivery ZIP';

  @override
  String get taskExportHint =>
      'Complete each version to export JPEGs, individual JSON reports and a readable checklist together.';

  @override
  String get taskReady => 'Prepared';

  @override
  String get taskPending => 'To prepare';

  @override
  String get taskBusy => 'Working…';

  @override
  String get taskDelete => 'Delete task';

  @override
  String get taskDeleteConfirm =>
      'Delete this task and its local photo copies? Files already exported and system originals are kept.';

  @override
  String get taskChanged =>
      'The source or requirements changed. Return to the task and prepare this version again.';

  @override
  String get taskSaveOutput => 'Save file to task';

  @override
  String get taskOutputSaved => 'File saved to task';

  @override
  String get taskSaveOutputHint =>
      'Save this version to the task, then prepare the next file or export the delivery package.';

  @override
  String get taskFixedRequirements =>
      'Background and file requirements are fixed by this task. Edit them on the task page.';

  @override
  String get taskNoSource =>
      'Choose one source photo before preparing versions.';

  @override
  String get taskExportFailed =>
      'Unable to export. Check that every output exists and still meets its requirements.';

  @override
  String get taskInvalidName =>
      'Use a unique file name with letters, numbers, underscores or hyphens.';

  @override
  String get taskInvalidFile =>
      'Choose a readable photo up to 30 MB and 24 megapixels.';

  @override
  String get taskActionFailed =>
      'Unable to complete this action. Please retry.';

  @override
  String get taskOutputMismatch =>
      'This file does not meet the task requirements. Adjust it before saving.';

  @override
  String get checkExistingTitle => 'Check an existing photo';

  @override
  String get checkExistingDesc =>
      'Inspect the file you already have, without editing it';

  @override
  String get checkChooseFile => 'Choose photo file';

  @override
  String get checkRequirements => 'Photo requirements';

  @override
  String get checkSetRequirements => 'Set requirements';

  @override
  String get checkRun => 'Check selected file';

  @override
  String get checkNoFile =>
      'Choose a file and enter the requirements to begin.';

  @override
  String get checkByteNote =>
      'Checks read the selected file without changing it. Files preserves the selected bytes; Photos or Camera may supply a converted copy.';

  @override
  String get checkScope =>
      'File properties only. Portrait, background, identity and institutional acceptance are not verified.';

  @override
  String get checkMakeCopy => 'Prepare a new copy';

  @override
  String get checkActual => 'Actual file';

  @override
  String get checkRequired => 'Required';

  @override
  String get checkPassed => 'Selected file properties match';

  @override
  String get checkFailed => 'Some file properties do not match';

  @override
  String get chooseFiles => 'Files';

  @override
  String get choosePhotos => 'Photos';

  @override
  String get chooseCamera => 'Camera';

  @override
  String get taskChooseDate => 'Choose date';

  @override
  String get taskClearDate => 'Clear date';

  @override
  String get taskEdit => 'Edit task';

  @override
  String get taskRemoveConfirm =>
      'Remove this requirement and its prepared local copy?';

  @override
  String get taskFilesCount => 'files prepared';

  @override
  String get taskNoOutputs =>
      'Add the dimensions, KB range and name for each file you need.';

  @override
  String get taskDeliveryTitle => 'Your application, ready to prepare';

  @override
  String get workflowDemo => 'Try a demo task';

  @override
  String get workflowDemoNote =>
      'Fictional requirements · real editing and export';

  @override
  String get workflowOverview => 'Delivery overview';

  @override
  String get workflowRefresh => 'Recheck files';

  @override
  String get workflowRequired => 'Required file properties';

  @override
  String get workflowActual => 'Measured file properties';

  @override
  String get workflowBackground => 'Selected background (not measured)';

  @override
  String get workflowUnprepared => 'Not prepared';

  @override
  String get workflowMissing => 'File missing — prepare again';

  @override
  String get workflowFailed => 'File checks failed — review or prepare again';

  @override
  String get workflowPassed => 'File checks passed';

  @override
  String get workflowExcerpt =>
      'Requirement excerpt (source not independently verified)';

  @override
  String get workflowConfirmed => 'Confirmed by you';

  @override
  String get workflowStale => 'Requirements or source changed — confirm again';

  @override
  String get workflowPrepare => 'Prepare this file';

  @override
  String get workflowEdit => 'Edit requirements';

  @override
  String get workflowExtract => 'Extract requirements from screenshot';

  @override
  String get workflowRecognizing => 'Reading text on your device…';

  @override
  String get workflowRetry => 'Retry recognition';

  @override
  String get workflowOcrFailed =>
      'Text recognition unavailable or failed. Retry or enter requirements manually.';

  @override
  String get workflowNoText =>
      'No readable text found. Try a clearer screenshot or enter requirements manually.';

  @override
  String get workflowOcrNote =>
      'Review every value against the screenshot. Nothing is saved until you confirm. 1 KB = 1024 bytes.';

  @override
  String get workflowOriginalText => 'Recognized text';

  @override
  String get workflowDimensions =>
      'Dimension candidates — confirm width and height';

  @override
  String get workflowSize => 'File-size candidates';

  @override
  String get workflowWidth => 'Width (px)';

  @override
  String get workflowHeight => 'Height (px)';

  @override
  String get workflowMinimum => 'Minimum KB (blank = no minimum)';

  @override
  String get workflowMaximum => 'Maximum KB (blank = no maximum)';

  @override
  String get workflowFilename => 'File name (without .jpg)';

  @override
  String get workflowChooseBackground => 'Select required background';

  @override
  String get workflowJpeg => 'I have checked that JPEG is acceptable';

  @override
  String get workflowConfirmValues =>
      'I have verified width, height and all requirements against the source';

  @override
  String get workflowAdd => 'Confirm and add requirements';

  @override
  String get workflowInvalid =>
      'Complete and confirm valid requirements: 50–2000 px, aspect 0.5–2, KB up to 2048; unique ASCII file name.';

  @override
  String get workflowUnsupported =>
      'Some source constraints cannot be applied automatically. Review the original; only exact pixel dimensions, integer KB limits and JPEG can be prepared here.';

  @override
  String get workflowManual => 'Enter requirements manually';

  @override
  String get workflowReconfirm => 'Confirm against current screenshot';

  @override
  String get workflowReconfirmNote =>
      'Check the current screenshot and these requirements before confirming. This is your confirmation, not institutional certification.';

  @override
  String get workflowRecent => 'Continue recent task';

  @override
  String get workflowInProgress => 'unfinished tasks';

  @override
  String get workflowDetectedBackgrounds =>
      'Detected backgrounds — choose and verify';

  @override
  String get workflowExcerptExport =>
      'Only this short excerpt will be saved and included in your exported reports. Remove unrelated or personal information.';

  @override
  String get finderTitle => 'AI photo finder';

  @override
  String get finderIntro =>
      'Find candidates for this task in a folder or selected files. You choose which photo to use.';

  @override
  String get finderManual => 'Choose a photo manually';

  @override
  String get finderFolder => 'Choose a local folder';

  @override
  String get finderFiles => 'Select multiple photos';

  @override
  String get finderDemo => 'Try sample photos';

  @override
  String get finderRecursive => 'Include subfolders';

  @override
  String get finderScope =>
      'Only the scope you select is read. Face detection runs on your device. No identity recognition or photo uploads.';

  @override
  String get finderProvider =>
      'Use downloaded local files. Android 11+ cannot select the Downloads root; choose a subfolder or multiple files. A file provider may download files you explicitly select. Unverified or undownloaded folder items are skipped.';

  @override
  String get finderLimits =>
      'Limits: 2,000 directory items, 500 photos, 5 folder levels; 30 MB and 24 megapixels per photo. JPEG, PNG and decodable HEIC.';

  @override
  String get finderNeedRequirements =>
      'Add at least one photo requirement in the task before searching. Manual selection is available now.';

  @override
  String get finderDisclaimer =>
      'These are preparation references, not an acceptance or compliance check. Face pose and quality estimates may be wrong. Check clothing, expression and the receiving organization’s requirements yourself.';

  @override
  String get finderStop => 'Stop scan';

  @override
  String get finderClear => 'Clear results and access';

  @override
  String get finderPartial =>
      'Partial scan — completed results are kept. Limits reached or scan stopped.';

  @override
  String get finderSearch => 'Search file name or relative path';

  @override
  String get finderAll => 'All results';

  @override
  String get finderPriority => 'Review first';

  @override
  String get finderManualGroup => 'Manual review';

  @override
  String get finderPixels => 'Check crop resolution';

  @override
  String get finderUnknown => 'Unknown / skipped';

  @override
  String get finderUse => 'Use this photo';

  @override
  String get finderEmpty =>
      'No results yet. Choose a source or try the sample photos.';

  @override
  String get finderNoMatches =>
      'No matching results. Change your filter or search.';

  @override
  String get finderCrops => 'Estimated crops for task outputs';

  @override
  String get finderCropNote =>
      'Approximate crop from face location; not a full-head or official framing assessment. Final framing stays editable.';

  @override
  String get finderStale =>
      'Task requirements or source changed. Exit and search again before using a result.';

  @override
  String get finderFailed =>
      'Could not complete this action. Use a local folder, retry, or choose manually.';

  @override
  String get finderChanged =>
      'The original file changed or is no longer accessible. Scan it again.';

  @override
  String get finderSingle =>
      'Single face; pose estimate within the reference range';

  @override
  String get finderMultiple =>
      'Multiple faces detected — choose and crop manually';

  @override
  String get finderPoseUnknown => 'Face pose could not be estimated';

  @override
  String get finderTurned => 'Estimated head turn or tilt needs review';

  @override
  String get finderSmallFace => 'Face region has few original pixels';

  @override
  String get finderQualityUnknown => 'Face quality could not be measured';

  @override
  String get finderSoft => 'Face region may be soft or blurred';

  @override
  String get finderExposure => 'Face region may be too dark or bright';

  @override
  String get finderNoFace => 'No face detected — cannot determine suitability';

  @override
  String get finderUnsupported => 'Unsupported format';

  @override
  String get finderOversized => 'File exceeds the size or pixel limit';

  @override
  String get finderRemote => 'Not confirmed locally downloaded — skipped';

  @override
  String get finderUnreadable => 'File could not be read or analyzed';

  @override
  String get finderCacheLimit => 'Thumbnail cache limit reached';

  @override
  String get finderDemoNote =>
      'Sample variants use a licensed portrait and artificial edits. Real detection runs on each image; results vary by device.';

  @override
  String get finderFaces => 'detected faces';

  @override
  String get finderItems => 'Directory items checked';

  @override
  String get finderPreview => 'Photo preview (up to 1280 px)';

  @override
  String get finderCropFraming =>
      'Estimated crop may cut the face — adjust framing manually';

  @override
  String get startupContinue => 'Skip';

  @override
  String get finderPickSize => 'Choose photo size';

  @override
  String get finderSizeSearch => 'Search sizes, exams or destinations';

  @override
  String get finderCustomSize => 'Enter dimensions / KB limits';

  @override
  String get finderChooseTarget => 'What size do you need?';

  @override
  String get finderChooseSizeFirst =>
      'Choose a size first, then select your photos.';

  @override
  String get finderBatchPhotos => 'Choose photos from library';

  @override
  String get finderOtherSources => 'Folder or photo files';

  @override
  String get finderSourceHint =>
      'Select many photos in the system picker. Multi-select gestures depend on your system.';

  @override
  String get finderShortPrivacy =>
      'Analyzed on your device. Only your chosen scope is read.';

  @override
  String get finderAdvanced => 'Formats, limits & privacy';

  @override
  String get finderRecommend => 'Recommended';

  @override
  String get finderAllPhotos => 'All photos';

  @override
  String get finderAnalyzing => 'Finding suitable photos…';

  @override
  String get finderNoRecommended =>
      'No clear recommendation. You can still choose a photo manually.';

  @override
  String get finderStartHint =>
      'Pick a size and a batch of photos. We’ll help you find a starting point.';

  @override
  String get finderDetails => 'Why this photo?';

  @override
  String get finderPrepare => 'Prepare with this photo';

  @override
  String get finderSaveRecords => 'Preparation history';

  @override
  String get finderSimpleIntro => 'Choose size → select photos → prepare';

  @override
  String get finderShortCaution =>
      'Suggestions are references. Final acceptance is decided by the receiving organization.';

  @override
  String get finderProviderIos =>
      'Use downloaded local folders. The system may retrieve photos or files you explicitly select from a provider.';

  @override
  String get finderChangePhotos => 'Choose another batch';

  @override
  String get finderPreparingSource => 'Preparing your photo…';

  @override
  String get finderNoPhotos =>
      'No supported photos found here. Try another folder or choose photos from your library.';

  @override
  String get modelTitle => 'Image model';

  @override
  String get modelDesc =>
      'Enhanced photo search needs a semantic model download. Photos are analyzed on this device and never uploaded.';

  @override
  String get modelSizeApprox => 'about 287 MB';

  @override
  String get modelStatusReady => 'Installed';

  @override
  String get modelStatusMissing => 'Not downloaded';

  @override
  String get modelStatusPartial => 'Partially downloaded. You can resume.';

  @override
  String get modelStatusDownloading => 'Downloading';

  @override
  String get modelStatusCorrupt =>
      'Model incomplete. Delete and download again.';

  @override
  String get modelDownload => 'Download model';

  @override
  String get modelPause => 'Pause';

  @override
  String get modelResume => 'Resume download';

  @override
  String get modelDelete => 'Delete model';

  @override
  String get modelDeleteConfirm =>
      'Delete the downloaded model? Enhanced search is unavailable until you download it again.';

  @override
  String get modelOnlyWifi => 'Download over Wi-Fi only';

  @override
  String get modelWifiHint =>
      'Wi-Fi recommended; cellular download may cost data.';

  @override
  String modelProgress(Object received, Object total) {
    return '$received / $total MB';
  }

  @override
  String modelInstalledAt(Object size) {
    return 'Installed ($size MB)';
  }

  @override
  String get enhancedTitle => 'Enhanced';

  @override
  String get enhancedIntro =>
      'Describe in one sentence to rank this batch semantically';

  @override
  String get enhancedEnableTitle => 'Enable Enhanced?';

  @override
  String get enhancedEnableBody =>
      'Needs a one-time ~287 MB semantic model download, then works offline. Photos stay on this device and are never uploaded.';

  @override
  String get enhancedSearchHint => 'e.g. office photo in a business suit';

  @override
  String enhancedSorting(Object done, Object total) {
    return 'Ranking… ($done/$total)';
  }

  @override
  String get enhancedStop => 'Stop ranking';

  @override
  String get enhancedDisclaimer =>
      'Semantic reference ranking; results not guaranteed. ID-photo checks are unaffected.';

  @override
  String get enhancedModelMissing =>
      'Model not installed. Download it in Mine › Image model.';

  @override
  String get modelWifiBlocked =>
      'Not on Wi-Fi; download paused per your setting.';
}
