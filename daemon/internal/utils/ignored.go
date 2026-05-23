package utils

import (
	"path/filepath"
	"strings"
)

var defaultDirectories = map[string]bool{
	".git":             true,
	".svn":             true,
	".hg":              true,
	"node_modules":     true,
	"bower_components": true,
	"vendor":           true,
	"pkg":              true,
	"mod":              true,
	"bin":              true,
	"cache":            true,
	"flutter_web_sdk":  true,
	".pub-cache":       true,
	"Pods":             true,
	".vscode":          true,
	".idea":            true,
	".DS_Store":        true,
	"Library":          true,
	"Frameworks":       true,
	".Trash":           true,
}

var defaultFiles = map[string]bool{
	".DS_Store":      true,
	".localized":     true,
	"thumbs.db":      true,
	"desktop.ini":    true,
	".gitignore":     true,
	".gitattributes": true,
	".gitmodules":    true,
}

var defaultExtensions = map[string]bool{
	".tmp":  true,
	".log":  true,
	".swp":  true,
	".lock": true,
}

// IgnoreChecker allows custom and reusable file/directory ignoring filters.
type IgnoreChecker struct {
	Directories map[string]bool
	Files       map[string]bool
	Extensions  map[string]bool
}

// NewIgnoreChecker initializes a standard IgnoreChecker with default ignore rules.
func NewIgnoreChecker() *IgnoreChecker {
	return &IgnoreChecker{
		Directories: defaultDirectories,
		Files:       defaultFiles,
		Extensions:  defaultExtensions,
	}
}

// ShouldIgnore checks if a path matches any of the ignore patterns.
func (c *IgnoreChecker) ShouldIgnore(path string, root string) bool {
	name := filepath.Base(path)

	// Check exact directory/file matches
	if c.Directories[name] || c.Files[name] {
		return true
	}

	// Check hidden files/folders (starting with dot)
	if strings.HasPrefix(name, ".") && name != "." && name != ".." {
		return true
	}

	// Check extensions
	ext := filepath.Ext(name)
	if c.Extensions[ext] {
		return true
	}

	return false
}

var defaultChecker = NewIgnoreChecker()

// ShouldIgnore returns true if the given path should be ignored under default rules.
// It will NOT ignore the path if it matches the root directory being scanned.
func ShouldIgnore(path string, root string) bool {
	return defaultChecker.ShouldIgnore(path, root)
}

