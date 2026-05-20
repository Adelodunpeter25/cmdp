package search

import (
	"sort"
	"strings"

	"github.com/sahilm/fuzzy"
	"github.com/Adelodunpeter25/cmdp/daemon/internal/indexer"
)

// Result represents a single search result with its match score
type Result struct {
	Item  indexer.IndexItem `json:"Item"`
	Score int               `json:"Score"`
}

// Items matches a query against a slice of IndexItems using fuzzy matching
func Items(query string, items []indexer.IndexItem) []Result {
	if len(items) == 0 {
		return nil
	}

	if query == "" {
		results := make([]Result, len(items))
		for i, item := range items {
			results[i] = Result{Item: item, Score: 0}
		}
		sort.SliceStable(results, func(i, j int) bool {
			return results[i].Item.Name < results[j].Item.Name
		})
		return results
	}

	names := make([]string, len(items))
	for i, item := range items {
		names[i] = item.Name
	}

	matches := fuzzy.Find(query, names)

	results := make([]Result, len(matches))
	for i, match := range matches {
		results[i] = Result{
			Item:  items[match.Index],
			Score: match.Score,
		}
	}

	sort.SliceStable(results, func(i, j int) bool {
		scoreI := float64(results[i].Score)
		scoreJ := float64(results[j].Score)

		lowerQuery := strings.ToLower(query)
		nameI := strings.ToLower(results[i].Item.Name)
		nameJ := strings.ToLower(results[j].Item.Name)

		// 1. Exact Name Match (Highest priority)
		if nameI == lowerQuery {
			scoreI += 1000
		}
		if nameJ == lowerQuery {
			scoreJ += 1000
		}

		// 2. Prefix Match Bonus
		if strings.HasPrefix(nameI, lowerQuery) {
			scoreI += 500
		}
		if strings.HasPrefix(nameJ, lowerQuery) {
			scoreJ += 500
		}

		if scoreI == scoreJ {
			return results[i].Item.Name < results[j].Item.Name
		}
		return scoreI > scoreJ
	})

	return results
}
