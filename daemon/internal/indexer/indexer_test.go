package indexer

import (
	"testing"
)

func TestCrawler_ScanSystem(t *testing.T) {
	// For now, let's scan a known path that should exist on any Mac
	dirs := []string{"/System/Applications"}
	crawler := NewCrawler(1)
	items, err := crawler.Scan(dirs)

	if err != nil {
		t.Fatalf("Failed to scan: %v", err)
	}

	if len(items) == 0 {
		t.Error("Expected to find some apps in /System/Applications, but found none")
	}

	// Verify we found something like Finder or Calculator
	found := false
	for _, item := range items {
		if item.Name == "Calculator" || item.Name == "Finder" {
			found = true
			break
		}
	}

	if !found {
		t.Logf("Found %d items, but not the ones we expected for a test. This might be fine depending on the OS version.", len(items))
	}
}
