# Simpler photo finder UX

User direction (2026-11-09): remove examples; choose a common spec or custom dimensions/KB; find suitable photos from a folder or many selected photos. Previous task/requirements/delivery-led flow was too complex. User delegates UX choices.

Decision: single clear target spec for the main flow, then choose a photo batch, then tap one to prepare. No task creation dialog or internal workflow terminology. Existing multi-output tasks remain secondary, manual single-photo/camera remains available. Keep the existing cold-start animation exactly; user reconfirmed no new or modified motion. Use system multi-photo pickers (do not promise unverified swipe gestures), scoped directory/file alternatives, local analysis, bounded original decoding. Technical details collapse by default; simple recommended/all grid and explicit adoption. Save a source-backed record atomically only on adoption. Preserve existing records and all underlying preparation features.

- [x] RED/GREEN: searchable preset picker (33 specs), custom entry, atomic source-backed record, session reranking without rescanning.
- [x] Direct home finder, simple target/source/results UI, preset entry also usable from task requirements; remove every public example creation entry.
- [x] Native scoped batch Photos picker (iOS PHPicker provider-on-demand, Android photo picker with SAF fallback), preserve limits/cancellation/file fingerprint checks.
- [x] Update UI/native regressions and current EN/ZH docs/metadata/captures; independent whole-change review, full verification and signed phone update. No automatic App Store submission/public release; invalidate old candidate packaging until rebuilt.

Verification: 216 unit/widget tests; clean analyzer; iPhone native 3 passed / UI skipped nonforeground; Android native 4 passed, EN/ZH captures inspected. Native picker/iPad/final store artwork remain explicit release QA, not inferred from fixture injection. Existing cold-start source unchanged.
