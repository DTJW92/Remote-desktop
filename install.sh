#!/bin/bash
export $(cat /proc/1/environ | tr '\0' '\n')

# Step 1: Install Tailscale
echo "Installing Tailscale..."
mkdir -p /userdata/temp
cd /userdata/temp || exit 1

wget -q https://pkgs.tailscale.com/stable/tailscale_1.76.1_amd64.tgz

tar -xf tailscale_1.76.1_amd64.tgz
cd tailscale_1.76.1_amd64 || exit 1

mkdir -p /userdata/tailscale

mv systemd /userdata/tailscale/systemd
mv tailscale /userdata/tailscale/tailscale
mv tailscaled /userdata/tailscale/tailscaled

# Cleanup temporary files
cd /userdata || exit 1
rm -rf /userdata/temp

# Configure Tailscale as a service
echo "Configuring Tailscale service..."
mkdir -p /userdata/system/services
cat << 'EOF' > /userdata/system/services/tailscale
#!/bin/bash

if [[ "$1" != "start" ]]; then
  exit 0
fi

# Ensure /dev/net/tun exists
if [ ! -d /dev/net ]; then
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200
  chmod 600 /dev/net/tun
fi

# Configure IP forwarding
sysctl_config="/etc/sysctl.conf"
temp_sysctl_config="/tmp/sysctl.conf"

# Backup existing sysctl.conf (if needed)
if [ -f "$sysctl_config" ]; then
  cp "$sysctl_config" "${sysctl_config}.bak"
fi

# Apply new configurations
cat <<EOL > "$temp_sysctl_config"
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOL

mv "$temp_sysctl_config" "$sysctl_config"
sysctl -p "$sysctl_config"

# Start Tailscale daemon
/userdata/tailscale/tailscaled -state /userdata/tailscale/state > /userdata/tailscale/tailscaled.log 2>&1 &

# Bring up Tailscale with specific options
/userdata/tailscale/tailscale up --advertise-routes=192.168.1.0/24 --snat-subnet-routes=false --accept-routes
EOF

chmod +x /userdata/system/services/tailscale

# Enable and start the Tailscale service
batocera-services enable tailscale
batocera-services start tailscale

# Step 2: Install Sunshine
echo "Installing Sunshine..."
mkdir -p /userdata/system
wget -O /userdata/system/sunshine.AppImage https://github.com/LizardByte/Sunshine/releases/download/v2024.1208.41026/sunshine.AppImage

chmod a+x /userdata/system/sunshine.AppImage

# Create a persistent configuration directory
mkdir -p /userdata/sunshine/config
mkdir -p /userdata/system/sunshine-config
mkdir -p /userdata/system/logs

# Configure Sunshine as a service
echo "Configuring Sunshine service..."
cat << 'EOF' > /userdata/system/services/sunshine
#!/bin/bash
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0

if [[ "$1" != "start" ]]; then
  exit 0
fi

# Create persistent directory for Sunshine config (if it doesn't exist)
mkdir -p /userdata/system/sunshine-config/Sunshine

# Check if Sunshine config exists (after the first run) and move it to persistent storage
if [ -d ~/.config/sunshine ]; then
  mv ~/.config/sunshine /userdata/system/sunshine-config/sunshine
fi

if [ ! -L ~/.config/sunshine ]; then
  ln -s /userdata/system/sunshine-config/sunshine ~/.config/sunshine
fi

# Run Sunshine
cd /userdata/system
./sunshine.AppImage > /userdata/system/logs/sunshine.log 2>&1 &

EOF

chmod +x /userdata/system/services/sunshine

# Enable and start the Sunshine service
batocera-services enable sunshine
batocera-services start sunshine

echo "Installation complete! Please head to https://YOUR-MACHINE-IP:47990 to pair Sunshine with Moonlight."
