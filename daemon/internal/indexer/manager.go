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

	// Update memory with scanned apps as fallback
	m.mu.Lock()
	m.apps = allApps
	m.mu.Unlock()

	// Update DB
	m.db.SaveApps(allApps)

	// Reload from DB to preserve frecency data in memory
	if appsWithFrecency, err := m.db.LoadApps(); err == nil {
		m.mu.Lock()
		m.apps = appsWithFrecency
		m.mu.Unlock()
	}
}

func (m *Manager) GetApps() []App {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.apps
}

// UpdateFrecency should be called when an app is selected
func (m *Manager) UpdateFrecency(path string) error {
	now := time.Now()

	m.mu.Lock()
	for i := range m.apps {
		if m.apps[i].Path == path {
			m.apps[i].Frequency++
			m.apps[i].LastOpened = now
			break
		}
	}
	m.mu.Unlock()

	_, err := m.db.conn.Exec(`
		UPDATE apps 
		SET last_opened = ?, frequency = frequency + 1 
		WHERE path = ?`, now, path)
	return err
}
