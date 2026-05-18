package indexer

import (
	"sync"
	"time"
)

type Manager struct {
	db     *DB
	apps   []App
	mu     sync.RWMutex
	dirs   []string
}

func NewManager(db *DB, dirs []string) *Manager {
	return &Manager{
		db:   db,
		dirs: dirs,
	}
}

// Start performs the initial scan and loads data from DB
func (m *Manager) Start() error {
	// 1. Try to load from DB first for instant startup
	apps, err := m.db.LoadApps()
	if err == nil && len(apps) > 0 {
		m.mu.Lock()
		m.apps = apps
		m.mu.Unlock()
	}

	// 2. Perform a fresh scan in the background
	go m.refresh()

	return nil
}

func (m *Manager) refresh() {
	// Concurrent scanning of different directories
	var wg sync.WaitGroup
	var allApps []App
	var mu sync.Mutex

	for _, dir := range m.dirs {
		wg.Add(1)
		go func(d string) {
			defer wg.Done()
			apps, err := Scan([]string{d}) // Using our scan logic
			if err == nil {
				mu.Lock()
				allApps = append(allApps, apps...)
				mu.Unlock()
			}
		}(dir)
	}

	wg.Wait()

	// Update memory
	m.mu.Lock()
	m.apps = allApps
	m.mu.Unlock()

	// Update DB
	m.db.SaveApps(allApps)
}

func (m *Manager) GetApps() []App {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.apps
}

// UpdateFrecency should be called when an app is selected
func (m *Manager) UpdateFrecency(path string) error {
	_, err := m.db.conn.Exec(`
		UPDATE apps 
		SET last_opened = ?, frequency = frequency + 1 
		WHERE path = ?`, time.Now(), path)
	return err
}
