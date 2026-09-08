import 'package:flutter/widgets.dart';

import '../models/photo_spec.dart';
import '../services/compliance_service.dart';
import 'app_localizations.dart';

/// 服务层（image_pipeline / compliance_service）与规格模型输出的中文
/// 固定文案 → l10n 键的翻译层。服务层保持纯逻辑、不依赖 BuildContext。
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

  // ── ImagePipeline 进度步骤 / 异常消息 ────────────────────────────

  /// 流水线 onProgress 回调的中文步骤 → 本地化步骤。
  String step(String raw) {
    switch (raw) {
      case '准备中…':
        return _l.stepPreparing;
      case '正在读取照片…':
        return _l.stepReading;
      case '正在智能抠图…':
        return _l.stepSegmenting;
      case '正在检测人脸并构图…':
        return _l.stepDetectingFace;
      case '正在压缩导出…':
        return _l.stepCompressing;
    }
    // 「正在合成<底色名>…」
    if (raw.startsWith('正在合成') && raw.endsWith('…')) {
      final bg = raw.substring(4, raw.length - 1);
      return _l.stepCompositing(bgNameNamed(bg));
    }
    return raw;
  }

  /// PipelineException.message → 本地化错误。
  String pipelineError(String raw) {
    switch (raw) {
      case '无法读取该照片，请换一张 JPG/PNG 图片':
        return _l.errReadPhoto;
      case '抠图失败，未识别到人物，请使用单人正脸照片':
        return _l.errNoPerson;
      case '未检测到正脸，请重新拍摄：正对镜头、面部无遮挡':
        return _l.errNoFace;
    }
    return raw;
  }

  String bgNameNamed(String name) => name == '蓝底' ? _l.bgBlue : name;

  // ── ComplianceService 检测项 ────────────────────────────────────

  /// CheckItem.label → 本地化标签（按服务层生成的固定前缀匹配）。
  String checkLabel(CheckItem item, PhotoSpec spec) {
    final label = item.label;
    if (label == '文件格式为 JPG') return _l.checkJpgFormat;
    if (label == '图片可解码') return _l.checkDecodable;
    if (label == '底色为蓝底') return _l.checkBlueBg;
    if (label == '检测到正脸') return _l.checkFaceDetected;
    if (label == '头部水平居中') return _l.checkHeadCentered;
    if (label == '双眼睁开') return _l.checkEyesOpen;
    if (label == '头部占比 45%–85%') return _l.checkHeadRatio;
    if (label.startsWith('文件大小 ')) {
      return _l.checkFileSizeRange(spec.minFileKb, spec.maxFileKb);
    }
    if (label.startsWith('像素尺寸 ')) {
      return _l.checkPixelSize(
          spec.minWidth, spec.maxWidth, spec.minHeight, spec.maxHeight);
    }
    if (label.startsWith('最佳尺寸 ')) {
      return _l.checkBestSize(spec.pixelWidth, spec.pixelHeight);
    }
    if (label.startsWith('比例（高/宽）')) {
      return _l.checkRatio(
          _num(spec.minRatio.toString()), _num(spec.maxRatio.toString()));
    }
    return label;
  }

  /// CheckItem.fix → 本地化修复建议。
  String? fix(String? raw) {
    if (raw == null) return null;
    switch (raw) {
      case '文件过大，请重新生成压缩':
        return _l.fixFileTooLarge;
      case '文件过小，请提高导出质量':
        return _l.fixFileTooSmall;
      case '文件损坏，请重新生成':
        return _l.fixFileCorrupt;
      case '尺寸越界，请重新生成':
        return _l.fixSizeOutOfRange;
      case '比例不符，请重新裁剪':
        return _l.fixRatioMismatch;
      case '检测到底色不是蓝色，请使用换底功能重新生成':
        return _l.fixNotBlue;
      case '未检测到人脸，建议使用正脸免冠照片重新拍摄':
        return _l.fixNoFace;
      case '头部占比不合适，请调整拍摄距离':
        return _l.fixHeadRatio;
      case '人物未居中，请重新构图':
        return _l.fixNotCentered;
      case '检测到闭眼，请重新拍摄':
        return _l.fixEyesClosed;
    }
    return raw;
  }

  /// CheckItem.detail → 本地化实测值（仅「偏差 x%」含文案，数字类原样）。
  String? detail(String? raw) {
    if (raw == null) return null;
    if (raw.startsWith('偏差 ')) {
      return _l.deviationPercent(raw.substring(3));
    }
    return raw;
  }

  /// 1.2 → "1.2"，1.0 → "1"（与 ARB 中文原文格式一致）
  static String _num(String s) =>
      s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}
