package ps

// ProcessInfo holds CPU and memory metrics for a single process.
type ProcessInfo struct {
	Pid    int32   `json:"pid"`
	Name   string  `json:"name"`
	CPU    float64 `json:"cpu"`
	Memory uint64  `json:"memory"` // RSS in bytes
}

// SystemStats contains overall system performance stats and lists of top resource-consuming processes.
type SystemStats struct {
	CPUUsage       float64       `json:"cpuUsage"`
	TotalMemory    uint64        `json:"totalMemory"`
	UsedMemory     uint64        `json:"usedMemory"`
	TopMemoryProcs []ProcessInfo `json:"topMemoryProcs"`
	TopCPUProcs    []ProcessInfo `json:"topCPUProcs"`
}
