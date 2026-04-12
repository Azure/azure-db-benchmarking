#!/bin/bash
# =============================================================================
# HandleResponse Stall Diagnostics — Client VM + Envoy Stats Collector
# Run this on the client VM that has both the Python SDK and Envoy proxy
# Usage: ./collect_diagnostics.sh [envoy_admin_port] [duration_minutes]
# Example: ./collect_diagnostics.sh 9901 60
# =============================================================================

ENVOY_ADMIN_PORT="${1:-9901}"
DURATION_MINUTES="${2:-60}"
POLL_INTERVAL=60
OUTPUT_DIR="./handle_response_diagnostics_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$OUTPUT_DIR"

echo "=== HandleResponse Stall Diagnostics ==="
echo "Envoy admin port: $ENVOY_ADMIN_PORT"
echo "Duration: ${DURATION_MINUTES} minutes"
echo "Poll interval: ${POLL_INTERVAL}s"
echo "Output dir: $OUTPUT_DIR"
echo "Started at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# ENVOY STATS — key metrics to track
# ─────────────────────────────────────────────────────────────────────────────
ENVOY_STATS_FILE="$OUTPUT_DIR/envoy_stats.csv"
cat > "$OUTPUT_DIR/envoy_stats_keys.txt" << 'EOF'
upstream_flow_control_paused_reading_total
upstream_flow_control_resumed_reading_total
upstream_flow_control_backed_up_total
downstream_flow_control_paused_reading_total
downstream_flow_control_resumed_reading_total
upstream_cx_active
upstream_cx_connect_fail
upstream_cx_destroy
upstream_cx_destroy_with_active_rq
upstream_cx_total
upstream_cx_overflow
upstream_rq_active
upstream_rq_pending_active
upstream_rq_pending_overflow
upstream_rq_timeout
upstream_rq_total
upstream_rq_retry
upstream_rq_reset
upstream_rq_rx_reset
upstream_rq_tx_reset
downstream_cx_active
downstream_cx_total
downstream_rq_active
downstream_rq_total
http2.streams_active
http2.pending_send_bytes
http2.tx_flood
server.watchdog_miss
server.watchdog_mega_miss
server.concurrency
server.total_connections
EOF

echo "timestamp,metric,value" > "$ENVOY_STATS_FILE"

