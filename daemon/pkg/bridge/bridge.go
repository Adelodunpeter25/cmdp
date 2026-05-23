package main

import (
	"C"
	"encoding/json"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/Adelodunpeter25/cmdp/daemon/internal/indexer"
	"github.com/Adelodunpeter25/cmdp/daemon/internal/ps"
	"github.com/Adelodunpeter25/cmdp/daemon/internal/search"
)

var (
	manager      *indexer.Manager
	statsManager *ps.StatsManager
	once         sync.Once
)

// Initialize the Go engine. This will be called from Swift.
//export InitEngine
func InitEngine() {
	once.Do(func() {
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
				if entry.IsDir() && !strings.HasPrefix(entry.Name(), ".") {
					path := filepath.Join(homeDir, entry.Name())
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

func main() {
	// We need an empty main for c-archive, but it won't be called.
}
