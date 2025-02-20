#!/bin/bash
# Script to create an MPP Installer Debian package without pre-dependencies

# Create package directory structure
mkdir -p mpp-installer/DEBIAN
mkdir -p mpp-installer/usr/local/bin
mkdir -p mpp-installer/etc/systemd/system
mkdir -p mpp-installer/usr/share/mpp-installer

# Create control file - removed wireguard as a dependency
cat > mpp-installer/DEBIAN/control << EOF
Package: mpp-installer
Version: 1.0
Section: net
Priority: optional
Architecture: all
Depends: bash
Maintainer: Your Name <your.email@example.com>
Description: MPP WireGuard Installer and Configuration
 Installs WireGuard, generates keys, and configures the interface with systemd service.
EOF

# Create systemd service file
cat > mpp-installer/etc/systemd/system/mpp.service << EOF
[Unit]
Description=MPP WireGuard VPN Service
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

case "\$1" in
  start)
    systemctl start mpp
    echo "MPP VPN started"
    ;;
  stop)
    systemctl stop mpp
    echo "MPP VPN stopped"
    ;;
  status)
    systemctl status mpp
    ;;
  enable)
    systemctl enable mpp
    echo "MPP VPN enabled at boot"
    ;;
  disable)
    systemctl disable mpp
    echo "MPP VPN disabled at boot"
    ;;
  *)
    echo "Usage: mpp {start|stop|status|enable|disable}"
    exit 1
    ;;
esac
exit 0
EOF

# Make convenience script executable
chmod 755 mpp-installer/usr/local/bin/mpp

# Create postinst script (runs after installation)
cat > mpp-installer/DEBIAN/postinst << EOF
#!/bin/bash
set -e

# Install Wireguard
echo "Installing WireGuard packages..."
apt-get update
apt-get install -y wireguard wireguard-tools

echo "Generating WireGuard keys..."
# Generate keys and save them
mkdir -p /etc/wireguard/keys
cd /etc/wireguard/keys
wg genkey | tee privatekey | wg pubkey > publickey

PRIVATE_KEY=\$(cat privatekey)
PUBLIC_KEY=\$(cat publickey)

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

echo "Setting up systemd service..."
# Enable and start systemd service
systemctl daemon-reload
systemctl enable mpp.service
systemctl start mpp.service || echo "Note: Service start failed, you may need to reboot first."

echo "================================================================"
echo "MPP installation complete!"
echo "The VPN service has been configured and enabled at boot."
echo ""
echo "To control the VPN connection, use: mpp {start|stop|status|enable|disable}"
echo "================================================================"

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

echo "MPP VPN service has been removed."
exit 0
EOF

# Make scripts executable
chmod 755 mpp-installer/DEBIAN/postinst
chmod 755 mpp-installer/DEBIAN/postrm

# Build the package
dpkg-deb --build mpp-installer
echo "Package built successfully: mpp-installer.deb"
