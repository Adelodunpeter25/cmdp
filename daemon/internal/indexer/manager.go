package indexer

import (
	"log"
	"sync"
	"time"
)

type Manager struct {
	db      *DB
	items   []IndexItem
	mu      sync.RWMutex
	dirs    []string
	crawler *Crawler
}

func NewManager(db *DB, dirs []string) *Manager {
	return &Manager{
		db:      db,
		dirs:    dirs,
		crawler: NewCrawler(5), // Set a reasonable max depth
	}
}

// Start performs the initial scan and loads data from DB
func (m *Manager) Start() error {
	// 1. Try to load from DB first for instant startup
	items, err := m.db.LoadItems()
	if err == nil && len(items) > 0 {
		m.mu.Lock()
		m.items = items
		m.mu.Unlock()
	}

	// 2. Perform a fresh scan in the background
	go m.refresh()

	return nil
}

func (m *Manager) refresh() {
	log.Println("Manager: Refreshing index...")
	start := time.Now()

	allItems, err := m.crawler.Scan(m.dirs)
	if err != nil {
		log.Printf("Manager: Scan error: %v", err)
		return
	}

	// Update memory with scanned items
	m.mu.Lock()
	m.items = allItems
	m.mu.Unlock()

	// Update DB
	if err := m.db.SaveItems(allItems); err != nil {
		log.Printf("Manager: Failed to save items to DB: %v", err)
	}

	log.Printf("Manager: Index refreshed in %v. Found %d items.", time.Since(start), len(allItems))
}

func (m *Manager) GetItems() []IndexItem {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.items
}

// Reset clears all items and the database, then triggers a fresh scan.
func (m *Manager) Reset() {
	m.mu.Lock()
	m.items = nil
	m.mu.Unlock()

	if err := m.db.DeleteAll(); err != nil {
		log.Printf("Manager: Failed to clear database: %v", err)
	}
	log.Println("Manager: Index reset successfully")

	// Trigger a fresh scan
	go m.refresh()
}
