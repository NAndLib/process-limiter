#!/bin/bash

# get the process name and time limit from the arguments
PROCESS_NAME=$1
TIME_LIMIT=$2

# create a log file for process runtime in the user's home directory
LOG_DIR="$HOME/.cache/process-limiter"
if ! [ -d "$LOG_DIR" ]; then
  mkdir -p "$LOG_DIR"
fi
LOG_FILE="$LOG_DIR/process_runtime_$PROCESS_NAME.log"
touch "$LOG_FILE"

# get the current date
TODAY=$(date +%Y-%m-%d)

notify_user() {
  local summary="$1"
  local body="$2"
  if type notify-send &>/dev/null; then
    notify-send -a "Notify Limiter" "$summary" "$body"
  else
    echo "$summary"
    echo "$body"
  fi
}

write_log() {
  local real_total="${1:-0}"
  local running_total="${2:-0}"
  echo "$(date +%Y-%m-%d) $real_total $running_total" > "$LOG_FILE"
}

# wait for the process to show up in the process table
while true; do
  PID=$(pgrep -x "$PROCESS_NAME")
  if [ -n "$PID" ]; then
    # get the start time of the process
    START_TIME=$(stat -c %Y "/proc/$PID")

    # check if the process has exceeded the time limit
    CURRENT_TIME=$(date +%s)
    RUNTIME=$((CURRENT_TIME - START_TIME))

    # get the total runtime for the current day from the log file
    TOTAL_RUNTIME=$(awk -v d="$TODAY" '$1 == d {print $2}' "$LOG_FILE")
    if [ -z "$TOTAL_RUNTIME" ]; then
      TOTAL_RUNTIME=0
    fi

    CURRENT_TOTAL=$((TOTAL_RUNTIME + RUNTIME))
    # check if the total runtime exceeds the time limit
    if [ $CURRENT_TOTAL -gt "$TIME_LIMIT" ]; then
      notify_user "Time Limit Exceeded" "$PROCESS_NAME: $CURRENT_TOTAL/$TIME_LIMIT second(s)"
      kill -9 "$PID"
      while kill -0 "$PID" &>/dev/null; do
        sleep 1
      done
      write_log "$CURRENT_TOTAL" "$CURRENT_TOTAL"
    fi
  else
    TOTAL_RUNTIME=$(awk -v d="$TODAY" '$1 == d {print $3}' "$LOG_FILE")
    if [ -z "$TOTAL_RUNTIME" ]; then
      TOTAL_RUNTIME=0
    fi
  fi
  write_log "$TOTAL_RUNTIME" "$CURRENT_TOTAL"
  sleep 10
done
