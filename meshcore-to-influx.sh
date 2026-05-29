#!/bin/sh
set -eu

NODE="${1:?usage: $0 <node-name>}"
PORT="${MESHCORE_PORT:-/dev/cuaU0}"
INFLUX_URL="${INFLUX_URL:-http://10.0.0.12:8086/api/v2/write?org=Homeserver&bucket=meshcore&precision=s}"
INFLUX_TOKEN="${INFLUX_TOKEN:?INFLUX_TOKEN environment variable must be set}"

post() {
  curl -sS -X POST "$INFLUX_URL" \
    -H "Authorization: Token $INFLUX_TOKEN" \
    --data-binary "$1"
}

# Status
meshcore-cli -j -q -s "$PORT" req_status "$NODE" |
  jq -r --arg n "$NODE" '
    "meshcore_status,node=\($n) " +
    "bat=\(.bat)i," +
    "tx_queue_len=\(.tx_queue_len)i," +
    "noise_floor=\(.noise_floor)i," +
    "last_rssi=\(.last_rssi)i," +
    "last_snr=\(.last_snr)," +
    "airtime=\(.airtime)i," +
    "rx_airtime=\(.rx_airtime)i," +
    "uptime=\(.uptime)i," +
    "nb_recv=\(.nb_recv)i," +
    "nb_sent=\(.nb_sent)i," +
    "sent_flood=\(.sent_flood)i," +
    "sent_direct=\(.sent_direct)i," +
    "recv_flood=\(.recv_flood)i," +
    "recv_direct=\(.recv_direct)i," +
    "flood_dups=\(.flood_dups)i," +
    "direct_dups=\(.direct_dups)i," +
    "recv_errors=\(.recv_errors)i," +
    "full_evts=\(.full_evts)i"
  ' | while IFS= read -r line; do post "$line"; done

# Sleep a while to give the frequency some time for in between messages to arrive
sleep 5

# Telemetry (one line per LPP channel/type)
meshcore-cli -j -q -s "$PORT" req_telemetry "$NODE" |
  jq -r --arg n "$NODE" '
    .lpp[] |
    "meshcore_telemetry,node=\($n),channel=\(.channel),type=\(.type) value=\(.value)"
  ' | while IFS= read -r line; do post "$line"; done
