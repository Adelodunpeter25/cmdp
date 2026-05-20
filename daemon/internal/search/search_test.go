package search

import (
	"testing"

	"github.com/Adelodunpeter25/cmdp/daemon/internal/indexer"
)

func TestSearchItems(t *testing.T) {
	items := []indexer.IndexItem{
		{Name: "Google Chrome", Path: "/Applications/Google Chrome.app", Type: indexer.TypeApp},
		{Name: "Brave Browser", Path: "/Applications/Brave Browser.app", Type: indexer.TypeApp},
		{Name: "Figma", Path: "/Applications/Figma.app", Type: indexer.TypeApp},
		{Name: "Calculator", Path: "/System/Applications/Calculator.app", Type: indexer.TypeApp},
	}

	t.Run("Exact match", func(t *testing.T) {
		results := Items("Figma", items)
		if len(results) == 0 || results[0].Item.Name != "Figma" {
			t.Errorf("Expected Figma as first result, got %+v", results)
		}
	})

	t.Run("Fuzzy match", func(t *testing.T) {
		// "Chr" should match "Google Chrome"
		results := Items("Chr", items)
		found := false
		for _, r := range results {
			if r.Item.Name == "Google Chrome" {
				found = true
				break
			}
		}
		if !found {
			t.Error("Expected Chr to match Google Chrome")
		}
	})

	t.Run("Empty query", func(t *testing.T) {
		results := Items("", items)
		if len(results) != len(items) {
			t.Errorf("Expected all items for empty query, got %d", len(results))
		}
		// Alphabetical order for empty query
		if len(results) > 0 && results[0].Item.Name != "Brave Browser" {
			t.Errorf("Expected alphabetical first item, got %s", results[0].Item.Name)
		}
	})
}
