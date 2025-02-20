# MPP Secure Tunnel Installer

This package automates the installation and configuration of WireGuard VPN on your Linux system. The installer creates a convenient command-line utility and systemd service for easy management of your secure connection.

## Part 1: Building the Package

### Prerequisites
- Debian-based Linux distribution (Ubuntu, Debian, etc.)
- `dpkg-deb` package (`sudo apt install dpkg-dev`)
- Basic terminal knowledge

### Build Instructions

1. **Save the build script**
   
   Copy the provided build script to a file named `mpp-package.sh`

2. **Make the script executable**
   ```bash
   chmod +x mpp-package.sh
   ```

3. **Run the build script**
   ```bash
   sudo ./mpp-package.sh
   ```

4. **Verify package creation**
   
   You should see a new file named `mpp-installer-version-arch.deb` in the current directory.

### What the Build Script Creates

The build script generates a Debian package (.deb) that includes:
- Control files specifying package details
- Installation scripts (postinst, postrm)
- Systemd service definition
- Command-line utility script
- Setup configuration helper

## Part 2: Installation and Setup

### Installing the Package

1. **Install the Debian package**
   ```bash
   sudo dpkg -i mpp-installer-version-arch.deb
   ```

   Check for the version and architecture of the build file

2. **Handling installation outcomes**
   
   The installation will follow one of these paths:
   - **Automatic setup**: If no other package operations are running, setup will start automatically
   - **Deferred setup**: If another package operation is in progress, you'll need to manually run setup when it completes

### Manual Setup (if needed)

If setup didn't run automatically during installation:
```bash
sudo mpp setup
```

### Setup Process

During setup (whether automatic or manual), the following will happen:

1. **WireGuard Installation**
   - The system will check if WireGuard is already installed
   - If not, it will attempt to install WireGuard packages
   - If installation fails due to locks, you'll be instructed to install manually

2. **Key Generation**
   - Private and public keys will be generated
   - Keys are stored in `/etc/wireguard/keys/`
   - Your public key will be displayed

3. **Configuration**
   - You'll be prompted to enter the server's public key
   - A configuration file will be created at `/etc/wireguard/wg0.conf`
   - Default settings include:
     * Client IP: 10.0.0.1/24
     * Listen port: 51820
     * NAT/forwarding rules for sharing the connection

4. **Service Setup**
   - The systemd service will be enabled to start at boot
   - The service will attempt to start immediately

### Using the VPN

After installation and setup, you can control your VPN connection with:

```bash
# Start the VPN connection
sudo mpp start

# Stop the VPN connection
sudo mpp stop

# Check connection status
sudo mpp status

# Enable automatic start at boot
sudo mpp enable

# Disable automatic start at boot
sudo mpp-vpn disable

# Re-run the setup process (reconfigure)
sudo mpp setup
```

### Troubleshooting

If you encounter issues during installation:

1. **Lock errors**:
   - Wait for other package operations to complete
   - Run `sudo mpp setup` manually

2. **Missing WireGuard**:
   - Install manually: `sudo apt install wireguard wireguard-tools`
   - Then run setup: `sudo mpp setup`

3. **Service fails to start**:
   - Check configuration: `sudo cat /etc/wireguard/wg0.conf`
   - Verify interface names match your system (default assumes `eth0`)
   - Restart service: `sudo systemctl restart mpp`

### Uninstallation

To completely remove the package:
```bash
sudo apt remove mpp-installer
```

This will stop and disable the VPN service before removing files.
