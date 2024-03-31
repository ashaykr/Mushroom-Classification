#!/bin/bash

# EMC test script for running multiple cameras using UVS (Unified Video Streamer) tool

if [ $# -lt 2 ]; then
    echo "Usage: $0 <path_to_json_script> <run_duration_for_camera>"
    exit 1
fi

if [ ! -e "$1" ]; then
    echo "JSON file $1 does not exist"
    exit 1
fi

DURATION=$2
JSON_FILE_PATH=$1


ihm-uvs "$JSON_FILE_PATH" 2>&1 > /dev/null &


# Check if all cameras are healthy and running
sleep 2
journalctl | grep -E "Selected Usecase: Offline IFE with sensor node: resolution stream wx hi requestId:" > /var/volatile/temp

for ((i=0; i<4; i++))
do
    CURR_RESO[$i]=$(grep "stream wxh" /var/volatile/temp | grep "camerald\": $i" | awk '{split($0, a, "stream w x h: "); print a[2]}')
    FPS[$i]=$(grep "Selected Usecase:" /var/volatile/temp | grep "camerald\": $i" | awk '{split($0,a,", FPS:"); print a[2]}' | awk '{split($0,a,", "); print a[1]}')
    frm_check[$i]=$(grep "requestId:" /var/volatile/temp | grep "camerald\": $i" | awk '{split($0,a,"<==>"); print a[2]}' | awk '{split($0,a," "); print a[2]}')

    if [ ${frm_check[$i]} -lt 20 ]; then
        echo "FAILED to start Camera $i"
        exit 1
    fi
done

echo "All cameras kicked off successfully..."

# Display average FPS for each camera over 10 seconds
for ((i=0; i<4; i++))
do
    echo "Camera $i:"
    avg_fps=0
    for ((j=1; j<=$((($DURATION+5)/10)); ++j))
    do
        sleep 10
        curr_fps=$(journalctl | grep CalculateResultFPS | grep "camerald\": $i" | tail -n 1 | awk '{split($0,a, "FPS: "); print a[2]}')
        avg_fps=$(awk "BEGIN {print $avg_fps + $curr_fps}")
    done
    avg_fps=$(awk "BEGIN {print $avg_fps / $((($DURATION+5)/10))}")
    echo "Average FPS: $avg_fps"
done

# Stop all cameras
kill -9 $(pidof ihm-uvs)
wait $(pidof ihm-uvs) 2>/dev/null
