# Project Instructions (cmdp)

## Workflow Mandates
- **Always Commit:** After every successful modification, commit the changes with a clear and concise message.
- **Always Build:** Build the modified component (rebuild the Go backend when Go files change, and rebuild the Swift app when Swift files change). Do not rebuild the Go backend if only Swift files were changed.

## Build Procedures

### Backend (Go Daemon)
The backend must be built as a static library for the Swift app to link against.
```bash
cd daemon && make
```
*Note: Ensure the output `libsearch.a` is placed in `daemon/build/`.*

### Frontend (Swift App)
The frontend depends on the backend's static library.
```bash
cd cmdp && swift build
```

## Engineering Standards
- Follow the existing architecture: Go for indexing/search, Swift for UI/System integration.
- Ensure `cgo` bridges in `daemon/pkg/bridge/bridge.go` are kept in sync with `cmdp/Sources/CLibSearch/include/libsearch.h`.
- Adhere to the established UI theme in `cmdp/Sources/cmdp/Utils/Theme.swift`.
