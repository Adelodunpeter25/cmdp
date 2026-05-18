package indexer

import (
	"testing"
)

func TestScan(t *testing.T) {
	// For now, let's scan a known path that should exist on any Mac
	dirs := []string{"/System/Applications"}
	apps, err := Scan(dirs)

	if err != nil {
		t.Fatalf("Failed to scan: %v", err)
	}

	if len(apps) == 0 {
		t.Error("Expected to find some apps in /System/Applications, but found none")
	}

	// Verify we found something like Finder or Calculator
	found := false
	for _, app := range apps {
		if app.Name == "Calculator" || app.Name == "Finder" {
			found = true
			break
		}
	}

	if !found {
		t.Logf("Found %d apps, but not the ones we expected for a test. This might be fine depending on the OS version.", len(apps))
	}
}
