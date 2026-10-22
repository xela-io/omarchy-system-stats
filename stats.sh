#!/bin/sh
# Usage: stats.sh static|bar|details [hwlog]
#   static   hardware facts that never change; read once at startup
#   bar      only what the bar shows besides CPU/RAM (GPU load)
#   details  everything the open popup shows that changes over time
#   hwlog    bar mode also reads the hwlog CSV (details always does)
mode=${1:-details}

gpu_query() {
  nvidia-smi --query-gpu="$1" --format=csv,noheader,nounits 2>/dev/null | head -n1
}

# Optional: newest row of a hwlog CSV ($HWLOG_DIR/YYYY-MM-DD.csv), which
# provides values nvidia-smi cannot (GPU hotspot, VRAM temp) plus SoC voltage.
# Columns are looked up by header name; rows older than 60 s are ignored.
hwlog() {
  log="${HWLOG_DIR:-$HOME/hwlog}/$(date +%F).csv"
  [ -r "$log" ] || return 0
  [ $(($(date +%s) - $(stat -c %Y "$log"))) -lt 60 ] || return 0
  { head -n1 "$log"; tail -n1 "$log"; } | awk -F, '
    NR == 1 { for (i = 1; i <= NF; i++) col[$i] = i; next }
    {
      if (col["gpu_hotspot_c"]) printf "gpu_hotspot=%s\n", $col["gpu_hotspot_c"]
      if (col["gpu_vram_c"]) printf "vram_temp=%s\n", $col["gpu_vram_c"]
      if (col["gpu_tlimit_margin_c"]) printf "gpu_tlimit=%s\n", $col["gpu_tlimit_margin_c"]
      if (col["soc_vddnb_v"]) printf "soc_voltage=%s\n", $col["soc_vddnb_v"]
    }'
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
  [ "${2:-}" = hwlog ] && hwlog
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
  hwlog
  ;;
*)
  echo "usage: $0 static|bar|details" >&2
  exit 2
  ;;
esac
