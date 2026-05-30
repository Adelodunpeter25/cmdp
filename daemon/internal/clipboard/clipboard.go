package clipboard

import (
	"crypto/rand"
	"encoding/hex"
	"log"
	"time"

	"github.com/Adelodunpeter25/cmdp/daemon/internal/indexer"
)

type ClipboardItem struct {
	ID        string `json:"id"`
	Content   string `json:"content"`
	CreatedAt int64  `json:"created_at"`
}

type Manager struct {
	db *indexer.DB
}

func NewManager(db *indexer.DB) *Manager {
	return &Manager{
		db: db,
	}
}

func (m *Manager) Save(content string) {
	if content == "" {
		return
	}

	// Check if this matches the last saved item to avoid duplicate entries
	var lastContent string
	err := m.db.Conn().QueryRow("SELECT content FROM clipboard_items ORDER BY created_at DESC LIMIT 1").Scan(&lastContent)
	if err == nil && lastContent == content {
		return
	}

	bytes := make([]byte, 8)
	_, _ = rand.Read(bytes)
	id := hex.EncodeToString(bytes)
	createdAt := time.Now().Unix()

	query := `INSERT INTO clipboard_items(id, content, created_at) VALUES(?, ?, ?)`
	_, err = m.db.Conn().Exec(query, id, content, createdAt)
	if err != nil {
		log.Printf("Clipboard Manager: Failed to save item: %v", err)
	}

	// Prune history to limit size (e.g. keep last 100)
	_, _ = m.db.Conn().Exec("DELETE FROM clipboard_items WHERE id NOT IN (SELECT id FROM clipboard_items ORDER BY created_at DESC LIMIT 100)")
}

func (m *Manager) GetItems() []ClipboardItem {
	rows, err := m.db.Conn().Query("SELECT id, content, created_at FROM clipboard_items ORDER BY created_at DESC")
	if err != nil {
		log.Printf("Clipboard Manager: GetItems query error: %v", err)
		return []ClipboardItem{}
	}
	defer rows.Close()

	items := []ClipboardItem{}
	for rows.Next() {
		var item ClipboardItem
		if err := rows.Scan(&item.ID, &item.Content, &item.CreatedAt); err != nil {
			log.Printf("Clipboard Manager: Scan error: %v", err)
			continue
		}
		items = append(items, item)
	}
	return items
}

func (m *Manager) Delete(id string) error {
	_, err := m.db.Conn().Exec("DELETE FROM clipboard_items WHERE id = ?", id)
	return err
}
