# Architectural Decisions: cmd + p

This document outlines the core architectural decisions for the "cmd + p" launcher clone.

## 1. Core Architecture: Hybrid Swift + Go
- **Swift (Frontend):** Responsible for the UI, macOS native windowing, the search bar, and rendering results. Provides a native macOS user experience.
- **Go (Backend/Engine):** Responsible for performance-critical tasks: disk scanning, indexing, searching, and ranking.

## 2. Search Mechanism: Persistent In-Memory Index
- **Initial Scan:** On application launch, the Go engine performs a fast scan of key directories (e.g., `/Applications`, `/System/Applications`, `~/Applications`).
- **Memory-First:** The file list is stored in RAM for sub-10ms search response times.
- **Background Updates:** Uses filesystem watchers (via `fsnotify` in Go) to keep the index fresh without full rescans.

## 3. "Smart" Ranking: Frecency
- Results are ranked based on a combination of **Frequency** (how often an item is selected) and **Recency** (how recently it was selected).
- The Go engine will maintain a small persistent database (e.g., SQLite or a KV store) to track usage metrics.

## 4. Communication: C-Archive (cgo)
- The Go engine will be compiled into a static C-library (`.a` file).
- Swift will link against this library to call search functions directly, eliminating the latency and overhead of IPC (Inter-Process Communication) or network sockets.

## 5. Performance Inspiration: fff (Fast File Finder)
- We aim to replicate the efficiency of the `fff` project by prioritizing minimal memory footprint and zero-latency search results through optimized data structures and persistent indexing.
