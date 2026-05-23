package indexer

import (
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/fsnotify/fsnotify"
	"github.com/Adelodunpeter25/cmdp/daemon/internal/utils"
)

func (m *Manager) Watch() {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		log.Fatal(err)
	}
	defer watcher.Close()

	var watchedMu sync.Mutex
	watched := make(map[string]struct{})

	addWatch := func(path string) {
		watchedMu.Lock()
		if _, exists := watched[path]; exists {
			watchedMu.Unlock()
			return
		}
		watched[path] = struct{}{}
		watchedMu.Unlock()

		if err := watcher.Add(path); err != nil {
			log.Printf("Error watching directory %s: %v", path, err)
		}
	}

	isInsideAppBundle := func(path string) bool {
		cleanPath := filepath.Clean(path)
		if strings.HasSuffix(cleanPath, ".app") {
			return false
		}
		return strings.Contains(cleanPath, ".app"+string(os.PathSeparator))
	}

	addRecursive := func(root string) {
		var walk func(string) error
		walk = func(path string) error {
			if utils.ShouldIgnore(path, root) {
				return nil
			}
			info, err := os.Lstat(path)
			if err != nil {
				return nil
			}

			// Follow symlinks to directories
			if info.Mode()&os.ModeSymlink != 0 {
				resolved, err := filepath.EvalSymlinks(path)
				if err != nil {
					return nil
				}
				info, err = os.Stat(resolved)
				if err != nil {
					return nil
				}
				if !info.IsDir() {
					return nil
				}
				path = resolved
			}

			if !info.IsDir() {
				return nil
			}

			addWatch(path)
			if strings.HasSuffix(path, ".app") && path != root {
				return nil
			}

			entries, err := os.ReadDir(path)
			if err != nil {
				return nil
			}
			for _, entry := range entries {
				if err := walk(filepath.Join(path, entry.Name())); err != nil {
					return err
				}
			}
			return nil
		}
		if err := walk(root); err != nil {
			log.Printf("Error walking directory %s: %v", root, err)
		}
	}

	// Debounced refresh: coalesce rapid-fire FS events into a single refresh.
	// A burst of events from a single app install (dozens of creates/writes)
	// collapses into one refresh fired 500ms after the last event.
	const debounceDelay = 500 * time.Millisecond
	var debounceTimer *time.Timer
	var debounceMu sync.Mutex

	scheduleRefresh := func() {
		debounceMu.Lock()
		defer debounceMu.Unlock()
		if debounceTimer != nil {
			debounceTimer.Reset(debounceDelay)
		} else {
			debounceTimer = time.AfterFunc(debounceDelay, func() {
				log.Println("Manager: Debounced refresh triggered by filesystem event")
				m.refresh()
				debounceMu.Lock()
				debounceTimer = nil
				debounceMu.Unlock()
			})
		}
	}

	go func() {
		for {
			select {
			case event, ok := <-watcher.Events:
				if !ok {
					return
				}
				if isInsideAppBundle(event.Name) {
					continue
				}
				if utils.ShouldIgnore(event.Name, "") {
					continue
				}
				if event.Op&fsnotify.Create == fsnotify.Create {
					if info, err := os.Stat(event.Name); err == nil && info.IsDir() {
						if !utils.ShouldIgnore(event.Name, "") {
							addRecursive(event.Name)
						}
					}
				}
				if event.Op&(fsnotify.Create|fsnotify.Write|fsnotify.Remove|fsnotify.Rename) != 0 {
					log.Printf("Filesystem change detected: %s, scheduling debounced refresh...", event.Name)
					scheduleRefresh()
				}
			case err, ok := <-watcher.Errors:
				if !ok {
					return
				}
				log.Println("Watcher error:", err)
			}
		}
	}()

	for _, dir := range m.dirs {
		addRecursive(dir)
	}
	select {}
}
