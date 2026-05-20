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

func (db *DB) SaveItems(items []IndexItem) error {
	tx, err := db.conn.Begin()
	if err != nil {
		return err
	}

	stmt, err := tx.Prepare(`
		INSERT INTO items(path, name, icon_path, type)
		VALUES(?, ?, ?, ?)
		ON CONFLICT(path) DO UPDATE SET
			name = excluded.name,
			icon_path = excluded.icon_path,
			type = excluded.type
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
