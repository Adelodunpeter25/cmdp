package indexer

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/Adelodunpeter25/cmdp/daemon/internal/utils"
)

// FileCrawler walks directories recursively to index files into SQLite.
type FileCrawler struct {
	db       *DB
	maxDepth int
	ignore   *utils.IgnoreChecker
}

// NewFileCrawler creates a new FileCrawler instance.
func NewFileCrawler(db *DB, maxDepth int) *FileCrawler {
	return &FileCrawler{
		db:       db,
		maxDepth: maxDepth,
		ignore:   utils.NewIgnoreChecker(),
	}
}

// Scan performs incremental scanning of file directories.
func (c *FileCrawler) Scan(dirs []string) error {
	visitedDirs := make(map[string]bool)

	for _, dir := range dirs {
		// Skip standard application directories for files indexing
		if dir == "/Applications" || dir == "/System/Applications" || strings.Contains(dir, ".app") {
			continue
		}
		_ = c.walk(dir, dir, 0, visitedDirs)
	}

	// Clean up states and files for directories that were deleted
	allStates, err := c.db.GetAllDirectoryStates()
	if err == nil {
		for cachedPath := range allStates {
			if !visitedDirs[cachedPath] {
				_ = c.db.DeleteFilesForParent(cachedPath)
				_ = c.db.DeleteDirectoryState(cachedPath)
			}
		}
	}

	return nil
}

func (c *FileCrawler) walk(root string, path string, depth int, visitedDirs map[string]bool) error {
	if depth >= c.maxDepth {
		return nil
	}

	// Prevent circular or duplicate visits
	if visitedDirs[path] {
		return nil
	}

	if c.ignore.ShouldIgnore(path, root) {
		return nil
	}

	// Never crawl inside application bundles
	if strings.HasSuffix(path, ".app") || strings.Contains(path, ".app/") {
		return nil
	}

	info, err := os.Stat(path)
	if err != nil {
		return nil
	}

	if !info.IsDir() {
		return nil
	}

	visitedDirs[path] = true

	entries, err := os.ReadDir(path)
	if err != nil {
		return nil
	}

	var subDirs []string
	var fileItems []IndexItem

	for _, entry := range entries {
		fullPath := filepath.Join(path, entry.Name())

		if c.ignore.ShouldIgnore(fullPath, root) {
			continue
		}

		if entry.IsDir() {
			// Do not walk into app bundles
			if !strings.HasSuffix(entry.Name(), ".app") {
				subDirs = append(subDirs, fullPath)
			}
		} else {
			fileItems = append(fileItems, IndexItem{
				Name: entry.Name(),
				Path: fullPath,
				Type: TypeFile,
			})
		}
	}

	// Check cache state
	fsMtimeNs := info.ModTime().UnixNano()
	dbMtimeNs, err := c.db.GetDirectoryState(path)

	if err != nil || fsMtimeNs != dbMtimeNs {
		// Parent directory modification time changed, update file index for this folder
		errDel := c.db.DeleteFilesForParent(path)
		if errDel == nil {
			_ = c.db.InsertFiles(fileItems)
		}
		_ = c.db.UpdateDirectoryState(path, fsMtimeNs)
	}

	// Recurse into subdirectories
	for _, subDir := range subDirs {
		_ = c.walk(root, subDir, depth+1, visitedDirs)
	}

	return nil
}
