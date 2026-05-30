package main

import (
	"C"
	"encoding/json"
	"log"
	"os"
	"path/filepath"
	"sync"
	"syscall"

	"github.com/Adelodunpeter25/cmdp/daemon/internal/clipboard"
	"github.com/Adelodunpeter25/cmdp/daemon/internal/indexer"
	"github.com/Adelodunpeter25/cmdp/daemon/internal/ps"
	"github.com/Adelodunpeter25/cmdp/daemon/internal/search"
	"github.com/Adelodunpeter25/cmdp/daemon/internal/shelf"
	"github.com/Adelodunpeter25/cmdp/daemon/internal/utils"
)

var (
	manager          *indexer.Manager
	statsManager     *ps.StatsManager
	shelfManager     *shelf.Manager
	clipboardManager *clipboard.Manager
	once             sync.Once
)

func increaseFdLimit() {
	var rLimit syscall.Rlimit
	if err := syscall.Getrlimit(syscall.RLIMIT_NOFILE, &rLimit); err == nil {
		rLimit.Cur = rLimit.Max
		if err := syscall.Setrlimit(syscall.RLIMIT_NOFILE, &rLimit); err != nil {
			log.Printf("Bridge: Failed to set FD limit: %v", err)
		} else {
			log.Printf("Bridge: Increased FD limit to %d", rLimit.Cur)
		}
	}
}

// Initialize the Go engine. This will be called from Swift.
//export InitEngine
func InitEngine() {
	once.Do(func() {
		increaseFdLimit()
		homeDir, err := os.UserHomeDir()
		if err != nil {
			log.Printf("Bridge: Failed to get home dir: %v", err)
			return
		}
		dbPath := filepath.Join(homeDir, ".cmdp.db")

		db, err := indexer.OpenDB(dbPath)
		if err != nil {
			log.Printf("Bridge: Failed to open DB: %v", err)
			return
		}

		shelfManager, err = shelf.NewManager(db, homeDir)
		if err != nil {
			log.Printf("Bridge: Failed to initialize shelf manager: %v", err)
		}

		clipboardManager = clipboard.NewManager(db)

		dirs := []string{
			"/Applications",
			"/System/Applications",
		}

		// Track added directories to avoid duplicates
		added := map[string]bool{
			"/Applications":        true,
			"/System/Applications": true,
		}

		// Add user Applications if it exists and isn't a duplicate
		userApps := filepath.Join(homeDir, "Applications")
		if _, err := os.Stat(userApps); err == nil {
			dirs = append(dirs, userApps)
			added[userApps] = true
		}

		// Dynamically add all non-hidden directories in homeDir
		entries, err := os.ReadDir(homeDir)
		if err == nil {
			for _, entry := range entries {
				path := filepath.Join(homeDir, entry.Name())
				if entry.IsDir() && !utils.ShouldIgnore(path, homeDir) {
					// Skip directories already added or typically redundant
					name := entry.Name()
					if name == "Library" || added[path] {
						continue
					}
					dirs = append(dirs, path)
				}
			}
		}

		manager = indexer.NewManager(db, dirs)
		if err := manager.Start(); err != nil {
			log.Printf("Bridge: Failed to start manager: %v", err)
			return
		}

		statsManager = ps.NewStatsManager()
		log.Println("Bridge: Go Engine initialized successfully")
	})
}

// Search for items. Returns a JSON string of results.
// Swift is responsible for freeing the returned C string.
//export SearchApps
func SearchApps(query *C.char) *C.char {
	if manager == nil {
		return C.CString("[]")
	}

	goQuery := C.GoString(query)
	items := manager.GetItems()

	// Merge system commands into the search pool
	commands := indexer.GetCommands()
	allSearchItems := make([]indexer.IndexItem, 0, len(items)+len(commands))
	allSearchItems = append(allSearchItems, items...)
	allSearchItems = append(allSearchItems, commands...)

	results := search.Items(goQuery, allSearchItems)

	// Convert results to JSON for easy parsing in Swift
	jsonData, err := json.Marshal(results)
	if err != nil {
		return C.CString("[]")
	}

	return C.CString(string(jsonData))
}

