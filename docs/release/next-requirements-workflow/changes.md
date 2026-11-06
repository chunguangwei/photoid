# Next candidate — changes from rejected 1.1.0 (49)

| Previous behavior | New behavior | Reproduce |
|---|---|---|
| Start with an empty task and provide own materials | Public demo creates a real editable task with portrait and fictional EN/ZH requirement fixture | Home > Try a demo task |
| Requirement screenshot is reference only; all values entered manually | On-device OCR proposes candidates; explicit confirmation creates one output and a short editable source excerpt | Task > Extract requirements |
| Per-file checks primarily opened individually | Delivery overview rereads actual files and compares requested/measured properties for all outputs | Task > Delivery overview |
| Fixed six-second launch countdown | Home appears without the timer; segmentation model prewarms after first frame | Launch app |
| No linkage between source excerpt and revised requirements | Evidence/spec revision checks invalidate earlier confirmation and report stale provenance | Replace evidence / edit requirements |

These are product changes, not a guarantee of 4.3 acceptance. The latest Apple clarification request remains unanswered as of the last page inspection. No next build was uploaded or resubmitted by this work.

Internal validation builds retain pubspec 1.1.0+49. They are NOT a replacement for the build already reviewed. Assign and verify a new version/build before distribution; final screenshots/video must show that exact binary.
