package indexer

// GetCommands returns the list of system commands.
func GetCommands() []IndexItem {
	return []IndexItem{
		{
			Name: "Sleep",
			Path: "sleep",
			Type: TypeCommand,
		},
		{
			Name: "Restart...",
			Path: "restart",
			Type: TypeCommand,
		},
		{
			Name: "Shut Down...",
			Path: "shutdown",
			Type: TypeCommand,
		},
		{
			Name: "Lock Screen",
			Path: "lock",
			Type: TypeCommand,
		},
		{
			Name: "Empty Trash",
			Path: "empty-trash",
			Type: TypeCommand,
		},
		{
			Name: "Reset Index",
			Path: "reset-index",
			Type: TypeCommand,
		},
	}
}