// Search for files. Returns a JSON string of results.
// Swift is responsible for freeing the returned C string.
//export SearchFiles
func SearchFiles(query *C.char) *C.char {
	if manager == nil {
		return C.CString("[]")
	}

	goQuery := C.GoString(query)
	candidates, err := manager.SearchFiles(goQuery)
	if err != nil {
		log.Printf("Bridge: SearchFiles error: %v", err)
		return C.CString("[]")
	}

	results := search.Files(goQuery, candidates)

	jsonData, err := json.Marshal(results)
	if err != nil {
		return C.CString("[]")
	}

	return C.CString(string(jsonData))
}

// Reset the index by clearing the database.
//export ResetIndex
func ResetIndex() {
	if manager == nil {
		return
	}
	manager.Reset()
}

// GetSystemStats retrieves and returns overall system metrics and top processes as JSON.
//export GetSystemStats
func GetSystemStats() *C.char {
	if statsManager == nil {
		return C.CString("{}")
	}

	stats, err := statsManager.GetStats()
	if err != nil {
		log.Printf("Bridge: Failed to get system stats: %v", err)
		return C.CString("{}")
	}

	jsonData, err := json.Marshal(stats)
	if err != nil {
		return C.CString("{}")
	}

	return C.CString(string(jsonData))
}

// KillProcess terminates a process by PID.
// force = 0: SIGTERM (graceful)
// force = 1: SIGKILL (forceful)
//export KillProcess
func KillProcess(pid C.int, force C.int) C.int {
	p, err := os.FindProcess(int(pid))
	if err != nil {
		log.Printf("Bridge: Failed to find process %d: %v", pid, err)
		return 0
	}

	var sig syscall.Signal
	if force != 0 {
		sig = syscall.SIGKILL
	} else {
		sig = syscall.SIGTERM
	}

	if err := p.Signal(sig); err != nil {
		log.Printf("Bridge: Failed to send signal %v to process %d: %v", sig, pid, err)
		return 0
	}
	return 1
}

// AddToShelf copies a file to the shelf. Returns a JSON string of the added item or "{}" on failure.
//export AddToShelf
func AddToShelf(originalPath *C.char) *C.char {
	if shelfManager == nil {
		return C.CString("{}")
	}
	goPath := C.GoString(originalPath)
	item, err := shelfManager.Add(goPath)
	if err != nil {
		log.Printf("Bridge: AddToShelf error: %v", err)
		return C.CString("{}")
	}

	jsonData, err := json.Marshal(item)
	if err != nil {
		return C.CString("{}")
	}
	return C.CString(string(jsonData))
}

// GetShelfItems returns a JSON array string of all shelf items or "[]" on failure.
//export GetShelfItems
func GetShelfItems() *C.char {
	if shelfManager == nil {
		return C.CString("[]")
	}
	items, err := shelfManager.GetItems()
	if err != nil {
		log.Printf("Bridge: GetShelfItems error: %v", err)
		return C.CString("[]")
	}

	jsonData, err := json.Marshal(items)
	if err != nil {
		return C.CString("[]")
	}
	return C.CString(string(jsonData))
}

// RemoveFromShelf removes an item from the shelf by ID. Returns 1 on success, 0 on failure.
//export RemoveFromShelf
func RemoveFromShelf(id *C.char) C.int {
	if shelfManager == nil {
		return 0
	}
	goID := C.GoString(id)
	if err := shelfManager.Remove(goID); err != nil {
		log.Printf("Bridge: RemoveFromShelf error: %v", err)
		return 0
	}
	return 1
}

// GetClipboardItems returns a JSON array string of all clipboard items or "[]" on failure.
//export GetClipboardItems
func GetClipboardItems() *C.char {
	if clipboardManager == nil {
		return C.CString("[]")
	}
	items := clipboardManager.GetItems()
	jsonData, err := json.Marshal(items)
	if err != nil {
		return C.CString("[]")
	}
	return C.CString(string(jsonData))
}

// RemoveFromClipboard removes an item from the clipboard history by ID. Returns 1 on success, 0 on failure.
//export RemoveFromClipboard
func RemoveFromClipboard(id *C.char) C.int {
	if clipboardManager == nil {
		return 0
	}
	goID := C.GoString(id)
	if err := clipboardManager.Delete(goID); err != nil {
		log.Printf("Bridge: RemoveFromClipboard error: %v", err)
		return 0
	}
	return 1
}

// SaveClipboardItem saves an item to the clipboard history.
//export SaveClipboardItem
func SaveClipboardItem(content *C.char) {
	if clipboardManager == nil {
		return
	}
	goContent := C.GoString(content)
	clipboardManager.Save(goContent)
}

func main() {
	// We need an empty main for c-archive, but it won't be called.
}
