package indexer

import (
	"database/sql"
	"errors"
	"time"

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

	stmt, err := tx.Prepare(`
		INSERT INTO apps(path, name, icon_path)
		VALUES(?, ?, ?)
		ON CONFLICT(path) DO UPDATE SET
			name = excluded.name,
			icon_path = excluded.icon_path
	`)
	if err != nil {
		tx.Rollback()
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
	rows, err := db.conn.Query("SELECT name, path, icon_path, last_opened, frequency FROM apps")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var apps []App
	for rows.Next() {
		var app App
		var lastOpened sql.NullString
		if err := rows.Scan(&app.Name, &app.Path, &app.IconPath, &lastOpened, &app.Frequency); err != nil {
			return nil, err
		}
		if lastOpened.Valid {
			parsed, err := parseSQLiteTime(lastOpened.String)
			if err == nil {
				app.LastOpened = parsed
			}
		}
		apps = append(apps, app)
	}
	return apps, nil
}

func parseSQLiteTime(value string) (time.Time, error) {
	layouts := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02 15:04:05",
		"2006-01-02 15:04:05-07:00",
	}

	for _, layout := range layouts {
		if parsed, err := time.Parse(layout, value); err == nil {
			return parsed, nil
		}
	}

	return time.Time{}, errors.New("unable to parse sqlite time")
}
