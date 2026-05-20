package indexer

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/Adelodunpeter25/cmdp/daemon/internal/utils"
)

// Crawler handles recursive directory scanning for apps and folders
type Crawler struct {
	maxDepth int
}

func NewCrawler(maxDepth int) *Crawler {
	return &Crawler{
		maxDepth: maxDepth,
	}
}

// Scan performs a recursive scan of the given directories
func (c *Crawler) Scan(dirs []string) ([]IndexItem, error) {
	var items []IndexItem

	for _, dir := range dirs {
		err := c.walk(dir, dir, 0, &items)
		if err != nil {
			// Log error but continue with other directories
			continue
		}
	}

	return items, nil
}

func (c *Crawler) walk(root string, path string, depth int, items *[]IndexItem) error {
	if depth >= c.maxDepth {
		return nil
	}

	if utils.ShouldIgnore(path, root) {
		return nil
	}

	entries, err := os.ReadDir(path)
	if err != nil {
		return nil // Skip directories we can't read
	}

	for _, entry := range entries {
		fullPath := filepath.Join(path, entry.Name())

		if utils.ShouldIgnore(fullPath, root) {
			continue
		}

		info, err := entry.Info()
		if err != nil {
			continue
		}

		// Handle symlinks
		if info.Mode()&os.ModeSymlink != 0 {
			resolved, err := filepath.EvalSymlinks(fullPath)
			if err != nil {
				continue
			}
			resolvedInfo, err := os.Stat(resolved)
			if err != nil {
				continue
			}
			if resolvedInfo.IsDir() {
				// For symlinks, we only care if they point to an .app
				if strings.HasSuffix(resolved, ".app") {
					name, _ := utils.ParseAppInfo(resolved)
					if name == "" {
						name = strings.TrimSuffix(filepath.Base(resolved), ".app")
					}
					*items = append(*items, IndexItem{
						Name: name,
						Path: fullPath,
						Type: TypeApp,
					})
				}
			}
			continue
		}

		if !info.IsDir() {
			continue
		}

		// Check if it's an .app bundle
		// We only consider it an app if it's a directory ending in .app
		if strings.HasSuffix(entry.Name(), ".app") {
			name, iconFile := utils.ParseAppInfo(fullPath)
			if name == "" || name == ".app" {
				name = strings.TrimSuffix(entry.Name(), ".app")
			}

			iconPath := ""
			if iconFile != "" {
				if !strings.HasSuffix(iconFile, ".icns") {
					iconFile += ".icns"
				}
				iconPath = filepath.Join(fullPath, "Contents", "Resources", iconFile)
				if _, err := os.Stat(iconPath); err != nil {
					iconPath = ""
				}
			}

			*items = append(*items, IndexItem{
				Name:     name,
				Path:     fullPath,
				IconPath: iconPath,
				Type:     TypeApp,
			})
			continue // Don't crawl inside app bundles
		}

		// It's a regular directory
		*items = append(*items, IndexItem{
			Name: entry.Name(),
			Path: fullPath,
			Type: TypeFolder,
		})

		// Recursively scan subdirectories
		if depth+1 < c.maxDepth {
			if err := c.walk(root, fullPath, depth+1, items); err != nil {
				continue
			}
		}
	}

	return nil
}
