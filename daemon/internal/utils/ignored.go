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
	"Applications":     true, // Handled separately or skipped to avoid redundancy
	"System":           true,
	"Volumes":          true,
	"Network":          true,
	"private":          true,
	"dev":              true,
	"cores":            true,
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

// ShouldIgnore returns true if the given path, directory name, or file name should be ignored.
func ShouldIgnore(path string) bool {
	name := filepath.Base(path)

	// Check exact directory/file matches
	if ignoredDirectories[name] || ignoredFiles[name] {
		return true
	}

	// Check hidden files/folders (starting with dot), but allow some common ones if needed
	// For now, let's ignore all hidden items by default to keep the index clean.
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
