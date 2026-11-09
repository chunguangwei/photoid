import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

/// Actual detector inputs, never canned candidate results.
Map<String, Uint8List> finderDemoVariants(Uint8List bytes) {
  final portrait = img.decodeImage(bytes)!;
  final small = img.copyResize(portrait, height: 160);
  final blurred =
      img.gaussianBlur(img.copyResize(portrait, height: 800), radius: 10);
  final tile = img.copyResize(portrait, height: 640);
  final pair = img.Image(width: tile.width * 2 + 80, height: tile.height);
  img.fill(pair, color: img.ColorRgb8(235, 235, 235));
  img.compositeImage(pair, tile);
  img.compositeImage(pair, tile, dstX: tile.width + 80);
  final blank = img.Image(width: 800, height: 600);
  img.fill(blank, color: img.ColorRgb8(180, 210, 230));
  return {
    'portrait.jpg': bytes,
    'small.jpg': Uint8List.fromList(img.encodeJpg(small)),
    'blurred.jpg': Uint8List.fromList(img.encodeJpg(blurred)),
    'two_portraits.jpg': Uint8List.fromList(img.encodeJpg(pair)),
    'no_portrait.jpg': Uint8List.fromList(img.encodeJpg(blank))
  };
}

Future<List<String>> writeFinderDemo(Directory directory) async {
  final asset = await rootBundle.load('assets/demo/portrait.jpg');
  final variants = await compute(finderDemoVariants,
      asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes));
  return [
    for (final entry in variants.entries)
      (await File('${directory.path}/${entry.key}').writeAsBytes(entry.value))
          .path
  ];
}
