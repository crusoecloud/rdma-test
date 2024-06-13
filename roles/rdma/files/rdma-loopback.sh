#!/bin/bash -e

rm -rf /tmp/rdma
mkdir -p /tmp/rdma

if [ -n "$(lspci -d '8086:0d57')" ]; then
  gpu=(0 1 2 3 4 5 6 7)
  hca=(1 2 3 4 5 6 7 8)
else
  gpu=(0 1 2 3 4 5 6 7)
  hca=(5 6 7 8 0 1 2 3)
fi

rdma_loopback() {( set -e 
  pids=()

  # Start all servers.
  for i in $(seq 0 7); do
    j=$((($i + $1) % 8))
    /opt/perftest/bin/ib_write_bw -d mlx5_${hca[$j]} --use_cuda=${gpu[$j]} --report_gbits -D 2 --port $((8080 + $i)) > /dev/null &
    pids+=($!)
  done

  # Wait for all servers to start.
  sleep 1

  # Start all clients.
  for i in $(seq 0 7); do
    /opt/perftest/bin/ib_write_bw -d mlx5_${hca[$i]} --use_cuda=${gpu[$i]} --report_gbits -D 2 --port $((8080 + $i)) --out_json --out_json_file=/tmp/rdma/${hca[$i]}.json localhost > /dev/null &
    pids+=($!)
  done

  # Wait for all processes to complete.
  for pid in ${pids[@]}; do
    wait $pid
  done

  for i in $(seq 0 7); do
    echo $(jq .results.BW_average /tmp/rdma/${hca[$i]}.json)
  done
)}

for i in $(seq 0 7); do
  rdma_loopback $i | paste -sd "\t" -
done
