#!/usr/bin/env bash
# Memory report for running quickshell instances; PSS is the number to compare
# across config changes (RSS overcounts shared libraries).
for pid in $(pgrep -x quickshell); do
	echo "== pid $pid"
	grep -E '^(Rss|Pss|Pss_Anon|Pss_File|Private_Dirty|Swap):' "/proc/$pid/smaps_rollup"
done
