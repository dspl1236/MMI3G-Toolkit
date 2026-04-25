#!/bin/sh
# Mini HTTP server for GEMMI — serves dbRoot + auth locally
# Uses nc.shle (QNX netcat) to handle HTTP requests
# Tiles go directly to kh.google.com via car's internet
#
# This server handles ONLY:
#   GET /dbRoot.v5  → dbRoot_custom.bin (local)
#   POST /geauth    → auth response (local)
#   GET /flatfile   → 302 redirect to kh.google.com (car fetches direct)

GE_DIR="/mnt/nav/gemmi"
PORT=80
FIFO="/tmp/gemmi_server_fifo"

# Create named pipe for nc
rm -f $FIFO
mkfifo $FIFO 2>/dev/null || { echo "mkfifo not available"; exit 1; }

serve_one() {
    # Read HTTP request
    read -r METHOD PATH PROTO < $FIFO
    # Strip carriage return
    PATH=$(echo "$PATH" | tr -d '\r')
    METHOD=$(echo "$METHOD" | tr -d '\r')
    
    # Read remaining headers (consume them)
    CONTENT_LENGTH=0
    while read -r LINE < $FIFO; do
        LINE=$(echo "$LINE" | tr -d '\r')
        case "$LINE" in
            Content-Length:*|content-length:*)
                CONTENT_LENGTH=$(echo "$LINE" | awk '{print $2}')
                ;;
            "") break ;;
        esac
    done
    
    case "$PATH" in
        /dbRoot*|/dbroot*)
            # Serve custom dbRoot
            SIZE=$(wc -c < "$GE_DIR/dbRoot_custom.bin")
            printf "HTTP/1.0 200 OK\r\nContent-Length: %d\r\nContent-Type: application/octet-stream\r\n\r\n" "$SIZE"
            cat "$GE_DIR/dbRoot_custom.bin"
            ;;
        /geauth*)
            # Serve cached auth response
            if [ "$CONTENT_LENGTH" -ge 49 ] 2>/dev/null; then
                AUTH_FILE="$GE_DIR/auth_resp2.bin"
            else
                AUTH_FILE="$GE_DIR/auth_resp1.bin"
            fi
            SIZE=$(wc -c < "$AUTH_FILE")
            printf "HTTP/1.0 200 OK\r\nContent-Length: %d\r\nContent-Type: application/octet-stream\r\n\r\n" "$SIZE"
            cat "$AUTH_FILE"
            ;;
        /flatfile*)
            # Redirect to real Google Earth server
            printf "HTTP/1.0 302 Found\r\nLocation: https://kh.google.com%s\r\nContent-Length: 0\r\n\r\n" "$PATH"
            ;;
        *)
            printf "HTTP/1.0 404 Not Found\r\nContent-Length: 0\r\n\r\n"
            ;;
    esac
}

echo "GEMMI mini-server starting on port $PORT..."

while true; do
    cat $FIFO | nc.shle -l $PORT > $FIFO 2>/dev/null &
    wait
done
