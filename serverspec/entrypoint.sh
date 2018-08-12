#!/usr/bin/env sh

set -e

# sanitize_cgroups, start_docker and stop_docker are taken from https://github.com/concourse/docker-image-resource
# https://raw.githubusercontent.com/concourse/docker-image-resource/master/LICENSE

sanitize_cgroups() {
  mkdir -p /sys/fs/cgroup
  mountpoint -q /sys/fs/cgroup || \
    mount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup

  mount -o remount,rw /sys/fs/cgroup

  sed -e 1d /proc/cgroups | while read sys hierarchy num enabled; do
    if [ "$enabled" != "1" ]; then
      # subsystem disabled; skip
      continue
    fi

    grouping="$(cat /proc/self/cgroup | cut -d: -f2 | grep "\\<$sys\\>")" || true
    if [ -z "$grouping" ]; then
      # subsystem not mounted anywhere; mount it on its own
      grouping="$sys"
    fi

    mountpoint="/sys/fs/cgroup/$grouping"

    mkdir -p "$mountpoint"

    # clear out existing mount to make sure new one is read-write
    if mountpoint -q "$mountpoint"; then
      umount "$mountpoint"
    fi

    mount -n -t cgroup -o "$grouping" cgroup "$mountpoint"

    if [ "$grouping" != "$sys" ]; then
      if [ -L "/sys/fs/cgroup/$sys" ]; then
        rm "/sys/fs/cgroup/$sys"
      fi

      ln -s "$mountpoint" "/sys/fs/cgroup/$sys"
    fi
  done

  if ! test -e /sys/fs/cgroup/systemd ; then
    mkdir /sys/fs/cgroup/systemd
    mount -t cgroup -o none,name=systemd none /sys/fs/cgroup/systemd
  fi
}

start_docker() {
  mkdir -p /var/log
  mkdir -p /var/run

  sanitize_cgroups

  # check for /proc/sys being mounted readonly, as systemd does
  if grep '/proc/sys\s\+\w\+\s\+ro,' /proc/mounts >/dev/null; then
    mount -o remount,rw /proc/sys
  fi

  local mtu=$(cat /sys/class/net/$(ip route get 8.8.8.8|awk '{ print $5 }')/mtu)

dockerd \
  --mtu ${mtu} \
  --data-root /scratch/docker \
  --storage-driver=overlay2 \
  --host=unix:///var/run/docker.sock \
	--host=tcp://0.0.0.0:2375 >/tmp/docker.log 2>&1 &

  echo $! > /tmp/docker.pid

  trap stop_docker EXIT

  sleep 1

  if ! docker info >/dev/null 2>&1; then
    echo waiting for docker to come up...
    until docker info >/dev/null 2>&1; do
      sleep 1
    done
  fi
}

stop_docker() {
  local pid=$(cat /tmp/docker.pid)
  if [ -z "$pid" ]; then
    return 0
  fi

  kill -TERM $pid
}


start_docker

# docker load -i ./images/* > /dev/null

exec $@
