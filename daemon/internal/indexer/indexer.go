package indexer

import (
	"time"
)

type ItemType string

const (
	TypeApp    ItemType = "app"
	TypeFolder ItemType = "folder"
)

type IndexItem struct {
	Name       string
	Path       string
	IconPath   string
	Type       ItemType
	LastOpened time.Time
	Frequency  int
}
