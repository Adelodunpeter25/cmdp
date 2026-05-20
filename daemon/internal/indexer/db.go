package indexer

import (
	"database/sql"

	_ "github.com/mattn/go-sqlite3"
)

type DB struct {
	conn *sql.DB
}

func OpenDB(path string) (*DB, error) {
	db, err := sql.Open("sqlite3", path)
	if err != nil {
		return nil, err
	}

	// Create tables if they don't exist
	query := `
	CREATE TABLE IF NOT EXISTS items (
		path TEXT PRIMARY KEY,
		name TEXT,
		icon_path TEXT,
		type TEXT
	);`

	_, err = db.Exec(query)
	if err != nil {
		return nil, err
	}

	return &DB{conn: db}, nil
}

// SaveItems replaces the entire items table with the provided list in a single
// atomic transaction.  This guarantees no stale entries (uninstalled apps,
// wrongly-typed rows, removed folders) survive between scans.
func (db *DB) SaveItems(items []IndexItem) error {
	tx, err := db.conn.Begin()
	if err != nil {
		return err
	}

	// Wipe existing data first.
	if _, err := tx.Exec("DELETE FROM items"); err != nil {
		tx.Rollback()
		return err
	}

	stmt, err := tx.Prepare(`
		INSERT INTO items(path, name, icon_path, type)
		VALUES(?, ?, ?, ?)
	`)
	if err != nil {
		tx.Rollback()
		return err
	}
	defer stmt.Close()

	for _, item := range items {
		_, err = stmt.Exec(item.Path, item.Name, item.IconPath, string(item.Type))
		if err != nil {
			tx.Rollback()
			return err
		}
	}

	return tx.Commit()
}

// DeleteAll removes all items from the database.
func (db *DB) DeleteAll() error {
	_, err := db.conn.Exec("DELETE FROM items")
	return err
}


func (db *DB) LoadItems() ([]IndexItem, error) {
	rows, err := db.conn.Query("SELECT name, path, icon_path, type FROM items")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []IndexItem
	for rows.Next() {
		var item IndexItem
		var itemType string
		if err := rows.Scan(&item.Name, &item.Path, &item.IconPath, &itemType); err != nil {
			return nil, err
		}
		item.Type = ItemType(itemType)
		items = append(items, item)
	}
	return items, nil
}
