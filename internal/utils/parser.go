package utils

import (
	"os"
	"path/filepath"

	"howett.net/plist"
)

// ParseAppInfo attempts to find the Display Name and Icon File in Info.plist
// It handles both XML and Binary Apple Plist formats.
func ParseAppInfo(appPath string) (string, string) {
	plistPath := filepath.Join(appPath, "Contents", "Info.plist")
	
	file, err := os.Open(plistPath)
	if err != nil {
		return filepath.Base(appPath), ""
	}
	defer file.Close()

	var data map[string]interface{}
	decoder := plist.NewDecoder(file)
	err = decoder.Decode(&data)
	if err != nil {
		return filepath.Base(appPath), ""
	}

	name := ""
	// Try CFBundleDisplayName first, then CFBundleName
	if val, ok := data["CFBundleDisplayName"].(string); ok && val != "" {
		name = val
	} else if val, ok := data["CFBundleName"].(string); ok && val != "" {
		name = val
	} else {
		name = filepath.Base(appPath)
	}

	iconFile := ""
	if val, ok := data["CFBundleIconFile"].(string); ok && val != "" {
		iconFile = val
	}

	return name, iconFile
}
