# Deploy to Google Cloud Platform (Easy!)

## Quick Setup (5 minutes)

### 1. Create GCP Account
- Go to [console.cloud.google.com](https://console.cloud.google.com)
- Get $300 free credit (lasts 90 days)

### 2. Open Cloud Shell
Click the terminal icon (>_) in the top right of the console

### 3. Create VM Instance
Run this in Cloud Shell:
```bash
gcloud compute instances create spaceloop-server \
  --zone=us-central1-a \
  --machine-type=e2-micro \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=30GB \
  --tags=game-server

# Create firewall rules
gcloud compute firewall-rules create spaceloop-game \
  --allow tcp:8910,tcp:8911 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=game-server
```

### 4. Connect to Your Server
```bash
gcloud compute ssh spaceloop-server --zone=us-central1-a
```

### 5. Install Everything (Copy & Paste)
```bash
# Install Godot
sudo apt update
sudo apt install -y wget unzip
wget https://downloads.tuxfamily.org/godotengine/4.3/Godot_v4.3-stable_linux.x86_64.zip
unzip Godot_v4.3-stable_linux.x86_64.zip
sudo mv Godot_v4.3-stable_linux.x86_64 /usr/local/bin/godot
rm Godot_v4.3-stable_linux.x86_64.zip

# Clone your game
sudo apt install -y git
git clone https://github.com/YOUR_USERNAME/spaceloop.git
cd spaceloop
```

### 6. Run the Server
```bash
# Start in background
nohup godot --headless run_server.gd > game.log 2>&1 &
nohup godot --headless run_http_server.gd > http.log 2>&1 &

# Check logs
tail -f game.log
```

### 7. Get Your Server IP
```bash
curl ifconfig.me
```

That's it! Update your game with this IP.