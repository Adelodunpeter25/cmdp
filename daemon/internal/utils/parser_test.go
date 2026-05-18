package utils

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseAppInfoFallsBackToCFBundleIconName(t *testing.T) {
	root := t.TempDir()
	appPath := filepath.Join(root, "System Settings.app")
	contentsPath := filepath.Join(appPath, "Contents")
	if err := os.MkdirAll(contentsPath, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}

	plistData := []byte(`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>System Settings</string>
	<key>CFBundleIconName</key>
	<string>PrefApp</string>
</dict>
</plist>`)

	if err := os.WriteFile(filepath.Join(contentsPath, "Info.plist"), plistData, 0o644); err != nil {
		t.Fatalf("write plist: %v", err)
	}

	name, icon := ParseAppInfo(appPath)
	if name != "System Settings" {
		t.Fatalf("unexpected name: got %q", name)
	}
	if icon != "PrefApp" {
		t.Fatalf("unexpected icon: got %q", icon)
	}
}
