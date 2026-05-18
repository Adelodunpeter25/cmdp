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
	CREATE TABLE IF NOT EXISTS apps (
		path TEXT PRIMARY KEY,
		name TEXT,
		icon_path TEXT,
		last_opened DATETIME,
		frequency INTEGER DEFAULT 0
	);`
	
	_, err = db.Exec(query)
	if err != nil {
		return nil, err
	}

	return &DB{conn: db}, nil
}

func (db *DB) SaveApps(apps []App) error {
	tx, err := db.conn.Begin()
	if err != nil {
		return err
	}

	stmt, err := tx.Prepare("INSERT OR REPLACE INTO apps(path, name, icon_path) VALUES(?, ?, ?)")
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, app := range apps {
		_, err = stmt.Exec(app.Path, app.Name, app.IconPath)
		if err != nil {
			tx.Rollback()
			return err
		}
	}

	return tx.Commit()
}

func (db *DB) LoadApps() ([]App, error) {
	rows, err := db.conn.Query("SELECT name, path, icon_path FROM apps")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var apps []App
	for rows.Next() {
		var app App
		if err := rows.Scan(&app.Name, &app.Path, &app.IconPath); err != nil {
			return nil, err
		}
		apps = append(apps, app)
	}
	return apps, nil
}
