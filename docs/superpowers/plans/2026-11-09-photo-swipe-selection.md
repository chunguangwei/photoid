# Fix iPhone batch swipe selection

User reports that the library batch picker cannot swipe-select. Current choosePhotos presents PHPicker with ordered multi-tap selection only. There is no app-owned gesture implementation; continuous/continuousAndOrdered deliver changes continuously and are not a swipe-enabling flag (Apple docs).

Implementer choice under delegated UX scope: add an iOS PhotoKit grid, opened only from choosePhotos, supporting a horizontal one-finger selection sweep and long-press drag, range reversal, deselection, 500-item cap and edge autoscroll. Vertical swipes scroll normally. Show short gesture hint, selected count and explicit confirm/cancel. Provide a system-picker alternative; denied/restricted photo permission falls back to PHPicker. Respect limited library access and provide a manage-visible-photos control. No full access requirement, identity index, background library analysis or uploads. Thumbnail loading is lazy; full data reads only for confirmed selection, bounded and cancellable, preserving original fingerprint checks. Existing cold-start code stays unchanged.

1. RED/GREEN pure Swift range-selection tests (forward/reverse/shrink/deselect/cap/preexisting).
2. Native grid and scoped permission lifecycle; connect PHAsset session entries and bounded reads.
3. Compile, run existing native processing regressions/full Flutter checks; update docs/metadata and build number.
4. Sign and reinstall normal app in place, no physical uninstall; sync branch and candidate artifacts. Actual physical gesture test remains explicit if mirroring cannot operate the device.
