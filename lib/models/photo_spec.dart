/// 证件照规格模型。后续规格库（30+ 场景）复用同一结构，可由 JSON 反序列化。
library;

class SpecBackground {
  const SpecBackground(this.name, this.r, this.g, this.b);

  final String name;
  final int r;
  final int g;
  final int b;

  factory SpecBackground.fromJson(Map<String, dynamic> json) => SpecBackground(
        json['name'] as String,
        json['r'] as int,
        json['g'] as int,
        json['b'] as int,
      );
}

class PhotoSpec {
  const PhotoSpec({
    required this.id,
    required this.name,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.minFileKb,
    required this.maxFileKb,
    required this.minWidth,
    required this.maxWidth,
    required this.minHeight,
    required this.maxHeight,
    required this.minRatio,
    required this.maxRatio,
    required this.background,
    this.requirements = const [],
  });

  final String id;
  final String name;

  /// 最佳像素尺寸
  final int pixelWidth;
  final int pixelHeight;

  /// 文件大小合法区间（KB）
  final int minFileKb;
  final int maxFileKb;

  /// 允许的宽/高像素区间
  final int minWidth;
  final int maxWidth;
  final int minHeight;
  final int maxHeight;

  /// 允许的高/宽比例区间
  final double minRatio;
  final double maxRatio;

  final SpecBackground background;

  /// 面向用户的要求清单（原样展示）
  final List<String> requirements;

  /// 宽/高
  double get aspect => pixelWidth / pixelHeight;


  PhotoSpec copyWith({
    String? name,
    int? pixelWidth,
    int? pixelHeight,
    int? minFileKb,
    int? maxFileKb,
    SpecBackground? background,
  }) =>
      PhotoSpec(
        id: id,
        name: name ?? this.name,
        pixelWidth: pixelWidth ?? this.pixelWidth,
        pixelHeight: pixelHeight ?? this.pixelHeight,
        minFileKb: minFileKb ?? this.minFileKb,
        maxFileKb: maxFileKb ?? this.maxFileKb,
        minWidth: minWidth,
        maxWidth: maxWidth,
        minHeight: minHeight,
        maxHeight: maxHeight,
        minRatio: minRatio,
        maxRatio: maxRatio,
        background: background ?? this.background,
        requirements: requirements,
      );
  factory PhotoSpec.fromJson(Map<String, dynamic> json) => PhotoSpec(
        id: json['id'] as String,
        name: json['name'] as String,
        pixelWidth: json['pixelWidth'] as int,
        pixelHeight: json['pixelHeight'] as int,
        minFileKb: json['minFileKb'] as int,
        maxFileKb: json['maxFileKb'] as int,
        minWidth: json['minWidth'] as int,
        maxWidth: json['maxWidth'] as int,
        minHeight: json['minHeight'] as int,
        maxHeight: json['maxHeight'] as int,
        minRatio: (json['minRatio'] as num).toDouble(),
        maxRatio: (json['maxRatio'] as num).toDouble(),
        background: SpecBackground.fromJson(
            (json['background'] as Map).cast<String, dynamic>()),
        requirements: (json['requirements'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
      );
}

/// 标准证件照蓝底 RGB(67,142,219)
const idPhotoBlue = SpecBackground('蓝底', 67, 142, 219);

/// 常用证件照底色板（换底色功能使用）。
const idPhotoWhite = SpecBackground('白底', 255, 255, 255);
const idPhotoRed = SpecBackground('红底', 255, 0, 0);
const idPhotoGray = SpecBackground('灰底', 178, 178, 178);
const idPhotoDarkBlue = SpecBackground('深蓝底', 0, 64, 152);

/// 全部可选底色（顺序即 UI 展示顺序）。
const idPhotoBackgrounds = [
  idPhotoBlue,
  idPhotoWhite,
  idPhotoRed,
  idPhotoGray,
  idPhotoDarkBlue,
];

/// 底色名 → l10n 键（pages 层据此本地化展示名）。
const backgroundL10nKeys = {
  '蓝底': 'bgBlue',
  '白底': 'bgWhite',
  '红底': 'bgRed',
  '灰底': 'bgGray',
  '深蓝底': 'bgDarkBlue',
};

/// 学校通知的学生报名照要求（教育ID命名）。
const studentPhotoSpec = PhotoSpec(
  id: 'student_edu_id',
  name: '学生报名照（教育ID）',
  pixelWidth: 480,
  pixelHeight: 640,
  minFileKb: 10,
  maxFileKb: 500,
  minWidth: 380,
  maxWidth: 580,
  minHeight: 540,
  maxHeight: 740,
  minRatio: 1.2,
  maxRatio: 1.4,
  background: idPhotoBlue,
  requirements: [
    '照片文件用教育ID命名（jpg 格式）',
    '文件大小在 10KB–500KB 之间',
    '照片底色为蓝底',
    '最佳尺寸 480×640 像素（宽 380–580，高 540–740）',
    '照片比例（高/宽）在 1.2–1.4 之间',
    '外穿秋季校服外套，里穿白色夏季半袖',
  ],
);
