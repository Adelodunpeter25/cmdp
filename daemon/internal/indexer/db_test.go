package indexer

import (
	"testing"
	"time"
)

func TestSaveItemsPreservesFrecencyFields(t *testing.T) {
	db, err := OpenDB(t.TempDir() + "/cmdp.db")
	if err != nil {
		t.Fatalf("OpenDB: %v", err)
	}

	const (
		path        = "/Applications/Figma.app"
		originalCnt = 7
	)
	originalTS := time.Date(2026, time.May, 18, 12, 0, 0, 0, time.UTC)

	if _, err := db.conn.Exec(
		`INSERT INTO items(path, name, icon_path, type, last_opened, frequency) VALUES(?, ?, ?, ?, ?, ?)`,
		path,
		"Figma",
		"/tmp/original.icns",
		string(TypeApp),
		originalTS,
		originalCnt,
	); err != nil {
		t.Fatalf("seed row: %v", err)
	}

	if err := db.SaveItems([]IndexItem{{
		Path:     path,
		Name:     "Figma 2026",
		IconPath: "/tmp/updated.icns",
		Type:     TypeApp,
	}}); err != nil {
		t.Fatalf("SaveItems: %v", err)
	}

	var (
		name       string
		iconPath   string
		lastOpened string
		frequency  int
	)
	if err := db.conn.QueryRow(
		`SELECT name, icon_path, last_opened, frequency FROM items WHERE path = ?`,
		path,
	).Scan(&name, &iconPath, &lastOpened, &frequency); err != nil {
		t.Fatalf("query row: %v", err)
	}

	if name != "Figma 2026" {
		t.Fatalf("name overwritten incorrectly: got %q", name)
	}
	if iconPath != "/tmp/updated.icns" {
		t.Fatalf("icon path overwritten incorrectly: got %q", iconPath)
	}
	parsedTS, err := time.Parse(time.RFC3339, lastOpened)
	if err != nil {
		// Try fallback parsing if RFC3339 fails (SQLite format)
		parsedTS, err = parseSQLiteTime(lastOpened)
		if err != nil {
			t.Fatalf("parse last_opened: %v", err)
		}
	}
	if !parsedTS.Equal(originalTS) {
		t.Fatalf("last_opened changed: got %s want %s", parsedTS.Format(time.RFC3339), originalTS.Format(time.RFC3339))
	}
	if frequency != originalCnt {
		t.Fatalf("frequency changed: got %d want %d", frequency, originalCnt)
	}
}
