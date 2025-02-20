#!/bin/bash
# Script to create an MPP Installer Debian package with versioned filename

# Set version and architecture information
VERSION="1.0"
ARCH="linux-amd64"

# Create package directory structure
mkdir -p mpp-installer/DEBIAN
mkdir -p mpp-installer/usr/local/bin
mkdir -p mpp-installer/etc/systemd/system
mkdir -p mpp-installer/usr/share/mpp-installer

# Create control file
cat > mpp-installer/DEBIAN/control << EOF
Package: mpp-installer
Version: ${VERSION}
Section: net
Priority: optional
Architecture: all
Depends: bash
Maintainer: Arjun Soundarajan <arjun.s01@simplify3x.com>
Description: myphantompath Installer and Configuration
 Installs WireGuard, generates keys, and configures the interface with systemd service.
EOF

# Create systemd service file
cat > mpp-installer/etc/systemd/system/mpp.service << EOF
[Unit]
Description=MPP Secure Communication Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/wg-quick up wg0
ExecStop=/usr/bin/wg-quick down wg0

[Install]
WantedBy=multi-user.target
EOF

# Create convenience script for controlling the service
cat > mpp-installer/usr/local/bin/mpp << EOF
#!/bin/bash

# Function to check for WireGuard
check_wireguard() {
  if ! command -v wg &> /dev/null; then
    echo "WireGuard is not installed. Please run: sudo apt-get install wireguard wireguard-tools"
    exit 1
  fi
}

case "\$1" in
  start)
    check_wireguard
    systemctl start mpp
    echo "myphantompath service started"
    ;;
  stop)
    systemctl stop mpp
    echo "myphantompath service stopped"
    ;;
  status)
    systemctl status mpp
    ;;
  enable)
    systemctl enable mpp
    echo "myphantompath service enabled at boot"
    ;;
  disable)
    systemctl disable mpp
    echo "myphantompath service disabled at boot"
    ;;
  setup)
    # Ensure WireGuard is installed
    if ! command -v wg &> /dev/null; then
      echo "WireGuard is not installed. Installing now..."
      sudo apt-get install -y wireguard wireguard-tools
    fi
    
    # Generate keys if they don't exist
    if [ ! -f /etc/wireguard/keys/privatekey ]; then
      echo "Generating WireGuard keys..."
      mkdir -p /etc/wireguard/keys
      cd /etc/wireguard/keys
      wg genkey | tee privatekey | wg pubkey > publickey
      chmod 600 privatekey publickey
    fi
    
    PRIVATE_KEY=\$(cat /etc/wireguard/keys/privatekey)
    PUBLIC_KEY=\$(cat /etc/wireguard/keys/publickey)
    
    echo "Your public key: \$PUBLIC_KEY"
    read -p "Enter the server's public key: " SERVER_PUBLIC_KEY
    
    # Configure WireGuard
    cat > /etc/wireguard/wg0.conf << EOL
[Interface]
Address = 10.0.0.1/24
SaveConfig = true
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE;
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE;
ListenPort = 51820
PrivateKey = \$PRIVATE_KEY

[Peer]
PublicKey = \$SERVER_PUBLIC_KEY
AllowedIPs = 10.0.0.2/32
EOL
    chmod 600 /etc/wireguard/wg0.conf
    
    # Setup service
    systemctl daemon-reload
    systemctl enable mpp.service
    echo "myphantompath service setup complete and enabled at boot."
    ;;
  *)
    echo "Usage: mpp {start|stop|status|enable|disable|setup}"
    exit 1
    ;;
esac
exit 0
EOF

# Make convenience script executable
chmod 755 mpp-installer/usr/local/bin/mpp

# Create a setup script that will be called by postinst
cat > mpp-installer/usr/share/mpp-installer/setup.sh << EOF
#!/bin/bash

# Wait for any apt/dpkg processes to finish
wait_for_apt() {
  echo "Checking for package manager locks..."
  while lsof /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || lsof /var/lib/apt/lists/lock >/dev/null 2>&1 || lsof /var/cache/apt/archives/lock >/dev/null 2>&1; do
    echo "Another package manager process is running. Waiting 5 seconds..."
    sleep 5
  done
  echo "Package manager is available now."
}

