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
		// 1. Relevance Score (Fuzzy match)
		// sahilm/fuzzy scores: higher is better match.
		// We multiply by a large factor to make it the primary signal.
		scoreI := float64(results[i].Score) * 1000
		scoreJ := float64(results[j].Score) * 1000

		// 2. Prefix Match Bonus
		// If the name starts with the query, give it a significant boost.
		lowerQuery := strings.ToLower(query)
		if strings.HasPrefix(strings.ToLower(results[i].Item.Name), lowerQuery) {
			scoreI += 5000
		}
		if strings.HasPrefix(strings.ToLower(results[j].Item.Name), lowerQuery) {
			scoreJ += 5000
		}

		// 3. Application Boost
		// Applications should generally outrank folders if relevance is close.
		if results[i].Item.Type == indexer.TypeApp {
			scoreI += 3000
		}
		if results[j].Item.Type == indexer.TypeApp {
			scoreJ += 3000
		}

		// 4. Frecency (Frequency + Recency)
		// Frecency should be a tie-breaker or subtle adjustment, not the primary driver.
		// A single click (Frequency 1) should not outrank a prefix match.
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
