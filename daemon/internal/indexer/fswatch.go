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

	addRecursive := func(root string) {
		err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return nil
			}
			if info.IsDir() {
				addWatch(path)
				if strings.HasSuffix(path, ".app") && path != root {
					return filepath.SkipDir
				}
			}
			return nil
		})
		if err != nil {
			log.Printf("Error walking directory %s: %v", root, err)
		}
	}

	done := make(chan bool)
	go func() {
		for {
			select {
			case event, ok := <-watcher.Events:
				if !ok {
					return
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
	<-done
}
