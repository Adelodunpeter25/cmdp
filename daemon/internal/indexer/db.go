package indexer

import (
	"database/sql"
	"path/filepath"
	"strings"

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
	);
	CREATE TABLE IF NOT EXISTS files (
		path TEXT PRIMARY KEY,
		name TEXT,
		extension TEXT,
		parent_dir TEXT
	);
	CREATE INDEX IF NOT EXISTS idx_files_name ON files(name);
	CREATE INDEX IF NOT EXISTS idx_files_parent ON files(parent_dir);

	CREATE TABLE IF NOT EXISTS directory_states (
		path TEXT PRIMARY KEY,
		last_modified_ns INTEGER
	);
	CREATE TABLE IF NOT EXISTS shelf_items (
		id TEXT PRIMARY KEY,
		original_path TEXT,
		shelf_path TEXT,
		name TEXT,
		created_at INTEGER
	);`

	_, err = db.Exec(query)
	if err != nil {
		return nil, err
	}

	return &DB{conn: db}, nil
}

// Conn returns the raw database connection.
func (db *DB) Conn() *sql.DB {
	return db.conn
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
	if err != nil {
		return err
	}
	_, err = db.conn.Exec("DELETE FROM files")
	if err != nil {
		return err
	}
	_, err = db.conn.Exec("DELETE FROM directory_states")
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

// DeleteFilesForParent deletes all files indexed under a specific parent directory.
func (db *DB) DeleteFilesForParent(parentDir string) error {
	_, err := db.conn.Exec("DELETE FROM files WHERE parent_dir = ?", parentDir)
	return err
}

// InsertFiles inserts a batch of files into the files table.
func (db *DB) InsertFiles(files []IndexItem) error {
	if len(files) == 0 {
		return nil
	}
	tx, err := db.conn.Begin()
	if err != nil {
		return err
	}

	stmt, err := tx.Prepare(`
		INSERT OR REPLACE INTO files(path, name, extension, parent_dir)
		VALUES(?, ?, ?, ?)
	`)
	if err != nil {
		tx.Rollback()
		return err
	}
	defer stmt.Close()

	for _, f := range files {
		ext := strings.TrimPrefix(filepath.Ext(f.Name), ".")
		parentDir := filepath.Dir(f.Path)
		_, err = stmt.Exec(f.Path, f.Name, ext, parentDir)
		if err != nil {
			tx.Rollback()
			return err
		}
	}

	return tx.Commit()
}

// SearchFiles returns matching files using a case-insensitive LIKE search.
// It supports glob-like wildcards (* and ?) by converting them to SQL LIKE syntax.
func (db *DB) SearchFiles(query string) ([]IndexItem, error) {
	if query == "" {
		return []IndexItem{}, nil
	}

	sqlQuery := query
	if strings.ContainsAny(query, "*?") {
		// Convert glob wildcards to SQL LIKE wildcards
		sqlQuery = strings.ReplaceAll(sqlQuery, "*", "%")
		sqlQuery = strings.ReplaceAll(sqlQuery, "?", "_")
	} else {
		// Default to substring match if no wildcards provided
		sqlQuery = "%" + query + "%"
	}

	rows, err := db.conn.Query("SELECT name, path FROM files WHERE name LIKE ? LIMIT 100", sqlQuery)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []IndexItem
	for rows.Next() {
		var item IndexItem
		if err := rows.Scan(&item.Name, &item.Path); err != nil {
			return nil, err
		}
		item.Type = TypeFile
		items = append(items, item)
	}
	return items, nil
}

// GetDirectoryState returns the cached mtime (in nanoseconds) for a directory.
// Returns 0 if not found.
func (db *DB) GetDirectoryState(path string) (int64, error) {
	var mtimeNs int64
	err := db.conn.QueryRow("SELECT last_modified_ns FROM directory_states WHERE path = ?", path).Scan(&mtimeNs)
	if err == sql.ErrNoRows {
		return 0, nil
	}
	return mtimeNs, err
}

// UpdateDirectoryState inserts or updates the cached mtime for a directory.
func (db *DB) UpdateDirectoryState(path string, mtimeNs int64) error {
	_, err := db.conn.Exec("INSERT OR REPLACE INTO directory_states(path, last_modified_ns) VALUES(?, ?)", path, mtimeNs)
	return err
}

// DeleteDirectoryState deletes a directory's cached mtime.
func (db *DB) DeleteDirectoryState(path string) error {
	_, err := db.conn.Exec("DELETE FROM directory_states WHERE path = ?", path)
	return err
}

// GetAllDirectoryStates returns a map of all cached directory paths and their mtimes.
func (db *DB) GetAllDirectoryStates() (map[string]int64, error) {
	rows, err := db.conn.Query("SELECT path, last_modified_ns FROM directory_states")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	states := make(map[string]int64)
	for rows.Next() {
		var path string
		var mtimeNs int64
		if err := rows.Scan(&path, &mtimeNs); err != nil {
			return nil, err
		}
		states[path] = mtimeNs
	}
	return states, nil
}

