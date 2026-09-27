# Yard Ops

Portfolio yard execution application with a live integration to the LTL Planner.

## Demonstrates

- yard-board state and gate/dock workflow
- Angular 22 tablet-friendly operations UI
- .NET 10 API
- optional read-only Alvys Trailers Search
- synchronous Yard -> LTL candidate lookup
- asynchronous Yard -> LTL integration events
- HMAC-SHA256 payload signatures
- idempotent downstream event handling
- outbox-style retry with bounded exponential backoff so local yard actions do not depend on immediate LTL availability

The public demo uses synthetic equipment and operational data by default.
