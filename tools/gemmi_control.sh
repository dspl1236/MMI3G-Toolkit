#!/bin/sh
# GEMMI Google Earth Control Script
# Called from GEM engineering menu or manually
# Usage: gemmi_control.sh [start|stop|restart|status]

GEMMI_DIR="/mnt/nav/gemmi"
SERVER_PID_FILE="/tmp/gemmi_server.pid"
LOG="/tmp/gemmi_ge.log"

case "$1" in
  start)
    echo "Starting GE server..." >> $LOG
    $GEMMI_DIR/gemmi_server.sh &
    echo $! > $SERVER_PID_FILE
    echo "GE server started (PID $(cat $SERVER_PID_FILE))" >> $LOG
    ;;
  stop)
    echo "Stopping GE server..." >> $LOG
    if [ -f $SERVER_PID_FILE ]; then
      kill $(cat $SERVER_PID_FILE) 2>/dev/null
      rm $SERVER_PID_FILE
    fi
    slay gemmi_final 2>/dev/null
    echo "Stopped." >> $LOG
    ;;
  restart)
    $0 stop
    sleep 1
    $0 start
    sleep 2
    # GEMMI auto-restarts via run_gemmi.sh
    echo "Restarted." >> $LOG
    ;;
  status)
    if [ -f $SERVER_PID_FILE ] && kill -0 $(cat $SERVER_PID_FILE) 2>/dev/null; then
      echo "GE server: RUNNING (PID $(cat $SERVER_PID_FILE))"
    else
      echo "GE server: STOPPED"
    fi
    if pidin ar 2>/dev/null | grep -q gemmi_final; then
      echo "GEMMI: RUNNING"
    else
      echo "GEMMI: STOPPED"
    fi
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status}"
    ;;
esac
