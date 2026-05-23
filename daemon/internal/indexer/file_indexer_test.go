package indexer

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestFileCrawler_Scan(t *testing.T) {
	tempDir := t.TempDir()
	dbPath := filepath.Join(tempDir, "test.db")
	db, err := OpenDB(dbPath)
	if err != nil {
		t.Fatalf("failed to open test db: %v", err)
	}
	defer db.conn.Close()

	// Create a test directory structure
	ignoredDir := filepath.Join(tempDir, "node_modules")
	docsDir := filepath.Join(tempDir, "docs")
	projectsDir := filepath.Join(tempDir, "projects")
	gitDir := filepath.Join(projectsDir, ".git")
	appDir := filepath.Join(tempDir, "app.app")

	dirs := []string{ignoredDir, docsDir, gitDir, appDir, projectsDir}
	for _, d := range dirs {
		if err := os.MkdirAll(d, 0755); err != nil {
			t.Fatalf("failed to create dir %s: %v", d, err)
		}
	}

	// Create test files
	files := []struct {
		path string
		data string
	}{
		{filepath.Join(ignoredDir, "some.txt"), "ignored"},
		{filepath.Join(docsDir, "resume.pdf"), "resume"},
		{filepath.Join(docsDir, "notes.txt"), "notes"},
		{filepath.Join(projectsDir, "main.go"), "package main"},
		{filepath.Join(gitDir, "config"), "config"},
		{filepath.Join(projectsDir, "temp.log"), "log"},
		{filepath.Join(tempDir, "readme.md"), "readme"},
		{filepath.Join(appDir, "Info.plist"), "plist"},
	}

	for _, f := range files {
		if err := os.WriteFile(f.path, []byte(f.data), 0644); err != nil {
			t.Fatalf("failed to write file %s: %v", f.path, err)
		}
	}

	crawler := NewFileCrawler(db, 5)

	// Scan the temp directory root
	if err := crawler.Scan([]string{tempDir}); err != nil {
		t.Fatalf("crawler Scan failed: %v", err)
	}

	// Helper to check file existence in DB
	checkFile := func(path string, expected bool) {
		t.Helper()
		var count int
		err := db.conn.QueryRow("SELECT COUNT(*) FROM files WHERE path = ?", path).Scan(&count)
		if err != nil {
			t.Fatalf("db query error for path %s: %v", path, err)
		}
		found := count > 0
		if found != expected {
			t.Errorf("path %s: expected presence = %v, got %v", path, expected, found)
		}
	}

	// Verify valid files are indexed
	checkFile(filepath.Join(docsDir, "resume.pdf"), true)
	checkFile(filepath.Join(docsDir, "notes.txt"), true)
	checkFile(filepath.Join(projectsDir, "main.go"), true)
	checkFile(filepath.Join(tempDir, "readme.md"), true)

	// Verify ignored folders/extensions are skipped
	checkFile(filepath.Join(ignoredDir, "some.txt"), false)   // node_modules
	checkFile(filepath.Join(gitDir, "config"), false)         // .git
	checkFile(filepath.Join(projectsDir, "temp.log"), false)   // ignored extension (.log)
	checkFile(filepath.Join(appDir, "Info.plist"), false)      // inside .app bundle

	// Test SearchFiles from database
	results, err := db.SearchFiles("notes")
	if err != nil {
		t.Fatalf("SearchFiles failed: %v", err)
	}
	if len(results) != 1 || results[0].Name != "notes.txt" {
		t.Errorf("expected 1 result 'notes.txt', got %v", results)
	}

	// Verify cached mtime is stored
	mtimeBefore, err := db.GetDirectoryState(docsDir)
	if err != nil {
		t.Fatalf("failed to get directory state: %v", err)
	}
	if mtimeBefore == 0 {
		t.Error("expected cached mtime to be set (> 0)")
	}

	// Incrementally add a file
	time.Sleep(100 * time.Millisecond)
	newFilePath := filepath.Join(docsDir, "new.txt")
	if err := os.WriteFile(newFilePath, []byte("new file"), 0644); err != nil {
		t.Fatalf("failed to write new file: %v", err)
	}

	// Touch folder to force mtime change in test filesystem
	now := time.Now()
	if err := os.Chtimes(docsDir, now, now); err != nil {
		t.Fatalf("failed to change dir times: %v", err)
	}

	if err := crawler.Scan([]string{tempDir}); err != nil {
		t.Fatalf("crawler second Scan failed: %v", err)
	}

	checkFile(newFilePath, true)

	// Test deletion cleanup
	if err := os.RemoveAll(docsDir); err != nil {
		t.Fatalf("failed to delete docs dir: %v", err)
	}

	if err := crawler.Scan([]string{tempDir}); err != nil {
		t.Fatalf("crawler third Scan failed: %v", err)
	}

	checkFile(filepath.Join(docsDir, "resume.pdf"), false)
	checkFile(filepath.Join(docsDir, "notes.txt"), false)
	checkFile(newFilePath, false)

	mtimeAfter, err := db.GetDirectoryState(docsDir)
	if err != nil {
		t.Fatalf("failed to get directory state after delete: %v", err)
	}
	if mtimeAfter != 0 {
		t.Errorf("expected directory state to be deleted, got %d", mtimeAfter)
	}
}
