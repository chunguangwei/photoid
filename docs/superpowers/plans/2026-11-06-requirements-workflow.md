# Requirements Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a visible, reproducible requirements-to-photo workflow with local OCR and real delivery checks.
**Architecture:** Preserve ApplicationTaskStore and current editor/export. Add conservative Dart parsing and a native OCR channel (Vision iOS, bundled ML Kit Android), provenance tied to evidence/spec versions, a normal editable demo task and a read-only overview.
**Tech Stack:** Flutter/Dart, Swift Vision, Kotlin ML Kit, existing image/archive packages.
**Spec:** docs/superpowers/specs/2026-11-06-requirements-workflow-design.md

## Global Constraints
- Preserve all existing tools, original Bundle ID, iOS 15.5 / Android API 26, bilingual/light/dark UI.
- No accounts/cloud OCR/ads/paid services; never claim official certification or acceptance.
- Up to five outputs; keep schemaVersion 1 backwards readable and current export snapshot checks.
- Never submit a new build automatically. Preserve existing user Info.plist edits.

## Review Focus
- Ambiguous or conflicting numbers must not silently become accepted requirements (Task 1 parser tests).
- Replaced evidence and changed specs must invalidate prior confirmation (Task 2 store tests).
- Corrupt/missing output cannot be green because metadata says ready (Task 3 service tests).
- OCR completing after navigation/replacement cannot modify a task (Task 4 widget tests).
- Repeated demo creation or interruption must not duplicate/contaminate user tasks (Task 2 tests).

### Task 1: Conservative requirements parser
**Files:** Create lib/services/requirements_parser.dart, test/requirements_parser_test.dart.
**Interfaces:** parseRequirements(String text) -> RequirementsDraft with dimension/KB/background candidates, matched excerpts and unsupported-unit/format warnings. Candidate values remain unconfirmed.
- [ ] Write tests for Chinese/English width-height, 480×640 ambiguity, 20–100 KB, max-only 100 KB, multiple/conflicting fields and unsupported mm/MB/PNG.
- [ ] Run flutter test test/requirements_parser_test.dart; observe missing implementation failure.
- [ ] Implement bounded deterministic parser without guessed defaults or unrelated numbers.
- [ ] Run same command; expect all pass; commit.

### Task 2: Provenance and offline demo
**Files:** Modify lib/models/application_task.dart, lib/services/application_task_store.dart, lib/services/application_delivery.dart; create lib/services/demo_task.dart, assets/demo/{portrait.jpg,requirements.png,LICENSE.md}; tests test/requirements_provenance_test.dart, test/demo_task_test.dart.
**Interfaces:** optional OutputRequirementSource(excerpt,evidenceRevision,specFingerprint,confirmed); store.confirmOutputSource(... expectedEvidenceRevision); store.createDemo(...) uses one serialized atomic directory transaction, stable marker and validated reusable task.
- [ ] Write tests for legacy JSON, renamed output retaining confirmation, changed spec/evidence invalidation, stale confirmation rejection, repeat/rebuild demo and failed creation rollback.
- [ ] Run targeted tests; expect failures for missing APIs.
- [ ] Implement provenance and demo transaction; add licensed source photo and fictional requirements fixture; do not pre-complete outputs.
- [ ] Include provenance status in JSON/TXT exports without adding full evidence/source images.
- [ ] Run targeted tests and existing task/delivery tests; expect all pass; commit.

### Task 3: Actual delivery overview
**Files:** Create lib/services/delivery_overview.dart, lib/pages/delivery_overview_page.dart; modify application_task_page.dart; test/delivery_overview_test.dart.
**Interfaces:** inspectTaskDelivery(task,store) -> sequential per-output inspection/status; overview callbacks navigate to existing requirement/editor operations and refresh on return.
- [ ] Test not-ready, missing, corrupt, wrong-size and valid file, stale snapshots and five-item bound.
- [ ] Run red; implement actual byte checks with bounded reads and version guard.
- [ ] Add responsive cards with requested/actual dimensions, exact bytes/KB, selected background separately labelled, excerpts and status; no cached export authorization.
- [ ] Run service/widget tests; commit.

### Task 4: Local OCR and confirmation UI
**Files:** Create lib/services/requirements_ocr.dart, lib/pages/requirements_import_page.dart; modify ios/Runner/AppDelegate.swift, android/app/src/main/kotlin/cn/wcg/photoid/MainActivity.kt, android/app/build.gradle.kts, application_task_page.dart; l10n ARBs/generated files; test/requirements_import_test.dart.
**Interfaces:** RequirementsOcr.recognize(path) -> Future<String>, injectable; confirmation returns a PhotoSpec, output filename, excerpt after explicit confirmation. Save binds current evidence revision.
- [ ] Test empty/failed recognition, user cancellation, multiple candidates, mandatory field completion, unsupported formats, async disposal and replaced evidence.
- [ ] Observe red; implement Vision asynchronous image processing and bundled Chinese/Latin ML Kit, close recognizers and bound input.
- [ ] Implement candidate selection with original text/image, editable fields, explicit width/height and JPEG confirmation, no auto-application.
- [ ] Wire importing from existing/new evidence, cap five and stale evidence checks; run tests, analyzer and native builds; commit.

### Task 5: First use and regression verification
**Files:** Modify home_page.dart, application_tasks_page.dart, splash_page.dart, main.dart, iOS display strings; adjust startup tests; create test/requirements_workflow_ui_test.dart.
- [ ] Test demo affordance, recent task, non-blocking first frame, existing tools reachable at 320pt / 130%, EN/ZH light/dark.
- [ ] Observe red; remove timed splash gate, retain real editor progress/cancel/retry, add demo and recent task UI with lifecycle refresh.
- [ ] Run full flutter test and flutter analyze; build iOS simulator and release Android; inspect native OCR build output; commit.

### Task 6: Independent review and release evidence
**Files:** docs/release/next-requirements-workflow/{verification.md,review-notes-en.txt,changes.md}.
- [ ] Obtain independent whole-change review, address material defects with regression tests.
- [ ] Verify actual connected devices, never substitute startup for full iPad interaction. Record unavailable devices/blockers accurately.
- [ ] Capture actual finished EN/ZH screens/video if device interaction available; otherwise record pending items, never fabricate evidence.
- [ ] Prepare accurate review notes and privacy changes, no auto resubmission. Commit final validation records and report concrete remaining gaps.
