//go:build !darwin

package ps

import (
	"github.com/shirou/gopsutil/v3/mem"
)

func getUsedMemory() (uint64, error) {
	vMem, err := mem.VirtualMemory()
	if err != nil {
		return 0, err
	}
	return vMem.Used, nil
}
