package utils

import (
	"path/filepath"
	"strings"
)

var ignoredDirectories = map[string]bool{
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

var ignoredFiles = map[string]bool{
	".DS_Store":      true,
	".localized":     true,
	"thumbs.db":      true,
	"desktop.ini":    true,
	".gitignore":     true,
	".gitattributes": true,
	".gitmodules":    true,
}

var ignoredExtensions = map[string]bool{
	".tmp":  true,
	".log":  true,
	".swp":  true,
	".lock": true,
}

// ShouldIgnore returns true if the given path should be ignored.
// It will NOT ignore the path if it matches the root directory being scanned.
func ShouldIgnore(path string, root string) bool {
	// Never ignore the root itself
	if path == root {
		return false
	}

	name := filepath.Base(path)

	// Check exact directory/file matches
	if ignoredDirectories[name] || ignoredFiles[name] {
		return true
	}

	// Check hidden files/folders (starting with dot)
	if strings.HasPrefix(name, ".") && name != "." && name != ".." {
		return true
	}

	// Check extensions
	ext := filepath.Ext(name)
	if ignoredExtensions[ext] {
		return true
	}

	return false
}
