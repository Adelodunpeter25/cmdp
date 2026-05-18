package search

import (
	"github.com/sahilm/fuzzy"
	"github.com/Adelodunpeter25/cmdp/search-daemon/internal/indexer"
)

// Result represents a single search result with its match score
type Result struct {
	App   indexer.App
	Score int
}

// Apps matches a query against a slice of Apps using fuzzy matching
func Apps(query string, apps []indexer.App) []Result {
	if query == "" {
		// Return all apps (or perhaps an empty list) if no query
		results := make([]Result, len(apps))
		for i, app := range apps {
			results[i] = Result{App: app, Score: 0}
		}
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

	return results
}
