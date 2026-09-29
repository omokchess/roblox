#!/usr/bin/env bash
# job.sh <스크립트> — StudioJobs 폴러가 실행하도록 run.luau 에 복사하고 job.txt 도장을 바꾼다. (2026-09-29)
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cp "$1" "$HERE/swamp/run.luau"
date +%s%N > "$HERE/swamp/job.txt"
