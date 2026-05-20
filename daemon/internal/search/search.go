package search

import (
	"sort"
	"strings"
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
		scoreI := float64(results[i].Score) * 10
		scoreJ := float64(results[j].Score) * 10

		lowerQuery := strings.ToLower(query)
		nameI := strings.ToLower(results[i].Item.Name)
		nameJ := strings.ToLower(results[j].Item.Name)

		// 1. Exact Name Match (Highest priority)
		if nameI == lowerQuery {
			scoreI += 100000
		}
		if nameJ == lowerQuery {
			scoreJ += 100000
		}

		// 2. Prefix Match Bonus
		if strings.HasPrefix(nameI, lowerQuery) {
			scoreI += 20000
		}
		if strings.HasPrefix(nameJ, lowerQuery) {
			scoreJ += 20000
		}

		// 3. Application Type Boost
		// Applications get a massive boost to keep them above folders.
		if results[i].Item.Type == indexer.TypeApp {
			scoreI += 50000
		}
		if results[j].Item.Type == indexer.TypeApp {
			scoreJ += 50000
		}

		// 4. Frecency (Subtle tie-breaker)
		scoreI += frecencyRank(results[i].Item)
		scoreJ += frecencyRank(results[j].Item)

		if scoreI == scoreJ {
			return results[i].Item.Name < results[j].Item.Name
		}
		return scoreI > scoreJ
	})

	return results
}

func frecencyRank(item indexer.IndexItem) float64 {
	// Frequency: Each click adds 100 points (max 1000)
	freqScore := float64(item.Frequency) * 100
	if freqScore > 1000 {
		freqScore = 1000
	}

	if item.LastOpened.IsZero() {
		return freqScore
	}

	// Recency: Items opened in the last hour get a boost
	age := time.Since(item.LastOpened)
	recencyScore := 0.0
	if age < time.Hour {
		recencyScore = 500
	} else if age < 24*time.Hour {
		recencyScore = 200
	} else if age < 7*24*time.Hour {
		recencyScore = 50
	}

	return freqScore + recencyScore
}
