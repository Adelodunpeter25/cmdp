package indexer

import (
	"log"
	"path/filepath"

	"github.com/fsnotify/fsnotify"
)

func (m *Manager) Watch() {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		log.Fatal(err)
	}
	defer watcher.Close()

	done := make(chan bool)
	go func() {
		for {
			select {
			case event, ok := <-watcher.Events:
				if !ok {
					return
				}
				// If something changes in the watched folders, trigger a refresh
				// We filter for .app movements or deletions
				if filepath.Ext(event.Name) == ".app" || event.Op&fsnotify.Write == fsnotify.Write {
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
		err = watcher.Add(dir)
		if err != nil {
			log.Printf("Error watching directory %s: %v", dir, err)
		}
	}
	<-done
}
