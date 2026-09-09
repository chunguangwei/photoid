import 'package:flutter/widgets.dart';

import '../models/photo_spec.dart';
import '../services/compliance_service.dart';
import '../services/image_pipeline.dart';
import 'app_localizations.dart';

/// 服务层（image_pipeline / compliance_service）与规格模型输出的语义标识
/// → l10n 键的翻译层。服务层保持纯逻辑、不依赖 BuildContext。
class Tr {
  Tr.of(BuildContext context) : _l = AppLocalizations.of(context);

  final AppLocalizations _l;

  AppLocalizations get l => _l;

  // ── 规格模型（photo_spec 常量为中文数据）─────────────────────────

  /// 规格名。目前仅内置学生规格有译文；其余（如未来 JSON 规格）原样显示。
  String specName(PhotoSpec spec) =>
      spec.id == 'student_edu_id' ? _l.specStudentName : spec.name;

  String bgName(SpecBackground bg) =>
      bg.name == '蓝底' ? _l.bgBlue : bg.name;

  List<String> requirements(PhotoSpec spec) {
    if (spec.id != 'student_edu_id') return spec.requirements;
    return [
      _l.reqEduIdName,
      _l.reqFileSize,
      _l.reqBlueBg,
      _l.reqBestSize,
      _l.reqRatio,
      _l.reqClothing,
    ];
  }

  // ── ImagePipeline 进度步骤 / 异常 ────────────────────────────────

  String step(PipelineStep step) {
    switch (step) {
      case PipelineStep.preparing:
        return _l.stepPreparing;
      case PipelineStep.reading:
        return _l.stepReading;
      case PipelineStep.segmenting:
        return _l.stepSegmenting;
      case PipelineStep.compositing:
        return _l.stepCompositing(_l.bgBlue);
      case PipelineStep.framing:
        return _l.stepDetectingFace;
      case PipelineStep.compressing:
        return _l.stepCompressing;
    }
  }

  String pipelineError(PipelineException e) {
    switch (e.code) {
      case 'readPhoto':
        return _l.errReadPhoto;
      case 'noPerson':
        return _l.errNoPerson;
      case 'noFace':
        return _l.errNoFace;
    }
    return e.code;
  }

  // ── ComplianceService 检测项 ────────────────────────────────────

  String checkLabel(CheckItem item, PhotoSpec spec) {
    switch (item.id) {
      case 'format':
        return _l.checkJpgFormat;
      case 'fileSize':
        return _l.checkFileSizeRange(spec.minFileKb, spec.maxFileKb);
      case 'decodable':
        return _l.checkDecodable;
      case 'pixelSize':
        return _l.checkPixelSize(
            spec.minWidth, spec.maxWidth, spec.minHeight, spec.maxHeight);
      case 'bestSize':
        return _l.checkBestSize(spec.pixelWidth, spec.pixelHeight);
      case 'ratio':
        return _l.checkRatio(
            _num(spec.minRatio.toString()), _num(spec.maxRatio.toString()));
      case 'blueBg':
        return _l.checkBlueBg;
      case 'faceDetected':
        return _l.checkFaceDetected;
      case 'headRatio':
        return _l.checkHeadRatio;
      case 'headCentered':
        return _l.checkHeadCentered;
      case 'eyesOpen':
        return _l.checkEyesOpen;
    }
    return item.id;
  }

  String? fix(CheckItem item) {
    if (item.fixId == null) return null;
    switch (item.fixId!) {
      case 'fileTooLarge':
        return _l.fixFileTooLarge;
      case 'fileTooSmall':
        return _l.fixFileTooSmall;
      case 'fileCorrupt':
        return _l.fixFileCorrupt;
      case 'sizeOutOfRange':
        return _l.fixSizeOutOfRange;
      case 'ratioMismatch':
        return _l.fixRatioMismatch;
      case 'notBlue':
        return _l.fixNotBlue;
      case 'noFace':
        return _l.fixNoFace;
      case 'headRatio':
        return _l.fixHeadRatio;
      case 'notCentered':
        return _l.fixNotCentered;
      case 'eyesClosed':
        return _l.fixEyesClosed;
    }
    return item.fixId;
  }

  String? detail(CheckItem item) {
    if (item.detail == null) return null;
    if (item.id == 'headCentered') {
      return _l.deviationPercent(item.detail!);
    }
    return item.detail;
  }

  /// 1.2 → "1.2"，1.0 → "1"（与 ARB 中文原文格式一致）
  static String _num(String s) =>
      s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}
