# Core architecture

This layer contains provider-neutral business primitives. Native platform integrations should call these components rather than embedding policy in UI widgets.

Key invariants:
- token-aware cloud context
- explicit permissions
- manual payment confirmation
- local-first deterministic operations
- cross-device event/orchestration model
