# Deploying Spaceloop to Oracle Cloud Free Tier

## Step 1: Create Oracle Cloud Account
1. Go to [cloud.oracle.com](https://cloud.oracle.com)
2. Sign up for free account (credit card required but won't be charged)
3. Choose your home region (pick closest to your players)

## Step 2: Create Your Free ARM Instance
1. From Oracle Cloud Console, go to **Compute → Instances**
2. Click **Create Instance**
3. Configure:
   - **Name**: spaceloop-server
   - **Image**: Ubuntu 22.04
   - **Shape**: Click "Change shape" → Ampere → VM.Standard.A1.Flex
   - **OCPUs**: 4 (max for free tier)
   - **Memory**: 24 GB (max for free tier)
   - **Boot volume**: 200 GB (max for free tier)
4. Add your SSH key (generate one if needed)
5. Click **Create**

## Step 3: Configure Networking
1. Go to **Networking → Virtual Cloud Networks**
2. Click on your VCN → Security Lists → Default Security List
3. Add Ingress Rules:
   - **Port 8910** (TCP) - Game Server
   - **Port 8911** (TCP) - HTTP Status Server
   - **Port 22** (TCP) - SSH (already added)

## Step 4: Connect to Your Server
```bash
ssh ubuntu@YOUR_SERVER_IP
```

## Step 5: Install Godot on the Server
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y wget unzip

# Download Godot for ARM64
cd ~
wget https://downloads.tuxfamily.org/godotengine/4.3/Godot_v4.3-stable_linux.arm64.zip
unzip Godot_v4.3-stable_linux.arm64.zip
sudo mv Godot_v4.3-stable_linux.arm64 /usr/local/bin/godot
rm Godot_v4.3-stable_linux.arm64.zip

# Verify installation
godot --version
```

## Step 6: Upload Your Game Files
From your local machine:
```bash
# Create a deployment package (exclude unnecessary files)
cd /Users/matt/spaceloop
rsync -avz --exclude='.godot' --exclude='.git' --exclude='*.tmp' . ubuntu@YOUR_SERVER_IP:~/spaceloop/
```

## Step 7: Create Systemd Services

### Game Server Service
```bash
sudo nano /etc/systemd/system/spaceloop-game.service
```

Paste this content:
```ini
[Unit]
Description=Spaceloop Game Server
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/spaceloop
ExecStart=/usr/local/bin/godot --headless run_server.gd
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### HTTP Status Server Service
```bash
sudo nano /etc/systemd/system/spaceloop-http.service
```

Paste this content:
```ini
[Unit]
Description=Spaceloop HTTP Status Server
After=network.target spaceloop-game.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/spaceloop
ExecStart=/usr/local/bin/godot --headless run_http_server.gd
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

## Step 8: Start the Services
```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable services to start on boot
sudo systemctl enable spaceloop-game
sudo systemctl enable spaceloop-http

# Start services
sudo systemctl start spaceloop-game
sudo systemctl start spaceloop-http

# Check status
sudo systemctl status spaceloop-game
sudo systemctl status spaceloop-http

# View logs
sudo journalctl -u spaceloop-game -f
sudo journalctl -u spaceloop-http -f
```

## Step 9: Configure Firewall
```bash
# Oracle uses iptables, add rules
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 8910 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 8911 -j ACCEPT

# Save iptables rules
sudo netfilter-persistent save
```

## Step 10: Update Your Game Client
Replace `127.0.0.1` with your Oracle server's public IP in:
- `multiplayer_client.gd`
- `game.gd` (for the HTTP status requests)

Example:
```gdscript
var error = peer.create_client("YOUR_ORACLE_IP", 8910)
```

## Monitoring Commands
```bash
# View game server logs
sudo journalctl -u spaceloop-game -f

# View HTTP server logs  
sudo journalctl -u spaceloop-http -f

# Restart services if needed
sudo systemctl restart spaceloop-game
sudo systemctl restart spaceloop-http

# Check resource usage
htop
```

## Oracle Free Tier Benefits
- **Forever free** (not just 12 months)
- 4 ARM CPUs + 24GB RAM
- 200GB storage
- 10TB bandwidth/month
- No sleep/shutdown like other free tiers
- Can run 24/7

## Troubleshooting
- If can't connect, check Security List rules in Oracle Console
- Ensure both iptables and Oracle Security Lists allow your ports
- Use `sudo tcpdump -i any port 8910` to debug connections