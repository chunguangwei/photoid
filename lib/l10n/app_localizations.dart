import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart ID Photo'**
  String get appTitle;

  /// No description provided for @privacyNote.
  ///
  /// In en, this message translates to:
  /// **'All processing happens on this device. Photos are never uploaded to a server.'**
  String get privacyNote;

  /// No description provided for @specStudentName.
  ///
  /// In en, this message translates to:
  /// **'Student Enrollment Photo'**
  String get specStudentName;

  /// No description provided for @bgBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get bgBlue;

  /// No description provided for @requirementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo requirements'**
  String get requirementsTitle;

  /// No description provided for @reqEduIdName.
  ///
  /// In en, this message translates to:
  /// **'File name is customizable (JPG format)'**
  String get reqEduIdName;

  /// No description provided for @reqFileSize.
  ///
  /// In en, this message translates to:
  /// **'File size between 10KB and 500KB'**
  String get reqFileSize;

  /// No description provided for @reqBlueBg.
  ///
  /// In en, this message translates to:
  /// **'Photo background must be blue'**
  String get reqBlueBg;

  /// No description provided for @reqBestSize.
  ///
  /// In en, this message translates to:
  /// **'Best size 480×640 px (width 380–580, height 540–740)'**
  String get reqBestSize;

  /// No description provided for @reqRatio.
  ///
  /// In en, this message translates to:
  /// **'Aspect ratio (height/width) between 1.2 and 1.4'**
  String get reqRatio;

  /// No description provided for @reqClothing.
  ///
  /// In en, this message translates to:
  /// **'Wear the autumn school uniform jacket over a white short-sleeve shirt'**
  String get reqClothing;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take ID photo'**
  String get takePhoto;

  /// No description provided for @pickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get pickFromGallery;

  /// No description provided for @cameraNotFound.
  ///
  /// In en, this message translates to:
  /// **'No available camera found'**
  String get cameraNotFound;

  /// No description provided for @cameraInitFailed.
  ///
  /// In en, this message translates to:
  /// **'Camera initialization failed: {detail}'**
  String cameraInitFailed(String detail);

  /// No description provided for @captureFailed.
  ///
  /// In en, this message translates to:
  /// **'Capture failed: {detail}'**
  String captureFailed(String detail);

  /// No description provided for @cameraGuide.
  ///
  /// In en, this message translates to:
  /// **'Face the camera, show both ears, align your head with the oval frame'**
  String get cameraGuide;

  /// No description provided for @stepPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get stepPreparing;

  /// No description provided for @stepReading.
  ///
  /// In en, this message translates to:
  /// **'Reading photo…'**
  String get stepReading;

  /// No description provided for @stepSegmenting.
  ///
  /// In en, this message translates to:
  /// **'Cutting out portrait…'**
  String get stepSegmenting;

  /// No description provided for @stepCompositing.
  ///
  /// In en, this message translates to:
  /// **'Compositing {bg}…'**
  String stepCompositing(String bg);

  /// No description provided for @stepDetectingFace.
  ///
  /// In en, this message translates to:
  /// **'Detecting face and composing…'**
  String get stepDetectingFace;

  /// No description provided for @stepCompressing.
  ///
  /// In en, this message translates to:
  /// **'Compressing and exporting…'**
  String get stepCompressing;

  /// No description provided for @errReadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Cannot read this photo. Please choose another JPG/PNG image.'**
  String get errReadPhoto;

  /// No description provided for @errNoPerson.
  ///
  /// In en, this message translates to:
  /// **'Cutout failed: no person detected. Please use a single-person front-facing photo.'**
  String get errNoPerson;

  /// No description provided for @errNoFace.
  ///
  /// In en, this message translates to:
  /// **'No front-facing face detected. Please retake: face the camera, keep your face unobstructed.'**
  String get errNoFace;

  /// No description provided for @processFailed.
  ///
  /// In en, this message translates to:
  /// **'Processing failed: {detail}'**
  String processFailed(String detail);

  /// No description provided for @retakeOrPick.
  ///
  /// In en, this message translates to:
  /// **'Retake / choose again'**
  String get retakeOrPick;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @chipPreview.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get chipPreview;

  /// No description provided for @chipOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get chipOriginal;

  /// No description provided for @complianceCheckSave.
  ///
  /// In en, this message translates to:
  /// **'Check photo & save'**
  String get complianceCheckSave;

  /// No description provided for @resultTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo checks'**
  String get resultTitle;

  /// No description provided for @checkItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Checks'**
  String get checkItemsTitle;

  /// No description provided for @verdictPass.
  ///
  /// In en, this message translates to:
  /// **'File checks passed'**
  String get verdictPass;

  /// No description provided for @verdictFail.
  ///
  /// In en, this message translates to:
  /// **'Review failed checks'**
  String get verdictFail;

  /// No description provided for @fileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get fileNameLabel;

  /// No description provided for @fileNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a file name'**
  String get fileNameHint;

  /// No description provided for @fileNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a file name first'**
  String get fileNameRequired;

  /// No description provided for @fileNameRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate a random name'**
  String get fileNameRegenerate;

  /// No description provided for @galleryPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Photo library write permission not granted'**
  String get galleryPermissionDenied;

  /// No description provided for @savedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery: {fileName}'**
  String savedToGallery(String fileName);

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {detail}'**
  String saveFailed(String detail);

  /// No description provided for @saveToGallery.
  ///
  /// In en, this message translates to:
  /// **'Save to gallery'**
  String get saveToGallery;

  /// No description provided for @doneRetake.
  ///
  /// In en, this message translates to:
  /// **'Done, take another'**
  String get doneRetake;

  /// No description provided for @referenceSuffix.
  ///
  /// In en, this message translates to:
  /// **' (reference)'**
  String get referenceSuffix;

  /// No description provided for @referenceJoiner.
  ///
  /// In en, this message translates to:
  /// **'; '**
  String get referenceJoiner;

  /// No description provided for @checkJpgFormat.
  ///
  /// In en, this message translates to:
  /// **'File format is JPG'**
  String get checkJpgFormat;

  /// No description provided for @checkFileSizeRange.
  ///
  /// In en, this message translates to:
  /// **'File size {min}–{max}KB'**
  String checkFileSizeRange(int min, int max);

  /// No description provided for @checkDecodable.
  ///
  /// In en, this message translates to:
  /// **'Image decodable'**
  String get checkDecodable;

  /// No description provided for @checkPixelSize.
  ///
  /// In en, this message translates to:
  /// **'Pixel size width {minW}–{maxW}, height {minH}–{maxH}'**
  String checkPixelSize(int minW, int maxW, int minH, int maxH);

  /// No description provided for @checkBestSize.
  ///
  /// In en, this message translates to:
  /// **'Best size {w}×{h}'**
  String checkBestSize(int w, int h);

  /// No description provided for @checkRatio.
  ///
  /// In en, this message translates to:
  /// **'Ratio (height/width) {min}–{max}'**
  String checkRatio(String min, String max);

  /// No description provided for @checkBlueBg.
  ///
  /// In en, this message translates to:
  /// **'Background is blue'**
  String get checkBlueBg;

  /// No description provided for @checkFaceDetected.
  ///
  /// In en, this message translates to:
  /// **'Front-facing face detected'**
  String get checkFaceDetected;

  /// No description provided for @checkHeadRatio.
  ///
  /// In en, this message translates to:
  /// **'Head ratio 45%–85%'**
  String get checkHeadRatio;

  /// No description provided for @checkHeadCentered.
  ///
  /// In en, this message translates to:
  /// **'Head horizontally centered'**
  String get checkHeadCentered;

  /// No description provided for @checkEyesOpen.
  ///
  /// In en, this message translates to:
  /// **'Eyes open'**
  String get checkEyesOpen;

  /// No description provided for @fixFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File too large. Regenerate with stronger compression.'**
  String get fixFileTooLarge;

  /// No description provided for @fixFileTooSmall.
  ///
  /// In en, this message translates to:
  /// **'File too small. Export with higher quality.'**
  String get fixFileTooSmall;

  /// No description provided for @fixFileCorrupt.
  ///
  /// In en, this message translates to:
  /// **'File corrupted. Please regenerate.'**
  String get fixFileCorrupt;

  /// No description provided for @fixSizeOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Size out of range. Please regenerate.'**
  String get fixSizeOutOfRange;

  /// No description provided for @fixRatioMismatch.
  ///
  /// In en, this message translates to:
  /// **'Ratio mismatch. Please re-crop.'**
  String get fixRatioMismatch;

  /// No description provided for @fixNotBlue.
  ///
  /// In en, this message translates to:
  /// **'Background is not blue. Use background replacement to regenerate.'**
  String get fixNotBlue;

  /// No description provided for @fixNoFace.
  ///
  /// In en, this message translates to:
  /// **'No face detected. Use a front-facing hatless photo and retake.'**
  String get fixNoFace;

  /// No description provided for @fixHeadRatio.
  ///
  /// In en, this message translates to:
  /// **'Head ratio out of range. Adjust the shooting distance.'**
  String get fixHeadRatio;

  /// No description provided for @fixNotCentered.
  ///
  /// In en, this message translates to:
  /// **'Person not centered. Recompose the shot.'**
  String get fixNotCentered;

  /// No description provided for @fixEyesClosed.
  ///
  /// In en, this message translates to:
  /// **'Eyes closed detected. Please retake.'**
  String get fixEyesClosed;

  /// No description provided for @deviationPercent.
  ///
  /// In en, this message translates to:
  /// **'Deviation {n}'**
  String deviationPercent(String n);

  /// No description provided for @updateTitle.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get updateTitle;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @updateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Please try again later.'**
  String get updateDownloadFailed;

  /// No description provided for @homeTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'ID Photo'**
  String get homeTakePhoto;

  /// No description provided for @homeChangeBg.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get homeChangeBg;

  /// No description provided for @homeChangeKb.
  ///
  /// In en, this message translates to:
  /// **'Resize KB'**
  String get homeChangeKb;

  /// No description provided for @homeMyAlbum.
  ///
  /// In en, this message translates to:
  /// **'My Photos'**
  String get homeMyAlbum;

  /// No description provided for @homeCustomSpec.
  ///
  /// In en, this message translates to:
  /// **'Set photo requirements'**
  String get homeCustomSpec;

  /// No description provided for @homeHotSpecs.
  ///
  /// In en, this message translates to:
  /// **'Popular specs'**
  String get homeHotSpecs;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search scenes or specs'**
  String get homeSearchHint;

  /// No description provided for @homeAllSpecs.
  ///
  /// In en, this message translates to:
  /// **'All specs'**
  String get homeAllSpecs;

  /// No description provided for @specPixelSize.
  ///
  /// In en, this message translates to:
  /// **'Pixels'**
  String get specPixelSize;

  /// No description provided for @specDpi.
  ///
  /// In en, this message translates to:
  /// **'DPI'**
  String get specDpi;

  /// No description provided for @specFileSize.
  ///
  /// In en, this message translates to:
  /// **'File size'**
  String get specFileSize;

  /// No description provided for @specBgColor.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get specBgColor;

  /// No description provided for @specNoLimit.
  ///
  /// In en, this message translates to:
  /// **'No requirement'**
  String get specNoLimit;

  /// No description provided for @specKbRange.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max}KB'**
  String specKbRange(String min, String max);

  /// No description provided for @specUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload photo'**
  String get specUpload;

  /// No description provided for @specShoot.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get specShoot;

  /// No description provided for @bgWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get bgWhite;

  /// No description provided for @bgRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get bgRed;

  /// No description provided for @bgGray.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get bgGray;

  /// No description provided for @bgDarkBlue.
  ///
  /// In en, this message translates to:
  /// **'Dark blue'**
  String get bgDarkBlue;

  /// No description provided for @kbToolTitle.
  ///
  /// In en, this message translates to:
  /// **'Resize file (KB)'**
  String get kbToolTitle;

  /// No description provided for @kbToolPick.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get kbToolPick;

  /// No description provided for @kbToolTargetKb.
  ///
  /// In en, this message translates to:
  /// **'Target size (KB)'**
  String get kbToolTargetKb;

  /// No description provided for @kbToolCompress.
  ///
  /// In en, this message translates to:
  /// **'Compress'**
  String get kbToolCompress;

  /// No description provided for @kbToolResult.
  ///
  /// In en, this message translates to:
  /// **'Result: {kb}KB ({w}×{h})'**
  String kbToolResult(String kb, String w, String h);

  /// No description provided for @kbToolSave.
  ///
  /// In en, this message translates to:
  /// **'Save to gallery'**
  String get kbToolSave;

  /// No description provided for @kbToolSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery'**
  String get kbToolSaved;

  /// No description provided for @kbToolInvalidKb.
  ///
  /// In en, this message translates to:
  /// **'Enter a number between 5 and 2048'**
  String get kbToolInvalidKb;

  /// No description provided for @kbToolFailed.
  ///
  /// In en, this message translates to:
  /// **'Compression failed: {detail}'**
  String kbToolFailed(String detail);

  /// No description provided for @albumTitle.
  ///
  /// In en, this message translates to:
  /// **'My Photos'**
  String get albumTitle;

  /// No description provided for @albumEmpty.
  ///
  /// In en, this message translates to:
  /// **'No photos yet. Take one!'**
  String get albumEmpty;

  /// No description provided for @albumDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get albumDelete;

  /// No description provided for @albumDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get albumDeleted;

  /// No description provided for @customTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom spec'**
  String get customTitle;

  /// No description provided for @customName.
  ///
  /// In en, this message translates to:
  /// **'Spec name'**
  String get customName;

  /// No description provided for @customWidth.
  ///
  /// In en, this message translates to:
  /// **'Width (px)'**
  String get customWidth;

  /// No description provided for @customHeight.
  ///
  /// In en, this message translates to:
  /// **'Height (px)'**
  String get customHeight;

  /// No description provided for @customMinKb.
  ///
  /// In en, this message translates to:
  /// **'Min file (KB)'**
  String get customMinKb;

  /// No description provided for @customMaxKb.
  ///
  /// In en, this message translates to:
  /// **'Max file (KB)'**
  String get customMaxKb;

  /// No description provided for @customCreate.
  ///
  /// In en, this message translates to:
  /// **'Create & use'**
  String get customCreate;

  /// No description provided for @customInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter valid values (W/H 50–2000, aspect 0.5–2, KB 5–2048, min ≤ max)'**
  String get customInvalid;

  /// No description provided for @editSwitchBg.
  ///
  /// In en, this message translates to:
  /// **'Switch background'**
  String get editSwitchBg;

  /// No description provided for @editRegenerating.
  ///
  /// In en, this message translates to:
  /// **'Regenerating with new background…'**
  String get editRegenerating;

  /// No description provided for @updateLatest.
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date'**
  String get updateLatest;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Check failed. Try again later.'**
  String get updateCheckFailed;

  /// No description provided for @updateCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get updateCheck;

  /// No description provided for @homeStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get homeStart;

  /// No description provided for @bgRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get bgRecommended;

  /// No description provided for @homeTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get homeTools;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {v}'**
  String settingsVersion(String v);

  /// No description provided for @settingsLicense.
  ///
  /// In en, this message translates to:
  /// **'Free for personal use. Commercial use requires the author\'s permission.'**
  String get settingsLicense;

  /// No description provided for @settingsContact.
  ///
  /// In en, this message translates to:
  /// **'Contact: chunguangwee@gmail.com'**
  String get settingsContact;

  /// No description provided for @cameraSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch camera'**
  String get cameraSwitch;

  /// No description provided for @cameraGuidePerson.
  ///
  /// In en, this message translates to:
  /// **'Face the camera, show both ears, align with the outline'**
  String get cameraGuidePerson;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get tabMine;

  /// No description provided for @privacySlogan.
  ///
  /// In en, this message translates to:
  /// **'Photo processing stays on your device'**
  String get privacySlogan;

  /// No description provided for @hotNow.
  ///
  /// In en, this message translates to:
  /// **'Common specifications'**
  String get hotNow;

  /// No description provided for @checkBgColor.
  ///
  /// In en, this message translates to:
  /// **'Background is {bg}'**
  String checkBgColor(String bg);

  /// No description provided for @fixBgMismatch.
  ///
  /// In en, this message translates to:
  /// **'Background is not {bg}. Regenerate with background replacement.'**
  String fixBgMismatch(String bg);

  /// No description provided for @updateBgStarted.
  ///
  /// In en, this message translates to:
  /// **'Downloading in background — progress in the notification bar. Tap it to install when done.'**
  String get updateBgStarted;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @langSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get langSystem;

  /// No description provided for @langZh.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get langZh;

  /// No description provided for @langEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEn;

  /// No description provided for @errMlkit.
  ///
  /// In en, this message translates to:
  /// **'AI processing is unavailable on this device. Retry or use another photo.'**
  String get errMlkit;

  /// No description provided for @updateRetryMirror.
  ///
  /// In en, this message translates to:
  /// **'Retry via mirror'**
  String get updateRetryMirror;

  /// No description provided for @updateCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy download link'**
  String get updateCopyLink;

  /// No description provided for @updateLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied. Open it in your browser to download.'**
  String get updateLinkCopied;

  /// No description provided for @editZoomHint.
  ///
  /// In en, this message translates to:
  /// **'Pinch & drag to adjust'**
  String get editZoomHint;

  /// No description provided for @editCropReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get editCropReset;

  /// No description provided for @editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editTitle;

  /// No description provided for @saveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// No description provided for @processingTitle.
  ///
  /// In en, this message translates to:
  /// **'Creating your photo with AI'**
  String get processingTitle;

  /// No description provided for @processingDesc.
  ///
  /// In en, this message translates to:
  /// **'We use AI portrait recognition to scan and optimize your photo. This may take a moment, please wait.'**
  String get processingDesc;

  /// No description provided for @processingBusy.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get processingBusy;

  /// No description provided for @cameraSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected: {name}'**
  String cameraSelected(String name);

  /// No description provided for @retake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retake;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @pickGalleryShort.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get pickGalleryShort;

  /// No description provided for @specBgColorPick.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get specBgColorPick;

  /// No description provided for @updateProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}% ({received} / {total} MB)'**
  String updateProgress(Object percent, Object received, Object total);

  /// No description provided for @updateProgressUnknown.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {received} MB'**
  String updateProgressUnknown(Object received);

  /// No description provided for @updateDone.
  ///
  /// In en, this message translates to:
  /// **'Download complete. Confirm in the system installer.'**
  String get updateDone;

  /// No description provided for @updateCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get updateCancel;

  /// No description provided for @updateRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get updateRetry;

  /// No description provided for @updateInstall.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get updateInstall;

  /// No description provided for @updateNeedInstallPermission.
  ///
  /// In en, this message translates to:
  /// **'Install permission required: system settings opened. Allow it, then come back and retry.'**
  String get updateNeedInstallPermission;

  /// No description provided for @updateRetryInstall.
  ///
  /// In en, this message translates to:
  /// **'Retry install'**
  String get updateRetryInstall;

  /// No description provided for @beautyLabel.
  ///
  /// In en, this message translates to:
  /// **'Beauty'**
  String get beautyLabel;

  /// No description provided for @clarityLabel.
  ///
  /// In en, this message translates to:
  /// **'Clarity'**
  String get clarityLabel;

  /// No description provided for @customUnitPx.
  ///
  /// In en, this message translates to:
  /// **'PX'**
  String get customUnitPx;

  /// No description provided for @customUnitMm.
  ///
  /// In en, this message translates to:
  /// **'mm'**
  String get customUnitMm;

  /// No description provided for @customDpi.
  ///
  /// In en, this message translates to:
  /// **'DPI'**
  String get customDpi;

  /// No description provided for @customReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get customReset;

  /// No description provided for @customTapToSwitch.
  ///
  /// In en, this message translates to:
  /// **'Tap to switch unit'**
  String get customTapToSwitch;

  /// No description provided for @customWidthMm.
  ///
  /// In en, this message translates to:
  /// **'Width (mm)'**
  String get customWidthMm;

  /// No description provided for @customHeightMm.
  ///
  /// In en, this message translates to:
  /// **'Height (mm)'**
  String get customHeightMm;

  /// No description provided for @splashSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip {seconds}s'**
  String splashSkip(Object seconds);

  /// No description provided for @splashAdPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Ad'**
  String get splashAdPlaceholder;

  /// No description provided for @specPrintSize.
  ///
  /// In en, this message translates to:
  /// **'Print size'**
  String get specPrintSize;

  /// No description provided for @specFileFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get specFileFormat;

  /// No description provided for @specKbEditable.
  ///
  /// In en, this message translates to:
  /// **'Set size'**
  String get specKbEditable;

  /// No description provided for @specKbDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Set file size (KB)'**
  String get specKbDialogTitle;

  /// No description provided for @specKbUnreachable.
  ///
  /// In en, this message translates to:
  /// **'This spec yields ~{kb}KB max; minimum cannot exceed it'**
  String specKbUnreachable(Object kb);

  /// No description provided for @dialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dialogCancel;

  /// No description provided for @homeCustomSaved.
  ///
  /// In en, this message translates to:
  /// **'My Custom Specs'**
  String get homeCustomSaved;

  /// No description provided for @customDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete custom spec'**
  String get customDeleteTitle;

  /// No description provided for @customDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String customDeleteConfirm(Object name);

  /// No description provided for @customDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get customDelete;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicyTitle;

  /// No description provided for @privacyPolicyBody.
  ///
  /// In en, this message translates to:
  /// **'Updated November 6, 2026\n\nPhotos and face detection results are processed on your device and are not uploaded for processing. No account is required, and the app has no advertising SDK.\n\nCamera access is used to take photos. Photo library access is used to choose photos and save finished images, only when you use those features.\n\nSaved results are also stored in the app’s private album. Delete them in My Photos. Exported copies must be deleted separately in the system photo library. System photo syncing and backups follow your device settings. Language and custom specifications are stored locally.\n\nGoogle ML Kit performs face detection locally, but can send technical diagnostics and usage metrics to Google, including device/app information, per-installation identifiers, API events, performance and errors. These metrics do not include your input photos or detection results. ONNX Runtime runs the bundled background-removal model locally.\n\nAndroid checks GitHub for app updates and downloads updates on request. iOS updates come from the App Store. Opening the online policy uses your browser.\n\nQuestions: chunguangwee@gmail.com. The online policy provides further details and links to Google’s SDK disclosures.\n\nTemporary export copies are kept in the app cache so receiving apps can read them. Copies older than one day are removed at the next app launch or export.\n\nApplication tasks are stored locally with your notes, requirement references, optional screenshots, source photo and prepared versions. Sources you record are not independently verified. Delete a task to remove its app-owned copies; system originals and files you already exported are kept. Existing-file checks read the selected bytes without changing them. ZIP delivery packages contain photo files and requirement/check reports; only share them with recipients you choose.\n\nRequirement screenshots are read locally using Apple Vision on iOS and bundled ML Kit text recognition on Android. Only selected images are processed; text is not uploaded for recognition. Confirmed excerpts remain in your task and are shared in reports only when you export them. Changed requirements or screenshots require rechecking. Recognition and user confirmation are not institutional certification.'**
  String get privacyPolicyBody;

  /// No description provided for @linkOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open this link. You can copy it and open it in your browser.'**
  String get linkOpenFailed;

  /// No description provided for @photoChecksNote.
  ///
  /// In en, this message translates to:
  /// **'These checks cover selected file properties and general framing estimates. They do not certify compliance or guarantee acceptance. Check the receiving organization’s current requirements.'**
  String get photoChecksNote;

  /// No description provided for @checkFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Checks could not be completed. Please retry.'**
  String get checkFailedRetry;

  /// No description provided for @homeNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching specifications. Try another name or create a custom spec.'**
  String get homeNoResults;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load. Please retry.'**
  String get loadFailed;

  /// No description provided for @kbLimitUnreachable.
  ///
  /// In en, this message translates to:
  /// **'This KB limit cannot be reached while preserving the image dimensions. Choose a larger limit.'**
  String get kbLimitUnreachable;

  /// No description provided for @homeHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Prepare your photo\nfor your application.'**
  String get homeHeroTitle;

  /// No description provided for @homeEyebrow.
  ///
  /// In en, this message translates to:
  /// **'APPLICATION PHOTO WORKSPACE'**
  String get homeEyebrow;

  /// No description provided for @homeCustomDesc.
  ///
  /// In en, this message translates to:
  /// **'Set dimensions, background and KB limits'**
  String get homeCustomDesc;

  /// No description provided for @deliveryExport.
  ///
  /// In en, this message translates to:
  /// **'Export JPEG + report'**
  String get deliveryExport;

  /// No description provided for @deliveryExportHint.
  ///
  /// In en, this message translates to:
  /// **'Export the unchanged JPEG and a JSON check report. Choose Save to Files in the system sheet for file upload. Other destinations may alter images.'**
  String get deliveryExportHint;

  /// No description provided for @tasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Application tasks'**
  String get tasksTitle;

  /// No description provided for @tasksDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep requirements, prepare versions and export together'**
  String get tasksDesc;

  /// No description provided for @taskNew.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get taskNew;

  /// No description provided for @taskEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your next application starts here'**
  String get taskEmpty;

  /// No description provided for @taskEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Save the requirements once, then prepare every photo file you need.'**
  String get taskEmptyHint;

  /// No description provided for @taskDetails.
  ///
  /// In en, this message translates to:
  /// **'Task details'**
  String get taskDetails;

  /// No description provided for @taskName.
  ///
  /// In en, this message translates to:
  /// **'Task name'**
  String get taskName;

  /// No description provided for @taskNotes.
  ///
  /// In en, this message translates to:
  /// **'Requirements and notes'**
  String get taskNotes;

  /// No description provided for @taskSourceReference.
  ///
  /// In en, this message translates to:
  /// **'Requirements source (link or reference)'**
  String get taskSourceReference;

  /// No description provided for @taskVerifiedDate.
  ///
  /// In en, this message translates to:
  /// **'Date you checked the requirements'**
  String get taskVerifiedDate;

  /// No description provided for @taskReferenceNote.
  ///
  /// In en, this message translates to:
  /// **'Sources are saved as your reference; the app does not verify them.'**
  String get taskReferenceNote;

  /// No description provided for @taskSave.
  ///
  /// In en, this message translates to:
  /// **'Save task'**
  String get taskSave;

  /// No description provided for @taskRequiredName.
  ///
  /// In en, this message translates to:
  /// **'Enter a task name'**
  String get taskRequiredName;

  /// No description provided for @taskOriginal.
  ///
  /// In en, this message translates to:
  /// **'One source photo'**
  String get taskOriginal;

  /// No description provided for @taskChooseSource.
  ///
  /// In en, this message translates to:
  /// **'Choose source photo'**
  String get taskChooseSource;

  /// No description provided for @taskReplaceSource.
  ///
  /// In en, this message translates to:
  /// **'Replace source photo'**
  String get taskReplaceSource;

  /// No description provided for @taskReplaceWarning.
  ///
  /// In en, this message translates to:
  /// **'Replacing the source resets all completed versions. Your system photo is not deleted.'**
  String get taskReplaceWarning;

  /// No description provided for @taskEvidence.
  ///
  /// In en, this message translates to:
  /// **'Requirements screenshot'**
  String get taskEvidence;

  /// No description provided for @taskAttachEvidence.
  ///
  /// In en, this message translates to:
  /// **'Attach screenshot'**
  String get taskAttachEvidence;

  /// No description provided for @taskViewEvidence.
  ///
  /// In en, this message translates to:
  /// **'View screenshot'**
  String get taskViewEvidence;

  /// No description provided for @taskOutputs.
  ///
  /// In en, this message translates to:
  /// **'Files to prepare'**
  String get taskOutputs;

  /// No description provided for @taskAddOutput.
  ///
  /// In en, this message translates to:
  /// **'Add file requirements'**
  String get taskAddOutput;

  /// No description provided for @taskFilename.
  ///
  /// In en, this message translates to:
  /// **'Output file name'**
  String get taskFilename;

  /// No description provided for @taskFilenameHelp.
  ///
  /// In en, this message translates to:
  /// **'1–80 letters, numbers, underscores or hyphens. Each name must be unique.'**
  String get taskFilenameHelp;

  /// No description provided for @taskOutputLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to five files per task'**
  String get taskOutputLimit;

  /// No description provided for @taskPrepare.
  ///
  /// In en, this message translates to:
  /// **'Prepare file'**
  String get taskPrepare;

  /// No description provided for @taskRedo.
  ///
  /// In en, this message translates to:
  /// **'Prepare again'**
  String get taskRedo;

  /// No description provided for @taskEditRequirement.
  ///
  /// In en, this message translates to:
  /// **'Edit requirements'**
  String get taskEditRequirement;

  /// No description provided for @taskRemoveOutput.
  ///
  /// In en, this message translates to:
  /// **'Remove file requirements'**
  String get taskRemoveOutput;

  /// No description provided for @taskRequirementsChanged.
  ///
  /// In en, this message translates to:
  /// **'Changing requirements resets this completed file.'**
  String get taskRequirementsChanged;

  /// No description provided for @taskExport.
  ///
  /// In en, this message translates to:
  /// **'Export delivery ZIP'**
  String get taskExport;

  /// No description provided for @taskExportHint.
  ///
  /// In en, this message translates to:
  /// **'Complete each version to export JPEGs, individual JSON reports and a readable checklist together.'**
  String get taskExportHint;

  /// No description provided for @taskReady.
  ///
  /// In en, this message translates to:
  /// **'Prepared'**
  String get taskReady;

  /// No description provided for @taskPending.
  ///
  /// In en, this message translates to:
  /// **'To prepare'**
  String get taskPending;

  /// No description provided for @taskBusy.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get taskBusy;

  /// No description provided for @taskDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete task'**
  String get taskDelete;

  /// No description provided for @taskDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this task and its local photo copies? Files already exported and system originals are kept.'**
  String get taskDeleteConfirm;

  /// No description provided for @taskChanged.
  ///
  /// In en, this message translates to:
  /// **'The source or requirements changed. Return to the task and prepare this version again.'**
  String get taskChanged;

  /// No description provided for @taskSaveOutput.
  ///
  /// In en, this message translates to:
  /// **'Save file to task'**
  String get taskSaveOutput;

  /// No description provided for @taskOutputSaved.
  ///
  /// In en, this message translates to:
  /// **'File saved to task'**
  String get taskOutputSaved;

  /// No description provided for @taskSaveOutputHint.
  ///
  /// In en, this message translates to:
  /// **'Save this version to the task, then prepare the next file or export the delivery package.'**
  String get taskSaveOutputHint;

  /// No description provided for @taskFixedRequirements.
  ///
  /// In en, this message translates to:
  /// **'Background and file requirements are fixed by this task. Edit them on the task page.'**
  String get taskFixedRequirements;

  /// No description provided for @taskNoSource.
  ///
  /// In en, this message translates to:
  /// **'Choose one source photo before preparing versions.'**
  String get taskNoSource;

  /// No description provided for @taskExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to export. Check that every output exists and still meets its requirements.'**
  String get taskExportFailed;

  /// No description provided for @taskInvalidName.
  ///
  /// In en, this message translates to:
  /// **'Use a unique file name with letters, numbers, underscores or hyphens.'**
  String get taskInvalidName;

  /// No description provided for @taskInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a readable photo up to 30 MB and 24 megapixels.'**
  String get taskInvalidFile;

  /// No description provided for @taskActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to complete this action. Please retry.'**
  String get taskActionFailed;

  /// No description provided for @taskOutputMismatch.
  ///
  /// In en, this message translates to:
  /// **'This file does not meet the task requirements. Adjust it before saving.'**
  String get taskOutputMismatch;

  /// No description provided for @checkExistingTitle.
  ///
  /// In en, this message translates to:
  /// **'Check an existing photo'**
  String get checkExistingTitle;

  /// No description provided for @checkExistingDesc.
  ///
  /// In en, this message translates to:
  /// **'Inspect the file you already have, without editing it'**
  String get checkExistingDesc;

  /// No description provided for @checkChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose photo file'**
  String get checkChooseFile;

  /// No description provided for @checkRequirements.
  ///
  /// In en, this message translates to:
  /// **'Photo requirements'**
  String get checkRequirements;

  /// No description provided for @checkSetRequirements.
  ///
  /// In en, this message translates to:
  /// **'Set requirements'**
  String get checkSetRequirements;

  /// No description provided for @checkRun.
  ///
  /// In en, this message translates to:
  /// **'Check selected file'**
  String get checkRun;

  /// No description provided for @checkNoFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a file and enter the requirements to begin.'**
  String get checkNoFile;

  /// No description provided for @checkByteNote.
  ///
  /// In en, this message translates to:
  /// **'Checks read the selected file without changing it. Files preserves the selected bytes; Photos or Camera may supply a converted copy.'**
  String get checkByteNote;

  /// No description provided for @checkScope.
  ///
  /// In en, this message translates to:
  /// **'File properties only. Portrait, background, identity and institutional acceptance are not verified.'**
  String get checkScope;

  /// No description provided for @checkMakeCopy.
  ///
  /// In en, this message translates to:
  /// **'Prepare a new copy'**
  String get checkMakeCopy;

  /// No description provided for @checkActual.
  ///
  /// In en, this message translates to:
  /// **'Actual file'**
  String get checkActual;

  /// No description provided for @checkRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get checkRequired;

  /// No description provided for @checkPassed.
  ///
  /// In en, this message translates to:
  /// **'Selected file properties match'**
  String get checkPassed;

  /// No description provided for @checkFailed.
  ///
  /// In en, this message translates to:
  /// **'Some file properties do not match'**
  String get checkFailed;

  /// No description provided for @chooseFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get chooseFiles;

  /// No description provided for @choosePhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get choosePhotos;

  /// No description provided for @chooseCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get chooseCamera;

  /// No description provided for @taskChooseDate.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get taskChooseDate;

  /// No description provided for @taskClearDate.
  ///
  /// In en, this message translates to:
  /// **'Clear date'**
  String get taskClearDate;

  /// No description provided for @taskEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get taskEdit;

  /// No description provided for @taskRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this requirement and its prepared local copy?'**
  String get taskRemoveConfirm;

  /// No description provided for @taskFilesCount.
  ///
  /// In en, this message translates to:
  /// **'files prepared'**
  String get taskFilesCount;

  /// No description provided for @taskNoOutputs.
  ///
  /// In en, this message translates to:
  /// **'Add the dimensions, KB range and name for each file you need.'**
  String get taskNoOutputs;

  /// No description provided for @taskDeliveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your application, ready to prepare'**
  String get taskDeliveryTitle;

  /// No description provided for @workflowDemo.
  ///
  /// In en, this message translates to:
  /// **'Try a demo task'**
  String get workflowDemo;

  /// No description provided for @workflowDemoNote.
  ///
  /// In en, this message translates to:
  /// **'Fictional requirements · real editing and export'**
  String get workflowDemoNote;

  /// No description provided for @workflowOverview.
  ///
  /// In en, this message translates to:
  /// **'Delivery overview'**
  String get workflowOverview;

  /// No description provided for @workflowRefresh.
  ///
  /// In en, this message translates to:
  /// **'Recheck files'**
  String get workflowRefresh;

  /// No description provided for @workflowRequired.
  ///
  /// In en, this message translates to:
  /// **'Required file properties'**
  String get workflowRequired;

  /// No description provided for @workflowActual.
  ///
  /// In en, this message translates to:
  /// **'Measured file properties'**
  String get workflowActual;

  /// No description provided for @workflowBackground.
  ///
  /// In en, this message translates to:
  /// **'Selected background (not measured)'**
  String get workflowBackground;

  /// No description provided for @workflowUnprepared.
  ///
  /// In en, this message translates to:
  /// **'Not prepared'**
  String get workflowUnprepared;

  /// No description provided for @workflowMissing.
  ///
  /// In en, this message translates to:
  /// **'File missing — prepare again'**
  String get workflowMissing;

  /// No description provided for @workflowFailed.
  ///
  /// In en, this message translates to:
  /// **'File checks failed — review or prepare again'**
  String get workflowFailed;

  /// No description provided for @workflowPassed.
  ///
  /// In en, this message translates to:
  /// **'File checks passed'**
  String get workflowPassed;

  /// No description provided for @workflowExcerpt.
  ///
  /// In en, this message translates to:
  /// **'Requirement excerpt (source not independently verified)'**
  String get workflowExcerpt;

  /// No description provided for @workflowConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed by you'**
  String get workflowConfirmed;

  /// No description provided for @workflowStale.
  ///
  /// In en, this message translates to:
  /// **'Requirements or source changed — confirm again'**
  String get workflowStale;

  /// No description provided for @workflowPrepare.
  ///
  /// In en, this message translates to:
  /// **'Prepare this file'**
  String get workflowPrepare;

  /// No description provided for @workflowEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit requirements'**
  String get workflowEdit;

  /// No description provided for @workflowExtract.
  ///
  /// In en, this message translates to:
  /// **'Extract requirements from screenshot'**
  String get workflowExtract;

  /// No description provided for @workflowRecognizing.
  ///
  /// In en, this message translates to:
  /// **'Reading text on your device…'**
  String get workflowRecognizing;

  /// No description provided for @workflowRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry recognition'**
  String get workflowRetry;

  /// No description provided for @workflowOcrFailed.
  ///
  /// In en, this message translates to:
  /// **'Text recognition unavailable or failed. Retry or enter requirements manually.'**
  String get workflowOcrFailed;

  /// No description provided for @workflowNoText.
  ///
  /// In en, this message translates to:
  /// **'No readable text found. Try a clearer screenshot or enter requirements manually.'**
  String get workflowNoText;

  /// No description provided for @workflowOcrNote.
  ///
  /// In en, this message translates to:
  /// **'Review every value against the screenshot. Nothing is saved until you confirm. 1 KB = 1024 bytes.'**
  String get workflowOcrNote;

  /// No description provided for @workflowOriginalText.
  ///
  /// In en, this message translates to:
  /// **'Recognized text'**
  String get workflowOriginalText;

  /// No description provided for @workflowDimensions.
  ///
  /// In en, this message translates to:
  /// **'Dimension candidates — confirm width and height'**
  String get workflowDimensions;

  /// No description provided for @workflowSize.
  ///
  /// In en, this message translates to:
  /// **'File-size candidates'**
  String get workflowSize;

  /// No description provided for @workflowWidth.
  ///
  /// In en, this message translates to:
  /// **'Width (px)'**
  String get workflowWidth;

  /// No description provided for @workflowHeight.
  ///
  /// In en, this message translates to:
  /// **'Height (px)'**
  String get workflowHeight;

  /// No description provided for @workflowMinimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum KB (blank = no minimum)'**
  String get workflowMinimum;

  /// No description provided for @workflowMaximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum KB (blank = no maximum)'**
  String get workflowMaximum;

  /// No description provided for @workflowFilename.
  ///
  /// In en, this message translates to:
  /// **'File name (without .jpg)'**
  String get workflowFilename;

  /// No description provided for @workflowChooseBackground.
  ///
  /// In en, this message translates to:
  /// **'Select required background'**
  String get workflowChooseBackground;

  /// No description provided for @workflowJpeg.
  ///
  /// In en, this message translates to:
  /// **'I have checked that JPEG is acceptable'**
  String get workflowJpeg;

  /// No description provided for @workflowConfirmValues.
  ///
  /// In en, this message translates to:
  /// **'I have verified width, height and all requirements against the source'**
  String get workflowConfirmValues;

  /// No description provided for @workflowAdd.
  ///
  /// In en, this message translates to:
  /// **'Confirm and add requirements'**
  String get workflowAdd;

  /// No description provided for @workflowInvalid.
  ///
  /// In en, this message translates to:
  /// **'Complete and confirm valid requirements: 50–2000 px, aspect 0.5–2, KB up to 2048; unique ASCII file name.'**
  String get workflowInvalid;

  /// No description provided for @workflowUnsupported.
  ///
  /// In en, this message translates to:
  /// **'The source contains unsupported units or formats. Review the original; only pixel dimensions, KB and JPEG can be prepared here. Do not silently substitute its requirements.'**
  String get workflowUnsupported;

  /// No description provided for @workflowManual.
  ///
  /// In en, this message translates to:
  /// **'Enter requirements manually'**
  String get workflowManual;

  /// No description provided for @workflowReconfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm against current screenshot'**
  String get workflowReconfirm;

  /// No description provided for @workflowReconfirmNote.
  ///
  /// In en, this message translates to:
  /// **'Check the current screenshot and these requirements before confirming. This is your confirmation, not institutional certification.'**
  String get workflowReconfirmNote;

  /// No description provided for @workflowRecent.
  ///
  /// In en, this message translates to:
  /// **'Continue recent task'**
  String get workflowRecent;

  /// No description provided for @workflowInProgress.
  ///
  /// In en, this message translates to:
  /// **'unfinished tasks'**
  String get workflowInProgress;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
