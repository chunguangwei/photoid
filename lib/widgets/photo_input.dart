import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' as picker;
import '../l10n/app_localizations.dart';

/// File selection keeps bytes; Photos may supply a system conversion.
Future<XFile?> choosePhotoInput(BuildContext context,
    {bool allowCamera = false}) async {
  final l = AppLocalizations.of(context);
  final kind = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
                leading: const Icon(Icons.folder_open),
                title: Text(l.chooseFiles),
                onTap: () => Navigator.pop(ctx, 0)),
            ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l.choosePhotos),
                onTap: () => Navigator.pop(ctx, 1)),
            if (allowCamera)
              ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: Text(l.chooseCamera),
                  onTap: () => Navigator.pop(ctx, 2)),
          ])));
  if (kind == null) return null;
  if (kind == 0) {
    return openFile(acceptedTypeGroups: [
      const XTypeGroup(
          label: 'Photo',
          extensions: ['jpg', 'jpeg', 'png', 'heic', 'heif'],
          uniformTypeIdentifiers: ['public.image'])
    ]);
  }
  final selected = await picker.ImagePicker().pickImage(
      source:
          kind == 2 ? picker.ImageSource.camera : picker.ImageSource.gallery);
  return selected == null ? null : XFile(selected.path);
}

Future<Uint8List> readBoundedPhoto(XFile file) async {
  if (await file.length() > 30 * 1024 * 1024) {
    throw ArgumentError('Image exceeds 30 MB');
  }
  return file.readAsBytes();
}

void showPhotoActionError(BuildContext context, Object error,
    {bool exporting = false}) {
  if (!context.mounted) return;
  final l = AppLocalizations.of(context);
  final message = error.toString();
  final text = exporting
      ? l.taskExportFailed
      : message.contains('changed')
          ? l.taskChanged
          : message.contains('name')
              ? l.taskInvalidName
              : message.contains('requirements')
                  ? l.taskOutputMismatch
                  : error is ArgumentError
                      ? l.taskInvalidFile
                      : l.taskActionFailed;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
