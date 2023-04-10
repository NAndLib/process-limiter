#!/bin/bash

# Configuration file for monitored processes and their time limits
LOG_DIR="$HOME/.cache/process-limiter"
if ! [ -d "$LOG_DIR" ]; then
  mkdir -p "$LOG_DIR"
fi
LOG_FILE="$LOG_DIR/manager.log"
touch "$LOG_FILE"

# Function to list all monitored processes and their time limits
list_processes() {
  echo "Monitored processes and time limits:"
  echo "----------------------------------"
  while read -r line; do
    if [[ "$line" =~ ^([^:]+):([0-9]+)$ ]]; then
      process_name="${BASH_REMATCH[1]}"
      time_limit="${BASH_REMATCH[2]}"
      total_time=$(awk -v d="$(date +%Y-%m-%d)" '$1 == d {print $3}' "$LOG_DIR/process_runtime_$process_name.log")
      echo "$process_name: ${total_time:-0}/$time_limit seconds"
    fi
  done < "$LOG_FILE"
  echo "----------------------------------"
}

# Function to start monitoring a process
start_monitoring() {
  # Get process name and time limit from arguments
  process_name="$1"
  time_limit="$2"

  # Check if process is already being monitored
  if grep -q "^${process_name}:" "$LOG_FILE"; then
    echo "Process $process_name is already being monitored."
    return 1
  fi

  # Add process to configuration file
  echo "${process_name}:${time_limit}" >> "$LOG_FILE"
  echo "Started monitoring process $process_name with time limit $time_limit seconds."

  # Launch process monitoring script in the background
  ./process_monitor.sh "$process_name" "$time_limit" &
}

# Function to stop monitoring a process
stop_monitoring() {
  # Get process name from argument
  process_name="$1"

  # Check if process is being monitored
  if ! grep -q "^${process_name}:" "$LOG_FILE"; then
    echo "Process $process_name is not being monitored."
    return 1
  fi

  # Remove process from configuration file
  sed -i "/^${process_name}:/d" "$LOG_FILE"
  echo "Stopped monitoring process $process_name."

  # Kill process monitoring script if it is running
  pid=$(pgrep -f "process_monitor.sh $process_name")
  if [ -n "$pid" ]; then
    kill "$pid"
    echo "Killed process monitoring script with PID $pid."
  fi
}

# Parse command-line arguments
case "$1" in
  "list")
    list_processes
    ;;
  "start")
    if [ $# -lt 3 ]; then
      echo "Usage: $0 start PROCESS_NAME TIME_LIMIT"
      exit 1
    fi
    start_monitoring "$2" "$3"
    ;;
  "stop")
    if [ $# -lt 2 ]; then
      echo "Usage: $0 stop PROCESS_NAME"
      exit 1
    fi
    stop_monitoring "$2"
    ;;
  *)
    echo "Usage: $0 {list|start|stop} [arguments...]"
    exit 1
esac
