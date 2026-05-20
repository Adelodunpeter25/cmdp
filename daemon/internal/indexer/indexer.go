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
	Name       string    `json:"Name"`
	Path       string    `json:"Path"`
	IconPath   string    `json:"IconPath"`
	Type       ItemType  `json:"Type"`
	LastOpened time.Time `json:"LastOpened"`
	Frequency  int       `json:"Frequency"`
}
