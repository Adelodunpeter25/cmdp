package search

import (
	"testing"
	"time"

	"github.com/Adelodunpeter25/cmdp/daemon/internal/indexer"
)

func TestSearchApps(t *testing.T) {
	apps := []indexer.App{
		{Name: "Google Chrome", Path: "/Applications/Google Chrome.app", Frequency: 2, LastOpened: time.Now().Add(-24 * time.Hour)},
		{Name: "Brave Browser", Path: "/Applications/Brave Browser.app", Frequency: 10, LastOpened: time.Now().Add(-48 * time.Hour)},
		{Name: "Figma", Path: "/Applications/Figma.app", Frequency: 1, LastOpened: time.Now().Add(-2 * time.Hour)},
		{Name: "Calculator", Path: "/System/Applications/Calculator.app"},
	}

	t.Run("Exact match", func(t *testing.T) {
		results := Apps("Figma", apps)
		if len(results) == 0 || results[0].App.Name != "Figma" {
			t.Errorf("Expected Figma as first result, got %+v", results)
		}
	})

	t.Run("Fuzzy match", func(t *testing.T) {
		// "Chr" should match "Google Chrome"
		results := Apps("Chr", apps)
		found := false
		for _, r := range results {
			if r.App.Name == "Google Chrome" {
				found = true
				break
			}
		}
		if !found {
			t.Error("Expected Chr to match Google Chrome")
		}
	})

	t.Run("Empty query", func(t *testing.T) {
		results := Apps("", apps)
		if len(results) != len(apps) {
			t.Errorf("Expected all apps for empty query, got %d", len(results))
		}
		if len(results) > 0 && results[0].App.Name != "Brave Browser" {
			t.Errorf("Expected most frequented app first, got %s", results[0].App.Name)
		}
	})
}
