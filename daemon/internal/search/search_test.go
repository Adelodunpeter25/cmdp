package search

import (
	"testing"

	"github.com/Adelodunpeter25/cmdp/daemon/internal/indexer"
)

var testItems = []indexer.IndexItem{
	{Name: "Google Chrome", Path: "/Applications/Google Chrome.app", Type: indexer.TypeApp},
	{Name: "Brave Browser", Path: "/Applications/Brave Browser.app", Type: indexer.TypeApp},
	{Name: "Figma", Path: "/Applications/Figma.app", Type: indexer.TypeApp},
	{Name: "Calculator", Path: "/System/Applications/Calculator.app", Type: indexer.TypeApp},
	{Name: "Visual Studio Code", Path: "/Applications/Visual Studio Code.app", Type: indexer.TypeApp},
	{Name: "Safari", Path: "/System/Applications/Safari.app", Type: indexer.TypeApp},
}

// firstName returns the name of the first result, or "" if results is empty.
func firstName(results []Result) string {
	if len(results) == 0 {
		return ""
	}
	return results[0].Item.Name
}

// containsName returns true if any result has the given name.
func containsName(results []Result, name string) bool {
	for _, r := range results {
		if r.Item.Name == name {
			return true
		}
	}
	return false
}

func TestExactMatch(t *testing.T) {
	results := Items("Figma", testItems)
	if firstName(results) != "Figma" {
		t.Errorf("exact match: want Figma first, got %q", firstName(results))
	}
}

func TestExactMatchCaseInsensitive(t *testing.T) {
	results := Items("figma", testItems)
	if firstName(results) != "Figma" {
		t.Errorf("case-insensitive exact match: want Figma first, got %q", firstName(results))
	}
}

func TestPrefixMatch(t *testing.T) {
	// "Saf" should rank Safari first
	results := Items("Saf", testItems)
	if firstName(results) != "Safari" {
		t.Errorf("prefix match: want Safari first, got %q", firstName(results))
	}
}

func TestWordBoundaryMatch(t *testing.T) {
	// "Chrome" is not a prefix of "Google Chrome" but is a word-boundary match
	results := Items("Chrome", testItems)
	if !containsName(results, "Google Chrome") {
		t.Error("word-boundary match: expected Google Chrome in results for query 'Chrome'")
	}
	// Google Chrome should rank higher than unrelated items
	if firstName(results) != "Google Chrome" {
		t.Errorf("word-boundary match: want Google Chrome first, got %q", firstName(results))
	}
}

func TestAcronymMatch(t *testing.T) {
	// "gc" → "Google Chrome" (acronym: g+c)
	results := Items("gc", testItems)
	if !containsName(results, "Google Chrome") {
		t.Error("acronym match: expected Google Chrome in results for query 'gc'")
	}
	if firstName(results) != "Google Chrome" {
		t.Errorf("acronym match: want Google Chrome first, got %q", firstName(results))
	}
}

func TestAcronymMatchVSC(t *testing.T) {
	// "vsc" → "Visual Studio Code"
	results := Items("vsc", testItems)
	if !containsName(results, "Visual Studio Code") {
		t.Error("acronym match: expected Visual Studio Code in results for query 'vsc'")
	}
	if firstName(results) != "Visual Studio Code" {
		t.Errorf("acronym match: want Visual Studio Code first, got %q", firstName(results))
	}
}

func TestFuzzyMatch(t *testing.T) {
	// "Chr" should fuzzy-match "Google Chrome"
	results := Items("Chr", testItems)
	if !containsName(results, "Google Chrome") {
		t.Error("fuzzy match: expected Google Chrome in results for query 'Chr'")
	}
}

func TestEmptyQuery(t *testing.T) {
	results := Items("", testItems)
	if len(results) != len(testItems) {
		t.Errorf("empty query: want %d results, got %d", len(testItems), len(results))
	}
	// Should be sorted alphabetically
	if firstName(results) != "Brave Browser" {
		t.Errorf("empty query alphabetical: want Brave Browser first, got %q", firstName(results))
	}
}

func TestEmptyItems(t *testing.T) {
	results := Items("Figma", nil)
	if results != nil {
		t.Errorf("empty items: expected nil, got %v", results)
	}
}

func TestTieBreakAlphabetical(t *testing.T) {
	// Two items whose names are structurally identical apart from the first word —
	// both get the same fuzzy score, same word-boundary bonus, so the tie must
	// be broken alphabetically ("Zap Launcher" < "Zip Launcher").
	items := []indexer.IndexItem{
		{Name: "Zip Launcher", Path: "/Applications/Zip.app", Type: indexer.TypeApp},
		{Name: "Zap Launcher", Path: "/Applications/Zap.app", Type: indexer.TypeApp},
	}
	// Both match "Launcher" as a word-boundary; identical structure → same scores.
	// Alphabetical tie-break should put Zap before Zip.
	results := Items("Launcher", items)
	if len(results) < 2 {
		t.Fatalf("tie-break: expected 2 results, got %d", len(results))
	}
	if firstName(results) != "Zap Launcher" {
		t.Errorf("tie-break: want Zap Launcher first (alphabetical), got %q", firstName(results))
	}
}

func TestAcronym(t *testing.T) {
	cases := []struct {
		input string
		want  string
	}{
		{"Google Chrome", "gc"},
		{"Visual Studio Code", "vsc"},
		{"Brave Browser", "bb"},
		{"Calculator", "c"},
		{"Figma", "f"},
	}
	for _, c := range cases {
		got := acronym(c.input)
		if got != c.want {
			t.Errorf("acronym(%q) = %q, want %q", c.input, got, c.want)
		}
	}
}
