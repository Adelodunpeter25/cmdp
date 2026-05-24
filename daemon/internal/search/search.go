package search

import (
	"path/filepath"
	"sort"
	"strings"
	"unicode"

	"github.com/sahilm/fuzzy"
	"github.com/Adelodunpeter25/cmdp/daemon/internal/indexer"
)

// Result represents a single search result with its match score.
type Result struct {
	Item  indexer.IndexItem `json:"Item"`
	Score int               `json:"Score"`
}

// Scoring weights
const (
	scoreExactMatch = 10_000
	scorePrefix     = 5_000
	scoreAcronym    = 4_000
	scoreWordPrefix = 3_000
)



// acronym returns the string formed by the first letter of each word in s.
// e.g. "Google Chrome" → "gc", "Visual Studio Code" → "vsc"
func acronym(s string) string {
	words := strings.FieldsFunc(s, func(r rune) bool {
		return unicode.IsSpace(r) || r == '-' || r == '_' || r == '.'
	})
	b := strings.Builder{}
	for _, w := range words {
		if len(w) > 0 {
			b.WriteRune(unicode.ToLower(rune(w[0])))
		}
	}
	return b.String()
}

// scoreItem computes a deterministic relevance score for item against query.
// Higher is better. The fuzzy library's raw score is used as the base.
func scoreItem(query string, item indexer.IndexItem, fuzzyScore int) int {
	q := strings.ToLower(query)
	name := strings.ToLower(item.Name)

	score := fuzzyScore

	// 1. Exact name match
	if name == q {
		score += scoreExactMatch
		return score // can't do better, short-circuit
	}

	// 2. Name starts with query (prefix match)
	if strings.HasPrefix(name, q) {
		score += scorePrefix
	}

	// 3. Acronym match — query matches the initials of words in the name
	// e.g. "gc" matches "Google Chrome"
	acr := acronym(item.Name)
	if strings.HasPrefix(acr, q) {
		score += scoreAcronym
	}

	// 4. Word-boundary match — any individual word in the name starts with query
	// e.g. "chrome" matches "Google Chrome", "safari" matches "Safari"
	words := strings.FieldsFunc(name, func(r rune) bool {
		return unicode.IsSpace(r) || r == '-' || r == '_' || r == '.'
	})
	for _, w := range words {
		if strings.HasPrefix(w, q) {
			score += scoreWordPrefix
			break // only count once
		}
	}

	return score
}

// Items matches a query against a slice of IndexItems and returns ranked results.
func Items(query string, items []indexer.IndexItem) []Result {
	// Always return a non-nil slice so json.Marshal produces "[]" not "null".
	if len(items) == 0 {
		return []Result{}
	}

	// Empty query: return everything sorted alphabetically.
	if query == "" {
		results := make([]Result, len(items))
		for i, item := range items {
			results[i] = Result{Item: item, Score: 0}
		}
		sort.SliceStable(results, func(i, j int) bool {
			return strings.ToLower(results[i].Item.Name) < strings.ToLower(results[j].Item.Name)
		})
		return results
	}

	// Build name list for the fuzzy library.
	names := make([]string, len(items))
	for i, item := range items {
		names[i] = item.Name
	}

	// Run fuzzy match to get candidate set + base scores.
	matches := fuzzy.Find(query, names)

	// Compute final scores outside the comparator (pure, deterministic).
	results := make([]Result, len(matches))
	for i, m := range matches {
		item := items[m.Index]
		results[i] = Result{
			Item:  item,
			Score: scoreItem(query, item, m.Score),
		}
	}

	// Sort: highest score first; break ties alphabetically.
	sort.SliceStable(results, func(i, j int) bool {
		if results[i].Score != results[j].Score {
			return results[i].Score > results[j].Score
		}
		return strings.ToLower(results[i].Item.Name) < strings.ToLower(results[j].Item.Name)
	})

	if len(results) == 0 {
		return []Result{}
	}
	return results
}

// Files matches a query against a slice of file IndexItems and returns ranked results.
func Files(query string, items []indexer.IndexItem) []Result {
	if len(items) == 0 {
		return []Result{}
	}

	// Empty query: return everything sorted alphabetically.
	if query == "" {
		results := make([]Result, len(items))
		for i, item := range items {
			results[i] = Result{Item: item, Score: 0}
		}
		sort.SliceStable(results, func(i, j int) bool {
			return strings.ToLower(results[i].Item.Name) < strings.ToLower(results[j].Item.Name)
		})
		return results
	}

	// Handle Glob patterns
	if strings.ContainsAny(query, "*?") {
		var results []Result
		lowerQuery := strings.ToLower(query)
		for _, item := range items {
			lowerName := strings.ToLower(item.Name)
			// filepath.Match is used for the actual glob logic
			if matched, _ := filepath.Match(lowerQuery, lowerName); matched {
				// For glob matches, we use a base score + a bonus for shorter names
				// (closer to the pattern)
				score := scoreExactMatch - len(item.Name)
				results = append(results, Result{Item: item, Score: score})
			}
		}

		sort.SliceStable(results, func(i, j int) bool {
			return results[i].Score > results[j].Score
		})

		return results
	}

	names := make([]string, len(items))
	for i, item := range items {
		names[i] = item.Name
	}

	// Fuzzy find candidates
	matches := fuzzy.Find(query, names)

	results := make([]Result, len(matches))
	for i, m := range matches {
		item := items[m.Index]
		results[i] = Result{
			Item:  item,
			Score: scoreItem(query, item, m.Score),
		}
	}

	// Sort by score desc, then name asc
	sort.SliceStable(results, func(i, j int) bool {
		if results[i].Score != results[j].Score {
			return results[i].Score > results[j].Score
		}
		return strings.ToLower(results[i].Item.Name) < strings.ToLower(results[j].Item.Name)
	})

	return results
}
