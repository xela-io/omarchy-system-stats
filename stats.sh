#!/bin/sh
# Usage: stats.sh static|bar|details
#   static   hardware facts that never change; read once at startup
#   bar      only what the bar shows besides CPU/RAM (GPU load)
#   details  everything the open popup shows that changes over time
mode=${1:-details}

gpu_query() {
  nvidia-smi --query-gpu="$1" --format=csv,noheader,nounits 2>/dev/null | head -n1
}

case $mode in
static)
  cpu_name=$(lscpu | sed -n 's/^Model name:[[:space:]]*//p' | head -n1)
  cpu_cores=$(lscpu -p=CORE | sed '/^#/d' | sort -u | wc -l)
  cpu_threads=$(getconf _NPROCESSORS_ONLN)
  printf 'cpu_name=%s\ncpu_cores=%s\ncpu_threads=%s\n' "$cpu_name" "$cpu_cores" "$cpu_threads"
  gpu_query name,memory.total | awk -F',[[:space:]]*' '{
      printf "gpu_name=%s\n", $1
      printf "vram_total=%.1f\n", $2 / 1024
    }'
  ;;
bar)
  printf 'gpu_usage=%s\n' "$(gpu_query utilization.gpu)"
  ;;
details)
  cpu_mhz=$(awk '/cpu MHz/ { sum += $4; n++ } END { if (n) printf "%.0f", sum/n }' /proc/cpuinfo)
  printf 'cpu_mhz=%s\n' "$cpu_mhz"
  for d in /sys/class/hwmon/hwmon*; do
    [ "$(cat "$d/name" 2>/dev/null)" = k10temp ] || continue
    [ -r "$d/temp1_input" ] && printf 'cpu_temp=%s\n' "$(($(cat "$d/temp1_input") / 1000))"
    break
  done
  gpu_query utilization.gpu,temperature.gpu,memory.used,power.draw,clocks.current.graphics \
    | awk -F',[[:space:]]*' '{
        printf "gpu_usage=%s\n", $1
        printf "gpu_temp=%s\n", $2
        printf "vram_used=%.1f\n", $3 / 1024
        printf "gpu_power=%.0f\n", $4
        printf "gpu_mhz=%s\n", $5
      }'
  df -hP / | awk 'NR==2 { print "disk_total=" $2; print "disk_used=" $3; print "disk_percent=" $5 }'
  printf 'processes=%s\n' "$(ps -e --no-headers | wc -l)"
  printf 'uptime=%s\n' "$(uptime -p | sed 's/^up //')"
  ;;
*)
  echo "usage: $0 static|bar|details" >&2
  exit 2
  ;;
esac
