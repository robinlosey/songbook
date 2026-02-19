# Architecture Overview

High-level data flow of the Songbook app's data management system.

```mermaid
flowchart TB
    subgraph app [App Layer]
        songbookApp[songbookApp]
        ContentView[ContentView]
    end

    subgraph sync [Sync Layer]
        SyncManager["SyncManager (Observable)"]
        SongSyncService["SongSyncService (Actor)"]
        ResourceDownloader["ResourceDownloader (Actor)"]
        NetworkMonitor["NetworkMonitor (Observable)"]
    end

    subgraph data [Data Layer]
        CSVParser["CSVParser (Struct)"]
        SongDTO[SongDTO]
        DataManager["DataManager (Singleton)"]
    end

    subgraph storage [Storage Layer]
        StoreA[(Store A)]
        StoreB[(Store B)]
        PDFs[PDFs]
        MP3s[MP3s]
    end

    songbookApp --> SyncManager
    songbookApp --> ContentView
    ContentView --> DataManager

    SyncManager --> SongSyncService
    SongSyncService --> NetworkMonitor
    SongSyncService --> ResourceDownloader
    SongSyncService --> CSVParser
    SongSyncService --> DataManager

    CSVParser --> SongDTO
    SongDTO --> DataManager

    DataManager --> StoreA
    DataManager --> StoreB
    ResourceDownloader --> PDFs
    ResourceDownloader --> MP3s
```

## Components

| Component | Type | Responsibility |
|-----------|------|----------------|
| `SyncManager` | Observable | UI-facing wrapper, triggers sync, forwards state |
| `SongSyncService` | Actor | Orchestrates sync flow, version checks, A/B swap |
| `ResourceDownloader` | Actor | Queues and downloads PDF/MP3 files with retry |
| `NetworkMonitor` | Observable | Tracks connectivity and metered status |
| `CSVParser` | Struct | Parses CSV into SongDTO array |
| `DataManager` | Singleton | Manages CoreData stores, A/B pattern |

