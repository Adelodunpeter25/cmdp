package indexer

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/Adelodunpeter25/cmdp/daemon/internal/utils"
)

type App struct {
	Name     string
	Path     string
	IconPath string
}

// Scan looks for .app bundles in the given directories
func Scan(dirs []string) ([]App, error) {
	var apps []App

	for _, dir := range dirs {
		err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return nil // Skip folders we can't access
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

				apps = append(apps, App{
					Name:     name,
					Path:     path,
					IconPath: iconPath,
				})
				return filepath.SkipDir // Don't look inside the app bundle
			}
			return nil
		})
		if err != nil {
			return nil, err
		}
	}

	return apps, nil
}