collect_envoy_stats() {
    local ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local stats_output
    stats_output=$(curl -s "http://localhost:${ENVOY_ADMIN_PORT}/stats" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$stats_output" ]; then
        echo "$ts,envoy_unreachable,1" >> "$ENVOY_STATS_FILE"
        return
    fi

    while IFS= read -r key; do
        local value=$(echo "$stats_output" | grep -E "^.*${key}" | head -20)
        if [ -n "$value" ]; then
            while IFS=': ' read -r metric val; do
                [ -n "$metric" ] && [ -n "$val" ] && echo "$ts,$metric,$val" >> "$ENVOY_STATS_FILE"
            done <<< "$value"
        fi
    done < "$OUTPUT_DIR/envoy_stats_keys.txt"
}

# ─────────────────────────────────────────────────────────────────────────────
# TCP CONNECTION STATE — detect Recv-Q backup (SDK not reading)
# ─────────────────────────────────────────────────────────────────────────────
TCP_STATS_FILE="$OUTPUT_DIR/tcp_stats.csv"
echo "timestamp,state,recv_q,send_q,local,remote" > "$TCP_STATS_FILE"

collect_tcp_stats() {
    local ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Connections with non-zero Recv-Q (data sitting unread — SDK not consuming)
    ss -tnpi state established 2>/dev/null | awk -v ts="$ts" '
    /^ESTAB/ {
        split($0, a, " ")
        recv_q = a[2]
        send_q = a[3]
        local = a[4]
        remote = a[5]
        if (recv_q > 0 || send_q > 65536) {
            printf "%s,ESTAB,%s,%s,%s,%s\n", ts, recv_q, send_q, local, remote
        }
    }' >> "$TCP_STATS_FILE"
    
    # Summary: total connections, connections with Recv-Q > 0, max Recv-Q
    local summary=$(ss -tnp state established 2>/dev/null | awk '
    /^ESTAB/ {
        total++
        recv_q = $2
        send_q = $3
        if (recv_q > 0) recv_q_nonzero++
        if (recv_q > max_recv_q) max_recv_q = recv_q
        if (send_q > 0) send_q_nonzero++
        if (send_q > max_send_q) max_send_q = send_q
    }
    END {
        printf "%d,%d,%d,%d,%d", total, recv_q_nonzero, max_recv_q, send_q_nonzero, max_send_q
    }')
    echo "$ts,SUMMARY,$summary" >> "$TCP_STATS_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
# PYTHON PROCESS STATS — CPU, memory, threads, GC
# ─────────────────────────────────────────────────────────────────────────────
PYTHON_STATS_FILE="$OUTPUT_DIR/python_stats.csv"
echo "timestamp,pid,cpu_pct,mem_rss_mb,threads,status" > "$PYTHON_STATS_FILE"

collect_python_stats() {
    local ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Find python processes
    ps aux 2>/dev/null | grep -i python | grep -v grep | awk -v ts="$ts" '{
        pid = $2
        cpu = $3
        mem_kb = $6
        mem_mb = mem_kb / 1024
        threads = "-"
        status = $8
        printf "%s,%s,%s,%.1f,%s,%s\n", ts, pid, cpu, mem_mb, threads, status
    }' >> "$PYTHON_STATS_FILE"
    
    # Thread count per python process
    for pid in $(pgrep -f python 2>/dev/null); do
        local thread_count=$(ls /proc/$pid/task 2>/dev/null | wc -l)
        local fd_count=$(ls /proc/$pid/fd 2>/dev/null | wc -l)
        echo "$ts,$pid,threads=$thread_count,fds=$fd_count" >> "$PYTHON_STATS_FILE"
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# SYSTEM STATS — CPU, memory, network
# ─────────────────────────────────────────────────────────────────────────────
SYSTEM_STATS_FILE="$OUTPUT_DIR/system_stats.csv"
echo "timestamp,metric,value" > "$SYSTEM_STATS_FILE"

collect_system_stats() {
    local ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # CPU
    local cpu_idle=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $8}' | sed 's/%//;s/,//')
    echo "$ts,cpu_idle_pct,$cpu_idle" >> "$SYSTEM_STATS_FILE"
    
    # Memory
    local mem_info=$(free -m 2>/dev/null | awk '/Mem:/ {printf "%d,%d,%d", $2, $3, $7}')
    echo "$ts,mem_total_avail_free_mb,$mem_info" >> "$SYSTEM_STATS_FILE"
    
    # Network: total TCP connections
    local tcp_total=$(ss -s 2>/dev/null | grep "^TCP:" | awk '{print $2}')
    echo "$ts,tcp_total,$tcp_total" >> "$SYSTEM_STATS_FILE"
    
    # Load average
    local loadavg=$(cat /proc/loadavg 2>/dev/null | awk '{print $1","$2","$3}')
    echo "$ts,loadavg_1_5_15,$loadavg" >> "$SYSTEM_STATS_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
# ENVOY FULL STATS DUMP — snapshot for post-analysis
# ─────────────────────────────────────────────────────────────────────────────
dump_envoy_full_stats() {
    local ts=$(date -u +%Y%m%d_%H%M%S)
    curl -s "http://localhost:${ENVOY_ADMIN_PORT}/stats" > "$OUTPUT_DIR/envoy_full_dump_${ts}.txt" 2>/dev/null
    curl -s "http://localhost:${ENVOY_ADMIN_PORT}/clusters" > "$OUTPUT_DIR/envoy_clusters_${ts}.txt" 2>/dev/null
    curl -s "http://localhost:${ENVOY_ADMIN_PORT}/server_info" > "$OUTPUT_DIR/envoy_server_info_${ts}.txt" 2>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN LOOP
# ─────────────────────────────────────────────────────────────────────────────
END_TIME=$(($(date +%s) + DURATION_MINUTES * 60))
ITERATION=0

# Initial full dump
echo "[$(date -u +%H:%M:%S)] Taking initial Envoy full stats dump..."
dump_envoy_full_stats

# ─────────────────────────────────────────────────────────────────────────────
# NOTE: Envoy access logs are NOT captured by this script to avoid disk bloat.
# Instead, we track aggregate counters (upstream_cx_destroy_with_active_rq,
# upstream_rq_reset etc.) via the stats endpoint to detect lost responses.
# If you need per-request access logs, tail Envoy stdout with a jq filter:
#   <envoy_stdout> | jq -c 'select(.resp_flags != "-" and .resp_flags != "")' >> anomalies.json
# ─────────────────────────────────────────────────────────────────────────────

echo "[$(date -u +%H:%M:%S)] Starting collection loop (Ctrl+C to stop)..."
echo ""

while [ $(date +%s) -lt $END_TIME ]; do
    ITERATION=$((ITERATION + 1))
    TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    echo -n "[$TS] Collecting #${ITERATION}... "
    
    collect_envoy_stats
    collect_tcp_stats
    collect_python_stats
    collect_system_stats
    
    # Full dump every 5 minutes
    if [ $((ITERATION % 5)) -eq 0 ]; then
        dump_envoy_full_stats
        echo "done (+ full dump)"
    else
        echo "done"
    fi
    
    sleep $POLL_INTERVAL
done

# Final full dump
echo ""
echo "[$(date -u +%H:%M:%S)] Taking final Envoy full stats dump..."
dump_envoy_full_stats

echo ""
echo "=== Collection complete ==="
echo "Output: $OUTPUT_DIR/"
echo "Files:"
ls -la "$OUTPUT_DIR/"
echo ""
echo "Key files to analyze:"
echo "  $ENVOY_STATS_FILE         — Envoy flow control + connection metrics (60s intervals)"
echo "  $TCP_STATS_FILE            — TCP Recv-Q/Send-Q (connections where SDK isn't reading)"
echo "  $PYTHON_STATS_FILE         — Python process CPU/memory/threads"
echo "  $SYSTEM_STATS_FILE         — System CPU/memory/load"
echo "  $OUTPUT_DIR/envoy_full_dump_*.txt  — Full Envoy stats snapshots"
echo ""
echo "Quick analysis after upgrade:"
echo ""
echo "  # Did Envoy pause reading from upstream (backpressure)?"
echo "  grep 'flow_control_paused' $ENVOY_STATS_FILE | tail -20"
echo ""
echo "  # Were connections destroyed with active requests (lost responses)?"
echo "  grep 'destroy_with_active_rq' $ENVOY_STATS_FILE | tail -20"
echo ""
echo "  # Were requests reset mid-response?"
echo "  grep 'rq_reset\|rq_rx_reset\|rq_tx_reset' $ENVOY_STATS_FILE | tail -20"
echo ""
echo "  # Were there TCP Recv-Q backups (SDK not reading)?"
echo "  grep 'SUMMARY' $TCP_STATS_FILE | awk -F, '{if(\$4>0) print}'"
echo ""
echo "  # Did Envoy worker threads stall?"
echo "  grep 'watchdog' $ENVOY_STATS_FILE | awk -F, '{if(\$3>0) print}'"
