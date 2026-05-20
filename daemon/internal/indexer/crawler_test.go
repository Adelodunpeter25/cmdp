package indexer

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCrawler_Scan(t *testing.T) {
	// Setup temporary directory for testing
	tempDir, err := os.MkdirTemp("", "crawler_test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tempDir)

	// Create a mock structure:
	// /Apps
	//   /MyApp.app (dir)
	// /Docs
	//   /Folder1
	//     /SubFolder
	//   /Ignored (.git)
	//   /SymlinkToApp -> /Apps/MyApp.app

	appsDir := filepath.Join(tempDir, "Apps")
	os.Mkdir(appsDir, 0755)
	myAppPath := filepath.Join(appsDir, "MyApp.app")
	os.Mkdir(myAppPath, 0755)

	docsDir := filepath.Join(tempDir, "Docs")
	os.Mkdir(docsDir, 0755)
	folder1 := filepath.Join(docsDir, "Folder1")
	os.Mkdir(folder1, 0755)
	subFolder := filepath.Join(folder1, "SubFolder")
	os.Mkdir(subFolder, 0755)

	ignoredDir := filepath.Join(docsDir, ".git")
	os.Mkdir(ignoredDir, 0755)

	symlinkPath := filepath.Join(docsDir, "SymlinkToApp")
	os.Symlink(myAppPath, symlinkPath)

	crawler := NewCrawler(3)
	items, err := crawler.Scan([]string{tempDir})
	if err != nil {
		t.Errorf("Crawler.Scan failed: %v", err)
	}

	// Verify results
	hasApp := false
	hasFolder1 := false
	hasSubFolder := false
	hasSymlinkApp := false
	hasIgnored := false

	for _, item := range items {
		if item.Path == myAppPath && item.Type == TypeApp {
			hasApp = true
		}
		if item.Path == folder1 && item.Type == TypeFolder {
			hasFolder1 = true
		}
		if item.Path == subFolder && item.Type == TypeFolder {
			hasSubFolder = true
		}
		if item.Path == symlinkPath && item.Type == TypeApp {
			hasSymlinkApp = true
		}
		if strings.Contains(item.Path, ".git") {
			hasIgnored = true
		}
	}

	if !hasApp { t.Error("Failed to find app bundle") }
	if !hasFolder1 { t.Error("Failed to find Folder1") }
	if !hasSubFolder { t.Error("Failed to find deep subfolder") }
	if !hasSymlinkApp { t.Error("Failed to follow symlink to app") }
	if hasIgnored { t.Error("Found an ignored directory (.git)") }
}

func TestCrawler_MaxDepth(t *testing.T) {
	tempDir, _ := os.MkdirTemp("", "depth_test")
	defer os.RemoveAll(tempDir)

	// Create deep structure: root/1/2/3/4/5
	curr := tempDir
	for i := 1; i <= 5; i++ {
		curr = filepath.Join(curr, fmt.Sprintf("%d", i))
		os.Mkdir(curr, 0755)
	}

	crawler := NewCrawler(2) // Should only find 1 and 2
	items, _ := crawler.Scan([]string{tempDir})

	count := 0
	for _, item := range items {
		if item.Type == TypeFolder {
			count++
		}
	}

	if count > 2 {
		t.Errorf("Crawler exceeded max depth: found %d items, expected max 2", count)
	}
}
