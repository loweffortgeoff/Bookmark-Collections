# Architecture Decisions

## Local-first SwiftData with private CloudKit mirroring

Every supported device keeps a complete local library. User mutations save to SwiftData before metadata or CloudKit work begins, so losing connectivity cannot lose a valid URL. CloudKit is a mirror of the private store rather than an online API dependency.

## One collection per bookmark

A bookmark belongs to zero or one collection. Favorite is an independent Boolean. This keeps the library model predictable while covering the primary organization flows; tags remain outside v1.

## Normalized URL identity and deterministic reconciliation

Tracking parameters, fragments, host casing, and default ports are normalized before identity comparison. Ordinary saves update or restore an existing normalized URL. If separate offline devices create different records, reconciliation keeps the earliest-created UUID, preserves Favorite with logical OR, applies the most recently modified title and collection, and removes redundant records.

## Soft deletion before permanent removal

Deletion first writes a timestamp and moves the bookmark to Recently Deleted. This makes deletion synchronizable and recoverable. Permanent deletion remains explicit and confirmed; aged deleted records can be purged after 30 days.

## Portable backups over proprietary archives

JSON is the lossless app backup, preserving identifiers and user-authored organization. Netscape bookmark HTML is the interoperability format. Preview binaries are excluded because they are derived cache data and can be enriched again.

## Share Extension uses the shared durable store

The extension and app use the same App Group SwiftData store and CloudKit container. The extension completes only after the local repository save succeeds. Metadata starts concurrently but never delays Save.

## System UI and no external dependencies

SwiftUI navigation, forms, file import/export, sharing, alerts, commands, and accessibility semantics are used throughout. The project intentionally avoids third-party libraries, analytics, telemetry, custom accounts, and sync servers.

## Honest sync health

CloudKit does not expose a trustworthy app-level “all records synced” timestamp. Settings therefore reports only account availability and actionable lookup errors; it never invents last-sync evidence.
