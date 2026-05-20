package main

import (
	"C"
	"encoding/json"
	"log"
	"os"
	"path/filepath"
	"sync"

	"github.com/Adelodunpeter25/cmdp/daemon/internal/indexer"
	"github.com/Adelodunpeter25/cmdp/daemon/internal/search"
)

var (
	manager *indexer.Manager
	once    sync.Once
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
			filepath.Join(homeDir, "Applications"),
			filepath.Join(homeDir, "Documents"),
			filepath.Join(homeDir, "Downloads"),
			filepath.Join(homeDir, "Desktop"),
			filepath.Join(homeDir, "Developer"), // Often used by devs
		}

		manager = indexer.NewManager(db, dirs)
		if err := manager.Start(); err != nil {
			log.Printf("Bridge: Failed to start manager: %v", err)
			return
		}

		// go manager.Watch() // Temporarily disable watch during refactor if needed, or update it
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
	results := search.Items(goQuery, items)

	// Convert results to JSON for easy parsing in Swift
	jsonData, err := json.Marshal(results)
	if err != nil {
		return C.CString("[]")
	}

	return C.CString(string(jsonData))
}

// Mark an app as selected to update its frecency score.
//export MarkSelected
func MarkSelected(path *C.char) {
	if manager == nil {
		return
	}
	goPath := C.GoString(path)
	manager.UpdateFrecency(goPath)
}

func main() {
	// We need an empty main for c-archive, but it won't be called.
}
