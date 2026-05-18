package indexer

import (
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/Adelodunpeter25/cmdp/daemon/internal/utils"
)

type App struct {
	Name     string
	Path     string
	IconPath string
	LastOpened time.Time
	Frequency  int
}

// Scan looks for .app bundles in the given directories
func Scan(dirs []string) ([]App, error) {
	var apps []App

	for _, dir := range dirs {
		if err := scanDirectory(dir, &apps); err != nil {
			return nil, err
		}
	}

	return apps, nil
}

func scanDirectory(dir string, apps *[]App) error {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil // Skip folders we can't access
	}

	for _, entry := range entries {
		path := filepath.Join(dir, entry.Name())

		info, err := entry.Info()
		if err != nil {
			continue
		}

		// Follow symlinks to directories
		if info.Mode()&os.ModeSymlink != 0 {
			resolved, err := filepath.EvalSymlinks(path)
			if err != nil {
				continue
			}
			resolvedInfo, err := os.Stat(resolved)
			if err != nil {
				continue
			}
			if resolvedInfo.IsDir() {
				if err := scanDirectory(resolved, apps); err != nil {
					return err
				}
			}
			continue
		}

		if !info.IsDir() {
			continue
		}

		// We only care about .app bundles
		if strings.HasSuffix(path, ".app") {
			name, iconFile := utils.ParseAppInfo(path)

			// Fallback to filename if parser fails or returns empty
			if name == "" || name == ".app" {
				name = strings.TrimSuffix(filepath.Base(path), ".app")
			}

			iconPath := ""
			if iconFile != "" {
				// Icons are typically in Contents/Resources/
				// If no extension, append .icns
				if !strings.HasSuffix(iconFile, ".icns") {
					iconFile += ".icns"
				}
				iconPath = filepath.Join(path, "Contents", "Resources", iconFile)

				// Verify icon exists
				if _, err := os.Stat(iconPath); err != nil {
					iconPath = "" // Reset if file not found
				}
			}

			*apps = append(*apps, App{
				Name:     name,
				Path:     path,
				IconPath: iconPath,
			})
			continue // Don't look inside the app bundle
		}

		if err := scanDirectory(path, apps); err != nil {
			return err
		}
	}

	return nil
}
