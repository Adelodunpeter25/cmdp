package indexer

import (
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/fsnotify/fsnotify"
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
				if event.Op&fsnotify.Create == fsnotify.Create {
					if info, err := os.Stat(event.Name); err == nil && info.IsDir() {
						addRecursive(event.Name)
					}
				}
				if event.Op&(fsnotify.Create|fsnotify.Write|fsnotify.Remove|fsnotify.Rename) != 0 {
					log.Printf("Filesystem change detected: %s, refreshing index...", event.Name)
					m.refresh()
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
