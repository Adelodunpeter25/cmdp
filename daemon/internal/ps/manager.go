package ps

import (
	"sort"
	"sync"

	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/mem"
	"github.com/shirou/gopsutil/v3/process"
)

// StatsManager monitors and caches running processes to accurately calculate CPU usage deltas.
type StatsManager struct {
	mu        sync.Mutex
	procCache map[int32]*process.Process
}

// NewStatsManager initializes a StatsManager.
func NewStatsManager() *StatsManager {
	return &StatsManager{
		procCache: make(map[int32]*process.Process),
	}
}

// GetStats collects the overall system CPU, Memory usage, and top resource-consuming processes.
func (m *StatsManager) GetStats() (*SystemStats, error) {
	// 1. Get virtual memory stats
	vMem, err := mem.VirtualMemory()
	if err != nil {
		return nil, err
	}

	// 2. Get CPU usage (overall, non-blocking)
	cpuPercents, err := cpu.Percent(0, false)
	var cpuUsage float64
	if err == nil && len(cpuPercents) > 0 {
		cpuUsage = cpuPercents[0]
	}

	// 3. Query all running processes
	procs, err := process.Processes()
	if err != nil {
		return nil, err
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	activePids := make(map[int32]bool)
	var procInfos []ProcessInfo

	for _, p := range procs {
		activePids[p.Pid] = true

		// Check if we have this process cached to calculate delta CPU%
		cachedProc, exists := m.procCache[p.Pid]
		if !exists {
			m.procCache[p.Pid] = p
			cachedProc = p
		}

		name, err := cachedProc.Name()
		if err != nil {
			continue
		}
		if name == "" {
			continue
		}

		// Calculate CPU usage percent on this process instance (non-blocking delta calculation)
		cpuPercent, _ := cachedProc.Percent(0)

		// Get RSS memory usage
		memInfo, err := cachedProc.MemoryInfo()
		var rss uint64
		if err == nil && memInfo != nil {
			rss = memInfo.RSS
		}

		procInfos = append(procInfos, ProcessInfo{
			Pid:    p.Pid,
			Name:   name,
			CPU:    cpuPercent,
			Memory: rss,
		})
	}

	// Remove exited processes from cache to prevent leaks
	for pid := range m.procCache {
		if !activePids[pid] {
			delete(m.procCache, pid)
		}
	}

	// 4. Sort and cap top resource users
	// Sort by CPU descending
	topCPU := make([]ProcessInfo, len(procInfos))
	copy(topCPU, procInfos)
	sort.Slice(topCPU, func(i, j int) bool {
		if topCPU[i].CPU != topCPU[j].CPU {
			return topCPU[i].CPU > topCPU[j].CPU
		}
		return topCPU[i].Pid < topCPU[j].Pid
	})
	if len(topCPU) > 3 {
		topCPU = topCPU[:3]
	} else if len(topCPU) == 0 {
		topCPU = []ProcessInfo{}
	}

	// Sort by Memory descending
	topMemory := make([]ProcessInfo, len(procInfos))
	copy(topMemory, procInfos)
	sort.Slice(topMemory, func(i, j int) bool {
		if topMemory[i].Memory != topMemory[j].Memory {
			return topMemory[i].Memory > topMemory[j].Memory
		}
		return topMemory[i].Pid < topMemory[j].Pid
	})
	if len(topMemory) > 3 {
		topMemory = topMemory[:3]
	} else if len(topMemory) == 0 {
		topMemory = []ProcessInfo{}
	}

	return &SystemStats{
		CPUUsage:       cpuUsage,
		TotalMemory:    vMem.Total,
		UsedMemory:     vMem.Used,
		TopMemoryProcs: topMemory,
		TopCPUProcs:    topCPU,
	}, nil
}
