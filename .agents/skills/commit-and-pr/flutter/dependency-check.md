# Flutter dependency check

When `pubspec.yaml` is in the diff and new packages have been added:

1. List each newly added package name and pinned version.
2. Surface this checklist for the developer to confirm before committing:
   - [ ] Verified on pub.dev that version `<x.y.z>` was published at least 14 days ago
   - [ ] Checked the package's GitHub repo for unusual recent commits, new maintainers, or activity spikes
3. Do NOT block the commit automatically — this is a developer confirmation step, not an automated gate.
