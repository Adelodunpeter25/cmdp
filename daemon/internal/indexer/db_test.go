package indexer

import (
	"testing"
)

func TestSaveItems(t *testing.T) {
	db, err := OpenDB(t.TempDir() + "/cmdp.db")
	if err != nil {
		t.Fatalf("OpenDB: %v", err)
	}

	const path = "/Applications/Figma.app"

	if err := db.SaveItems([]IndexItem{{
		Path:     path,
		Name:     "Figma 2026",
		IconPath: "/tmp/updated.icns",
		Type:     TypeApp,
	}}); err != nil {
		t.Fatalf("SaveItems: %v", err)
	}

	var (
		name     string
		iconPath string
		itemType string
	)
	if err := db.conn.QueryRow(
		`SELECT name, icon_path, type FROM items WHERE path = ?`,
		path,
	).Scan(&name, &iconPath, &itemType); err != nil {
		t.Fatalf("query row: %v", err)
	}

	if name != "Figma 2026" {
		t.Fatalf("name overwritten incorrectly: got %q", name)
	}
	if iconPath != "/tmp/updated.icns" {
		t.Fatalf("icon path overwritten incorrectly: got %q", iconPath)
	}
	if itemType != string(TypeApp) {
		t.Fatalf("type overwritten incorrectly: got %q", itemType)
	}
}
