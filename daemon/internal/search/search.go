package search

import (
	"sort"
	"time"

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
			return frecencyRank(results[i].Item) > frecencyRank(results[j].Item)
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
		// Base boost for apps over folders
		leftBoost := 0.0
		if results[i].Item.Type == indexer.TypeApp {
			leftBoost = 500_000
		}
		rightBoost := 0.0
		if results[j].Item.Type == indexer.TypeApp {
			rightBoost = 500_000
		}

		left := float64(results[i].Score)*1_000_000 + frecencyRank(results[i].Item) + leftBoost
		right := float64(results[j].Score)*1_000_000 + frecencyRank(results[j].Item) + rightBoost

		if left == right {
			return results[i].Item.Name < results[j].Item.Name
		}
		return left > right
	})

	return results
}

func frecencyRank(item indexer.IndexItem) float64 {
	score := float64(item.Frequency) * 1_000_000
	if item.LastOpened.IsZero() {
		return score
	}

	ageMinutes := time.Since(item.LastOpened).Minutes()
	if ageMinutes < 0 {
		ageMinutes = 0
	}

	recency := 1_000_000 - ageMinutes
	if recency < 0 {
		recency = 0
	}

	return score + recency
}
