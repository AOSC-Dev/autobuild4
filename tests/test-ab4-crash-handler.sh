#!/bin/bash -e
bash -c 'source "ab4-prelude.sh" && kill -SEGV $$; exit 1' | tee test-crash.log &
echo "Sub-process PID: $!"
sleep 1
kill -KILL "$!" || true
wait "$!" || true

# Check if the sub-process crashed
if grep -q 'signal 11' test-crash.log; then
  echo "Sub-process crashed as expected with a segmentation fault"
else
  echo "Sub-process did not crash as expected"
  exit 1
fi