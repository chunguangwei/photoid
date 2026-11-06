# Verification — requirements workflow (2026-11-06)

## Executed

- Baseline: 153 Flutter tests passed before implementation.
- Independent whole-change review found no Critical issues; material parser, excerpt privacy, broken-demo reuse and candidate display issues were fixed with regressions.
- Final full regression: `flutter test --no-pub` passed **185 tests**. `flutter analyze --no-pub` reported **No issues found**. The last pass includes trailing dimension bounds, mid-transaction demo rollback, manual fallback, conflicting background presentation, confirmed import, stale/missing evidence and short-excerpt export.
- iOS arm64 release build without code signing succeeded, including Swift Vision channel. Internal validation artifact: build/ios/iphoneos/Runner.app. Not installable as a signed distribution package.
- Explicit x86_64 simulator build succeeded. iOS 27 simulator refused installation because that runtime cannot execute x86_64; arm64 simulator is blocked by existing MLKit face-detection frameworks. Do not claim a successful iOS simulator run.
- Apple Vision macOS engine smoke test recognized English and Chinese fixtures. This is engine testing, not iPhone device acceptance.
- Final Android release compilation succeeded (178.4 MB, validation only; debug signing fallback).
- Android device integration: emulator-5554, Wi-Fi and mobile data disabled before the test installation/first recognition. Both bundled Chinese and Latin models read EN/ZH fixture dimensions and size ranges; demo assets created real incomplete tasks. Test passed. An earlier Chinese fixture had an OCR unit error; parser correctly refused it, fixture legibility was improved, and unknown-unit rejection remains tested.
- 320pt / 130% EN/ZH light/dark task widgets passed; success/cancel/failure/stale-source import and actual delivery corruption cases tested.

## Pending before submission

- Connected physical iPhone and iPad were listed unavailable. Complete Files/Photos selection, EN/ZH OCR confirmation, manual fallback, separate crops, save/reopen, overview and ZIP save/unzip on both physical devices. No full iPad interaction claim.
- Android physical device signed upgrade: no device connected. Current worktree release build uses debug fallback because release signing credentials are absent in the isolated worktree; do not distribute this APK as a signed upgrade.
- Capture final actual device screenshots and 60–90 second video, validate against the final version/build. No widget rendering may be substituted for a store screenshot.
- Recheck App Store build numbers, current Apple response, final privacy disclosure and metadata before a new submission. Do not automatically resubmit or add an appeal.

## Automation/security review

A local automated commit security scan could not reach its model (network timeout); this was reported during the session. Details: /Users/weichunguang/.claude/security/log.txt. Independent code review and tests are recorded separately and are not represented as completion of that scan.