# Function to install WireGuard
install_wireguard() {
  if ! command -v wg &> /dev/null; then
    echo "Installing WireGuard packages..."
    wait_for_apt
    apt-get update || true
    apt-get install -y wireguard wireguard-tools || {
      echo "Could not install WireGuard automatically."
      echo "Please install it manually with: sudo apt-get install wireguard wireguard-tools"
      echo "Then run: sudo mpp setup"
      exit 0
    }
  else
    echo "WireGuard is already installed."
  fi
}

# Setup WireGuard
setup_wireguard() {
  echo "Setting up WireGuard..."
  
  # Generate keys if they don't exist
  if [ ! -f /etc/wireguard/keys/privatekey ]; then
    echo "Generating WireGuard keys..."
    mkdir -p /etc/wireguard/keys
    cd /etc/wireguard/keys
    wg genkey | tee privatekey | wg pubkey > publickey
    chmod 600 privatekey publickey
  fi
  
  PRIVATE_KEY=\$(cat /etc/wireguard/keys/privatekey)
  PUBLIC_KEY=\$(cat /etc/wireguard/keys/publickey)
  
  echo "WireGuard keys generated."
  echo "Public key: \$PUBLIC_KEY"
  echo "Please configure this public key in the server conf file."
  
  # Ask for server public key
  read -p "Enter the server's public key: " SERVER_PUBLIC_KEY
  
  echo "Creating WireGuard configuration..."
  # Create wg.conf file with the correct private key
  cat > /etc/wireguard/wg0.conf << EOL
[Interface]
Address = 10.0.0.1/24
SaveConfig = true
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE;
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE;
ListenPort = 51820
PrivateKey = \$PRIVATE_KEY

[Peer]
PublicKey = \$SERVER_PUBLIC_KEY
AllowedIPs = 10.0.0.2/32
EOL
  
  chmod 600 /etc/wireguard/wg0.conf
}

# Setup service
setup_service() {
  echo "Setting up systemd service..."
  systemctl daemon-reload
  systemctl enable mpp.service
  systemctl start mpp.service 2>/dev/null || echo "Note: Service will be started after reboot."
}

# Main installation process
echo "Starting myphantompath service setup..."
install_wireguard
setup_wireguard
setup_service

echo "================================================================"
echo "myphantompath installation complete!"
echo "The myphantompath service has been configured and enabled at boot."
echo ""
echo "To control the connection, use: mpp {start|stop|status|enable|disable|setup}"
echo "================================================================"

exit 0
EOF

chmod 755 mpp-installer/usr/share/mpp-installer/setup.sh

# Create postinst script that launches the setup process properly
cat > mpp-installer/DEBIAN/postinst << EOF
#!/bin/bash
set -e

# Display welcome message
echo "myphantompath Installer v${VERSION} has been installed."
echo "Starting setup process (or you can run it later with 'sudo mpp setup')..."

# Try to run setup script immediately or inform user how to run it later
if lsof /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || lsof /var/lib/apt/lists/lock >/dev/null 2>&1; then
  echo "================================================================"
  echo "IMPORTANT: Another package operation is in progress."
  echo "When it completes, please run: sudo mpp setup"
  echo "================================================================"
else
  # Run setup in the background to avoid blocking dpkg
  /usr/share/mpp-installer/setup.sh &
fi

exit 0
EOF

# Create postrm script (runs after removal)
cat > mpp-installer/DEBIAN/postrm << EOF
#!/bin/bash
set -e

# Stop and disable service if it exists
if [ -f /etc/systemd/system/mpp.service ]; then
  systemctl stop mpp.service || true
  systemctl disable mpp.service || true
  systemctl daemon-reload
fi

echo "MPP VPN service v${VERSION} has been removed."
exit 0
EOF

# Make scripts executable
chmod 755 mpp-installer/DEBIAN/postinst
chmod 755 mpp-installer/DEBIAN/postrm

# Build the package with custom filename
dpkg-deb --build mpp-installer
mv mpp-installer.deb mpp-installer-${VERSION}-${ARCH}.deb
echo "Package built successfully: mpp-installer-${VERSION}-${ARCH}.deb"