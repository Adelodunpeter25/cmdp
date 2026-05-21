//go:build darwin

package ps

import (
	"os/exec"
	"strconv"
	"strings"

	"golang.org/x/sys/unix"
)

func getUsedMemory() (uint64, error) {
	val32, err := unix.SysctlUint32("vm.page_pageable_internal_count")
	if err != nil {
		return 0, err
	}

	out, err := exec.Command("vm_stat").Output()
	if err != nil {
		return 0, err
	}

	lines := strings.Split(string(out), "\n")
	var purgeable, wired, compressor uint64
	pageSize := uint64(unix.Getpagesize())

	for _, line := range lines {
		fields := strings.Split(line, ":")
		if len(fields) < 2 {
			continue
		}
		key := strings.TrimSpace(fields[0])
		value := strings.Trim(fields[1], " .")
		val, err := strconv.ParseUint(value, 10, 64)
		if err != nil {
			continue
		}

		switch key {
		case "Pages purgeable":
			purgeable = val * pageSize
		case "Pages wired down":
			wired = val * pageSize
		case "Pages occupied by compressor":
			compressor = val * pageSize
		}
	}

	appMemory := (uint64(val32) - (purgeable / pageSize)) * pageSize
	usedMemory := appMemory + wired + compressor
	return usedMemory, nil
}
