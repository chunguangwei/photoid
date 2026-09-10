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
  /// **'Blue background'**
  String get bgBlue;

  /// No description provided for @requirementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo requirements'**
  String get requirementsTitle;

  /// No description provided for @reqEduIdName.
  ///
  /// In en, this message translates to:
  /// **'Name the file with your Education ID (JPG format)'**
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
  /// **'Run compliance check & save'**
  String get complianceCheckSave;

  /// No description provided for @resultTitle.
  ///
  /// In en, this message translates to:
  /// **'Compliance check'**
  String get resultTitle;

  /// No description provided for @checkItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Checks'**
  String get checkItemsTitle;

  /// No description provided for @verdictPass.
  ///
  /// In en, this message translates to:
  /// **'Meets school requirements'**
  String get verdictPass;

  /// No description provided for @verdictFail.
  ///
  /// In en, this message translates to:
  /// **'Some checks failed'**
  String get verdictFail;

  /// No description provided for @eduIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Education ID (used as file name)'**
  String get eduIdLabel;

  /// No description provided for @eduIdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2026010101'**
  String get eduIdHint;

  /// No description provided for @eduIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your Education ID as the file name first'**
  String get eduIdRequired;

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
  /// **'Custom'**
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
  /// **'Photos never leave your device'**
  String get privacySlogan;

  /// No description provided for @hotNow.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
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

  /// No description provided for @editHd.
  ///
  /// In en, this message translates to:
  /// **'HD Enhanced'**
  String get editHd;

  /// No description provided for @editNormal.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get editNormal;

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
