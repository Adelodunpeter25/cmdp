package search

import (
	"sort"
	"time"

	"github.com/sahilm/fuzzy"
	"github.com/Adelodunpeter25/cmdp/daemon/internal/indexer"
)

// Result represents a single search result with its match score
type Result struct {
	App   indexer.App
	Score int
}

// Apps matches a query against a slice of Apps using fuzzy matching
func Apps(query string, apps []indexer.App) []Result {
	if len(apps) == 0 {
		return nil
	}

	if query == "" {
		results := make([]Result, len(apps))
		for i, app := range apps {
			results[i] = Result{App: app, Score: 0}
		}
		sort.SliceStable(results, func(i, j int) bool {
			return frecencyRank(results[i].App) > frecencyRank(results[j].App)
		})
		return results
	}

	// sahilm/fuzzy needs a source that implements their interface
	// or we can just pass a slice of strings for simple cases.
	// Let's create a slice of names for the fuzzy matcher.
	names := make([]string, len(apps))
	for i, app := range apps {
		names[i] = app.Name
	}

	matches := fuzzy.Find(query, names)

	results := make([]Result, len(matches))
	for i, match := range matches {
		results[i] = Result{
			App:   apps[match.Index],
			Score: match.Score,
		}
	}

	sort.SliceStable(results, func(i, j int) bool {
		left := float64(results[i].Score)*1_000_000 + frecencyRank(results[i].App)
		right := float64(results[j].Score)*1_000_000 + frecencyRank(results[j].App)
		if left == right {
			return results[i].App.Name < results[j].App.Name
		}
		return left > right
	})

	return results
}

func frecencyRank(app indexer.App) float64 {
	score := float64(app.Frequency) * 1_000_000
	if app.LastOpened.IsZero() {
		return score
	}

	ageMinutes := time.Since(app.LastOpened).Minutes()
	if ageMinutes < 0 {
		ageMinutes = 0
	}

	recency := 1_000_000 - ageMinutes
	if recency < 0 {
		recency = 0
	}

	return score + recency
}
