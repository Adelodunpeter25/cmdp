package indexer

type ItemType string

const (
	TypeApp     ItemType = "app"
	TypeFolder  ItemType = "folder"
	TypeCommand ItemType = "command"
)

type IndexItem struct {
	Name     string   `json:"Name"`
	Path     string   `json:"Path"`
	IconPath string   `json:"IconPath"`
	Type     ItemType `json:"Type"`
}
