# Architectural Decisions: cmd + p

This document outlines the core architectural decisions for the "cmd + p" launcher clone.

## 1. Core Architecture: Hybrid Swift + Go
- **Swift (Frontend):** Responsible for the UI, macOS native windowing, the search bar, and rendering results. Provides a native macOS user experience.
- **Go (Backend/Engine):** Responsible for performance-critical tasks: disk scanning, indexing, searching, and ranking.

## 2. Search Mechanism: Persistent In-Memory Index
- **Initial Scan:** On application launch, the Go engine performs a fast scan of key directories (e.g., `/Applications`, `/System/Applications`, `~/Applications`).
- **Memory-First:** The file list is stored in RAM for sub-10ms search response times.
- **Background Updates:** Uses filesystem watchers (via `fsnotify` in Go) to keep the index fresh without full rescans.

## 3. Search Ranking: Strict Fuzzy + Prefix Match
- Results are ranked strictly based on:
    1. **Exact Name Match:** Items matching the query exactly are prioritized.
    2. **Prefix Match:** Items starting with the query are ranked higher.
    3. **Fuzzy Score:** The base relevance score provided by the fuzzy matching algorithm.
- Frecency (Frequency/Recency) was removed to ensure a deterministic and predictable search experience.

## 4. Communication: C-Archive (cgo)
- The Go engine will be compiled into a static C-library (`.a` file).
- Swift will link against this library to call search functions directly, eliminating the latency and overhead of IPC (Inter-Process Communication) or network sockets.

## 5. Performance Inspiration: fff (Fast File Finder)
- We aim to replicate the efficiency of the `fff` project by prioritizing minimal memory footprint and zero-latency search results through optimized data structures and persistent indexing.
