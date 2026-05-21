package ps

import (
	"testing"
	"time"
)

func TestGetStats(t *testing.T) {
	manager := NewStatsManager()

	// Initial call to set CPU baseline
	stats, err := manager.GetStats()
	if err != nil {
		t.Fatalf("failed to get stats: %v", err)
	}

	if stats.TotalMemory == 0 {
		t.Errorf("expected TotalMemory to be > 0")
	}

	// Wait briefly to allow CPU delta calculations to record
	time.Sleep(100 * time.Millisecond)

	stats2, err := manager.GetStats()
	if err != nil {
		t.Fatalf("failed to get stats on second call: %v", err)
	}

	// Verify overall system load percentages are non-negative
	if stats2.CPUUsage < 0 {
		t.Errorf("expected CPUUsage to be >= 0, got %f", stats2.CPUUsage)
	}

	if stats2.TotalMemory == 0 {
		t.Errorf("expected TotalMemory on second call to be > 0")
	}

	if stats2.UsedMemory == 0 || stats2.UsedMemory > stats2.TotalMemory {
		t.Errorf("invalid UsedMemory: %d (Total: %d)", stats2.UsedMemory, stats2.TotalMemory)
	}

	// Verify top list capping works (cap to 3)
	if len(stats2.TopMemoryProcs) > 3 {
		t.Errorf("expected at most 3 top memory processes, got %d", len(stats2.TopMemoryProcs))
	}
	if len(stats2.TopCPUProcs) > 3 {
		t.Errorf("expected at most 3 top CPU processes, got %d", len(stats2.TopCPUProcs))
	}

	// Verify top lists are sorted descending
	for i := 1; i < len(stats2.TopMemoryProcs); i++ {
		if stats2.TopMemoryProcs[i-1].Memory < stats2.TopMemoryProcs[i].Memory {
			t.Errorf("TopMemoryProcs not sorted descending at index %d", i)
		}
	}

	for i := 1; i < len(stats2.TopCPUProcs); i++ {
		if stats2.TopCPUProcs[i-1].CPU < stats2.TopCPUProcs[i].CPU {
			t.Errorf("TopCPUProcs not sorted descending at index %d", i)
		}
	}
}
