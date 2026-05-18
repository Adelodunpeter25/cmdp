package main

import (
	"log"
	"os"
	"path/filepath"

	"github.com/Adelodunpeter25/cmdp/search-daemon/internal/indexer"
)

func main() {
	// Define the database path
	homeDir, err := os.UserHomeDir()
	if err != nil {
		log.Fatal("Could not find home directory:", err)
	}
	dbPath := filepath.Join(homeDir, ".cmdp.db")

	// Open/Create the database
	db, err := indexer.OpenDB(dbPath)
	if err != nil {
		log.Fatal("Could not open database:", err)
	}

	// Directories to scan
	dirs := []string{
		"/Applications",
		"/System/Applications",
		filepath.Join(homeDir, "Applications"),
	}

	// Initialize the Manager
	manager := indexer.NewManager(db, dirs)

	// Start the initial load and background scan
	log.Println("Starting search-daemon engine...")
	if err := manager.Start(); err != nil {
		log.Fatal("Failed to start manager:", err)
	}

	// Start the filesystem watcher in a goroutine
	go manager.Watch()

	// For the CLI version (cmd/daemon), we just keep it running
	// In the bridge version, this will be handled by the Swift app's lifecycle
	log.Println("Engine is running. Press Ctrl+C to stop.")
	select {}
}
