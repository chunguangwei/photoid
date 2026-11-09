# Task-aware Local Photo Finder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Scan a user-selected folder or explicit file batch, explain suitable portrait candidates against task requirements, and import only the user's choice while keeping manual selection.
**Architecture:** A bounded native session owns directory access and thumbnails. Dart parses detector results, computes transparent suitability/crop heuristics and drives a cancellable task-scoped UI. Existing task source replacement and editor/export remain authoritative.
**Tech Stack:** Flutter/Dart, iOS Vision/document picker/ImageIO, Android SAF/Bitmap/ML Kit bundled face detection.
**Spec:** docs/superpowers/specs/2026-11-09-ai-photo-finder-design.md

## Global Constraints
- Preserve manual Files/Photos/camera entry, existing OCR/demo/editor/export; iOS 15.5 / Android API 26.
- No cloud inference, identity embeddings, full-gallery permission or all-files permission; only explicit scoped sources.
- No automatic App Store submission; real screenshots cannot be replaced by mockups.
- At most 2000 directory items, 500 images, depth 5, 30MB/file, 24MP before decode; sequential analysis.

## Review Focus
- Multiple/unknown faces never become a confident single portrait (Task 1 tests).
- Corrupt/oversized/provider-remote images stay separate from unsuitable portraits (Tasks 1/2 tests and native guards).
- Stop/lifecycle/dispose ignore late results; source handles remain valid only within their session (Task 2 tests).
- Changed task requirements/files cannot import a stale recommendation (Tasks 2/3 tests).
- Manual selection remains reachable and source replacement invalidates existing outputs (Task 3 regression).

### Task 1: Explainable candidate evaluation
**Files:** lib/services/photo_finder_models.dart, lib/services/photo_finder_ranking.dart; test/photo_finder_ranking_test.dart.
**Interfaces:** FinderAnalysis.fromMap; evaluatePhoto(analysis,List<ApplicationOutput>) -> FinderCandidate (group/reasons/crop estimates/coverage); no acceptance probability.
- [x] Write red tests for zero/multiple/unknown faces, missing pose, low crop pixels, crop bounds and five-output coverage, compression-independent original bytes.
- [x] Implement normalized face geometry and bounded quality heuristics; run targeted tests green and commit.

### Task 2: Native scoped scan and Dart lifecycle
**Files:** lib/services/photo_finder_session.dart; ios/Runner/PhotoFinderBridge.swift and registration/project reference; android/.../PhotoFinderBridge.kt and MainActivity registration; test/photo_finder_session_test.dart.
**Interfaces:** photoid/photo_finder channel: chooseDirectory(recursive), chooseFiles, openDemo -> listing; analyze(session,id), materialize(session,id), close(session). Listing includes visited/truncated/entries and opaque IDs. Native checks originals and returns owned thumbnail paths, normalized detections, current fingerprint.
- [x] Write red fake-gateway tests for sequential scan, stop/dispose/late results, provider skips and session cleanup.
- [x] Implement iOS security-scope/coordinated bounded enumeration + Vision, Android read-only SAF local-provider enumeration + bundled ML Kit. Reject unsupported/unreadable/remote/oversized files explicitly; no guessed paths.
- [x] Recheck file hash at import, close all native resources on scope exit and clear stale session caches.
- [x] Verify green tests, native compilers, real detector smoke tests; commit.

### Task 3: UI and existing task connection
**Files:** lib/pages/photo_finder_page.dart; application_task_page.dart, home_page.dart, application_tasks_page.dart; ARBs/generated l10n; test/photo_finder_ui_test.dart.
**Interfaces:** Finder returns selected owned photo copy; parent awaits store.setSource then ends session. Existing source replacement confirmation remains mandatory. Home chooses task; task page explains missing requirements. Public demo creates a local sample directory and uses the same detector.
- [x] Write red tests for manual actions, no-requirement guard, reasons/candidate filtering, uncertain selection, stale task, clear/stop, small EN/ZH/light/dark UI.
- [x] Implement setup with folder/multi-file/demo buttons, provider notice, opt-in recursion; scan progress; grouped searchable candidates; measured reasons/crop previews; explicit adoption.
- [x] Verify green tests and full existing suite; commit.

### Task 4: Full documentation and review material
**Files:** README.md, CONTRIBUTING.md, docs/product.md, docs/development.md, docs/index.md, docs/appstore.md, docs/privacy-policy.md, historical PRD increment; new architecture/testing/release documents and metadata.
- [x] Update only current capability descriptions; preserve historical release/rejection evidence.
- [x] Provide EN/ZH metadata, concrete review walkthrough, actual screenshot/video capture plan; retain manual selection in every relevant description.
- [x] Run full tests/analyzer/builds and independent whole-change review, fix material defects with regressions.
- [x] Record physical-device/screenshot gaps accurately, update draft PR, no auto resubmission.


## Execution outcome

Implemented in the existing draft PR branch; 206 unit/widget tests, clean analyzer, native detector/UI integration on iPhone13 and offline Android emulator, plus signed normal iOS build. Independent review's three Important findings fixed and re-reviewed. Actual EN/ZH engineering captures included. Completion of implementation is separate from release acceptance: real provider authorization/HEIC, iPad compatibility, final Store size/navigation/screens/video, unused version/build and signing/upgrade QA remain explicitly pending in docs/release/next-photo-finder/verification.md. No automatic submission or formal release.
