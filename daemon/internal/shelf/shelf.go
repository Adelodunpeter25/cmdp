package shelf

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/Adelodunpeter25/cmdp/daemon/internal/indexer"
)

type ShelfItem struct {
	ID           string `json:"id"`
	OriginalPath string `json:"original_path"`
	ShelfPath    string `json:"shelf_path"`
	Name         string `json:"name"`
	CreatedAt    int64  `json:"created_at"`
}

type Manager struct {
	db       *indexer.DB
	shelfDir string
}

func NewManager(db *indexer.DB, homeDir string) (*Manager, error) {
	shelfDir := filepath.Join(homeDir, ".cmdp", "shelf")
	if err := os.MkdirAll(shelfDir, 0755); err != nil {
		return nil, err
	}
	return &Manager{
		db:       db,
		shelfDir: shelfDir,
	}, nil
}

func (m *Manager) Add(originalPath string) (*ShelfItem, error) {
	// Generate unique ID
	bytes := make([]byte, 8)
	if _, err := rand.Read(bytes); err != nil {
		return nil, err
	}
	id := hex.EncodeToString(bytes)

	name := filepath.Base(originalPath)
	// Create a unique folder for each item to avoid collisions of files with same name
	itemDir := filepath.Join(m.shelfDir, id)
	if err := os.MkdirAll(itemDir, 0755); err != nil {
		return nil, err
	}
	shelfPath := filepath.Join(itemDir, name)

	// Copy the file
	if err := copyFile(originalPath, shelfPath); err != nil {
		_ = os.RemoveAll(itemDir)
		return nil, err
	}

	item := &ShelfItem{
		ID:           id,
		OriginalPath: originalPath,
		ShelfPath:    shelfPath,
		Name:         name,
		CreatedAt:    time.Now().Unix(),
	}

	query := `INSERT INTO shelf_items(id, original_path, shelf_path, name, created_at) VALUES(?, ?, ?, ?, ?)`
	_, err := m.db.Conn().Exec(query, item.ID, item.OriginalPath, item.ShelfPath, item.Name, item.CreatedAt)
	if err != nil {
		// Clean up copied file if DB insert fails
		_ = os.RemoveAll(itemDir)
		return nil, err
	}

	return item, nil
}

func (m *Manager) GetItems() ([]ShelfItem, error) {
	rows, err := m.db.Conn().Query("SELECT id, original_path, shelf_path, name, created_at FROM shelf_items ORDER BY created_at DESC")
	if err != nil {
		return []ShelfItem{}, err
	}
	defer rows.Close()

	items := []ShelfItem{}
	for rows.Next() {
		var item ShelfItem
		if err := rows.Scan(&item.ID, &item.OriginalPath, &item.ShelfPath, &item.Name, &item.CreatedAt); err != nil {
			return nil, err
		}
		// Double check if file still exists on disk
		if _, err := os.Stat(item.ShelfPath); err == nil {
			items = append(items, item)
		} else {
			// Clean up missing item from DB
			_, _ = m.db.Conn().Exec("DELETE FROM shelf_items WHERE id = ?", item.ID)
		}
	}
	return items, nil
}

func (m *Manager) Remove(id string) error {
	var shelfPath string
	err := m.db.Conn().QueryRow("SELECT shelf_path FROM shelf_items WHERE id = ?", id).Scan(&shelfPath)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil
		}
		return err
	}

	// Remove parent dir of the file in shelf (which is shelfDir/id)
	if shelfPath != "" {
		itemDir := filepath.Dir(shelfPath)
		if filepath.Base(itemDir) == id { // safety check
			_ = os.RemoveAll(itemDir)
		}
	}

	_, err = m.db.Conn().Exec("DELETE FROM shelf_items WHERE id = ?", id)
	return err
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()

	if _, err = io.Copy(out, in); err != nil {
		return err
	}

	return out.Sync()
}
