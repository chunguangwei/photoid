# Contributing to PhotoID

Thanks for your interest in contributing! This project is a Flutter app for
on-device ID photo creation. Keep changes focused, local-first, and free of
new paid/watermark/account features unless discussed in an issue first.

## Reporting Issues

- Search existing issues before opening a new one.
- Include: Flutter version (`flutter doctor -v`), platform (Android/iOS +
  version), device model, and steps to reproduce.
- For crash/segmentation issues, attach a minimal sample image if possible
  (never personal ID photos of others without consent).

## Pull Requests

1. Fork the repo and create a feature branch: `git checkout -b feat/my-change`
2. Make focused commits with clear messages.
3. Run `flutter analyze` and `flutter test` — keep the tree green.
4. Open a PR describing **what** changed and **why**; link the related issue.
5. Address review feedback before merge; maintainers may squash commits.

## Code Style

- Follow the existing [flutter_lints](https://pub.dev/packages/flutter_lints)
  defaults; run `dart format` before committing.
- Keep UI strings bilingual (中文 + English) via the ARB files in `lib/l10n/`.
- Prefer editing existing services/pages over adding new layers.
- All image processing stays on-device — do not add network upload paths.

## Scope Boundaries

- No paid features, watermarks, or account systems.
- No server-side photo processing or telemetry that transmits images.
