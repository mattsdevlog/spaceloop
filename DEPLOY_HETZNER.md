# Deploy to Hetzner Cloud (€20 free credit)

## Cheapest Option - Only €3.29/month after credit

### 1. Sign Up
- Go to [hetzner.com/cloud](https://hetzner.com/cloud)
- Use referral for €20 credit: https://hetzner.cloud/?ref=Uu5P2Y3tUbYz
- No credit card needed initially!

### 2. Create Server
- Location: Choose closest to you
- Image: Ubuntu 22.04
- Type: CX11 (1 vCPU, 2GB RAM) - €3.29/month
- Create & Go

### 3. Access Your Server
```bash
ssh root@YOUR_SERVER_IP
```

### 4. Quick Install Script
Create this script on the server:
```bash
cat > install.sh << 'EOF'
#!/bin/bash
# Update system
apt update && apt upgrade -y

# Install Godot
cd /opt
wget https://downloads.tuxfamily.org/godotengine/4.3/Godot_v4.3-stable_linux.x86_64.zip
unzip Godot_v4.3-stable_linux.x86_64.zip
mv Godot_v4.3-stable_linux.x86_64 godot
rm *.zip

# Create game directory
mkdir -p /opt/spaceloop
cd /opt/spaceloop

# Create systemd service
cat > /etc/systemd/system/spaceloop.service << 'SERVICE'
[Unit]
Description=Spaceloop Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/spaceloop
ExecStart=/opt/godot --headless run_server.gd
Restart=always
User=root

[Install]
WantedBy=multi-user.target
SERVICE

# Open firewall
ufw allow 22/tcp
ufw allow 8910/tcp
ufw allow 8911/tcp
ufw --force enable

echo "Setup complete! Upload your game files to /opt/spaceloop/"
EOF

chmod +x install.sh
./install.sh
```

### 5. Upload Your Game
From your computer:
```bash
scp -r * root@YOUR_SERVER_IP:/opt/spaceloop/
```

### 6. Start Server
```bash
systemctl start spaceloop
systemctl enable spaceloop
systemctl status spaceloop
```