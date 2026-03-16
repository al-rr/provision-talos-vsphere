#!/usr/bin/env bash
set -euxo pipefail

# Create /srv/containers FS if free space or /dev/sda available
PART_DEV="/dev/sda"
MOUNTPOINT="/srv/containers"

mkdir -p "$MOUNTPOINT"

if lsblk -f "$PART_DEV" >/dev/null 2>&1; then
  # find free space and create new partition at the end if possible
  if command -v parted >/dev/null 2>&1; then
    parted -s "$PART_DEV" print free
    # try to create last partition if there's free space > 5GB
    # (naive approach: create a new primary using last 20%)
    parted -s "$PART_DEV" -- mkpart primary xfs 80% 100% || true
    partprobe || true
  fi

  # pick the last partition as candidate
  NEW_PART="$(lsblk -ln "$PART_DEV" | awk '/part/ {print $1}' | tail -n1)"
  if [ -n "$NEW_PART" ] && [ -b "/dev/$NEW_PART" ]; then
    mkfs.xfs -f "/dev/$NEW_PART"
    echo "/dev/$NEW_PART $MOUNTPOINT xfs defaults 0 0" >> /etc/fstab
    mkdir -p "$MOUNTPOINT"
    mount -a || mount "/dev/$NEW_PART" "$MOUNTPOINT"
  fi
fi

# Configure runtimes to use /srv/containers paths when available
if [ -d "$MOUNTPOINT" ] && mountpoint -q "$MOUNTPOINT"; then
  mkdir -p "$MOUNTPOINT/docker" "$MOUNTPOINT/containers"
  # Docker
  mkdir -p /etc/docker
  echo '{"data-root": "/srv/containers/docker"}' > /etc/docker/daemon.json || true

  # Podman (root)
  mkdir -p /etc/containers
  cat >/etc/containers/storage.conf <<'EOF'
[storage]
driver = "overlay"
runroot = "/var/run/containers/storage"
graphroot = "/srv/containers/containers"
[storage.options]
mount_program = "/usr/bin/fuse-overlayfs"
EOF
fi
