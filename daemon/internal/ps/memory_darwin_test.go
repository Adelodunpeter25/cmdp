//go:build darwin

package ps

import (
	"testing"
)

func TestGetUsedMemoryDarwin(t *testing.T) {
	usedMem, err := getUsedMemory()
	if err != nil {
		t.Fatalf("failed to get used memory: %v", err)
	}

	t.Logf("Calculated Used Memory via Activity Monitor formula: %.2f GB (%d bytes)", float64(usedMem)/1024/1024/1024, usedMem)

	if usedMem == 0 {
		t.Errorf("expected usedMem to be > 0")
	}
}
