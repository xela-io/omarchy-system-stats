#!/bin/sh
awk '/^cpu / { sub(/^cpu +/, ""); print "cpu_ticks=" $0 }' /proc/stat
cpu_name=$(lscpu | sed -n 's/^Model name:[[:space:]]*//p' | head -n1)
cpu_cores=$(lscpu -p=CORE | sed '/^#/d' | sort -u | wc -l)
cpu_threads=$(getconf _NPROCESSORS_ONLN)
cpu_mhz=$(awk '/cpu MHz/ { sum += $4; n++ } END { if (n) printf "%.0f", sum/n }' /proc/cpuinfo)
printf 'cpu_name=%s\ncpu_cores=%s\ncpu_threads=%s\ncpu_mhz=%s\n' "$cpu_name" "$cpu_cores" "$cpu_threads" "$cpu_mhz"
for d in /sys/class/hwmon/hwmon*; do
  [ "$(cat "$d/name" 2>/dev/null)" = k10temp ] || continue
  [ -r "$d/temp1_input" ] && printf 'cpu_temp=%s\n' "$(($(cat "$d/temp1_input") / 1000))"
  break
done
nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,clocks.current.graphics --format=csv,noheader,nounits 2>/dev/null \
  | head -n1 \
  | awk -F',[[:space:]]*' '{
      printf "gpu_name=%s\n", $1
      printf "gpu_usage=%s\n", $2
      printf "gpu_temp=%s\n", $3
      printf "vram_used=%.1f\n", $4 / 1024
      printf "vram_total=%.1f\n", $5 / 1024
      printf "gpu_power=%.0f\n", $6
      printf "gpu_mhz=%s\n", $7
    }'
awk '/MemTotal:/ { total=$2 } /MemAvailable:/ { available=$2 } END { used=total-available; printf "ram_used=%.1f\nram_total=%.1f\nram_percent=%.0f\n", used/1048576, total/1048576, used*100/total }' /proc/meminfo
df -hP / | awk 'NR==2 { print "disk_total=" $2; print "disk_used=" $3; print "disk_percent=" $5 }'
printf 'processes=%s\n' "$(ps -e --no-headers | wc -l)"
printf 'uptime=%s\n' "$(uptime -p | sed 's/^up //')"
