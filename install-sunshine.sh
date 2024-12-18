# Step 1: Install Sunshine
echo "Installing Sunshine..."
mkdir -p /userdata/system
wget -q -O /userdata/system/sunshine.AppImage  https://github.com/DTJW92/Remote-desktop/raw/main/sunshine.AppImage

chmod a+x /userdata/system/sunshine.AppImage

# Create a persistent configuration directory
mkdir -p /userdata/system/sunshine-config
mkdir -p /userdata/system/logs

# Configure Sunshine as a service
echo "Configuring Sunshine service..."
mkdir -p /userdata/system/services
cat << 'EOF' > /userdata/system/services/sunshine
#!/bin/bash
#
# sunshine service script for Batocera
# Functional start/stop/restart(update)/status/uninstall

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0


# Directories and file paths
app_dir="/userdata/system"
config_dir="${app_dir}/sunshine-config/sunshine"
config_symlink="${HOME}/.config/sunshine"
app_image="${app_dir}/sunshine.AppImage"
log_dir="${app_dir}/logs"
log_file="${log_dir}/sunshine.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): ${1} service sunshine"

case "$1" in
    start)
        echo "Starting Sunshine service..."
        # Create persistent directory for Sunshine config
        mkdir -p "${config_dir}"

        # Move existing config if present
        if [ -d "${config_symlink}" ] && [ ! -L "${config_symlink}" ]; then
            mv "${config_symlink}" "${config_dir}"
        fi

        # Ensure config directory is symlinked
        if [ ! -L "${config_symlink}" ]; then
            ln -sf "${config_dir}" "${config_symlink}"
        fi

        # Start Sunshine AppImage
        if [ -x "${app_image}" ]; then
            cd "${app_dir}"
            ./sunshine.AppImage > "${log_file}" 2>&1 &
            echo "Sunshine started successfully."
        else
            echo "Sunshine.AppImage not found or not executable."
            exit 1
        fi
        ;;
    stop)
        echo "Stopping Sunshine service..."
        # Stop the specific processes for sunshine.AppImage
        pkill -f "./sunshine.AppImage" && echo "Sunshine stopped." || echo "Sunshine is not running."
        pkill -f "/tmp/.mount_sunshi" && echo "Sunshine child process stopped." || echo "Sunshine child process is not running."
        ;;
    restart)
        echo "Restarting Sunshine service..."
        "$0" stop
        rm -f "${app_image}"
        curl -L https://bit.ly/BatoceraSunshine | bash
        "$0" start
        ;;
    status)
        if pgrep -f "sunshine.AppImage" > /dev/null; then
            echo "Sunshine is running."
            exit 0
        else
            echo "Sunshine is stopped."
            exit 1
        fi
        ;;
    uninstall)
        echo "Uninstalling Sunshine service..."
        "$0" stop
        rm -f "${app_image}"
        rm -rf "${config_symlink}" "${config_dir}"
        echo "Sunshine uninstalled successfully."
        ;;
    *)
        echo "Usage: $0 {start|stop|restart(update)|status|uninstall}"
        exit 1
        ;;
esac

exit $?

EOF

chmod +x /userdata/system/services/sunshine

echo "Applying Nvidia patches for a smoother experience..."
# Apply Nvidia patches if necessary
curl -L https://github.com/DTJW92/Remote-desktop/raw/main/nvidia-patches.sh | bash

# Enable and start the Sunshine service
batocera-services enable sunshine
batocera-services start sunshine

clear

echo "Installation complete! Please head to https://YOUR-MACHINE-IP:47990 to pair Sunshine with Moonlight."
