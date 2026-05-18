package utils

import (
	"testing"
)

func TestParseAppInfo_RealApps(t *testing.T) {
	testCases := []struct {
		path string
	}{
		{"/System/Applications/Calculator.app"},
		{"/Applications/Google Chrome.app"},
		{"/Applications/Figma.app"},
		{"/Applications/Xcode.app"},
	}

	for _, tc := range testCases {
		name, icon := ParseAppInfo(tc.path)
		t.Logf("App: %s -> Name: %s, Icon: %s", tc.path, name, icon)
		if name == "" {
			t.Errorf("Failed to parse name for %s", tc.path)
		}
	}
}
