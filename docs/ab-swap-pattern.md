# A/B Database Swap Pattern

Safe atomic database updates using two CoreData stores. The active store serves the UI while the inactive store is rebuilt with new data.

```mermaid
sequenceDiagram
    participant Sync as SongSyncService
    participant DM as DataManager
    participant Active as Store A - Active
    participant Inactive as Store B - Inactive

    Note over Sync,Inactive: Normal Sync Flow

    Sync->>Active: 1. Fetch favorite filenames
    Active-->>Sync: Set of filenames

    Sync->>Inactive: 2. Flush all entities
    Sync->>Inactive: 3. Populate with new songs + favorites

    alt Success
        Sync->>DM: 4. switchToInactiveStore
        Note over Active,Inactive: Stores swap roles
        DM->>Inactive: Now serves UI
    else Failure
        Note over Active: Remains Active
        Note over Inactive: Discarded on next sync
    end
```

## How It Works

1. **Favorites Preservation**: Before rebuilding, we extract favorite filenames from the active store
2. **Flush Inactive**: Clear all data from the inactive store
3. **Populate**: Insert new songs from CSV, reapplying favorites by filename match
4. **Atomic Swap**: On success, flip `currentDB` in UserDefaults and reload container
5. **Automatic Rollback**: On failure, the active store remains untouched

## Crash Recovery

- A `buildInProgress` flag is set before building starts
- If the app restarts with this flag set, we flush the inactive store
- Ensures no partial data ever reaches production

## UserDefaults Keys

| Key | Purpose |
|-----|---------|
| `currentDB` | "A" or "B" - which store is active |
| `buildInProgress` | Crash recovery flag |
| `storedCSVVersion` | Version of current database |

