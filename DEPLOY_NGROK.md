# Use Ngrok (Easiest - Run from your computer!)

## No cloud setup needed - Use your own computer as the server

### 1. Install Ngrok
```bash
# On Mac
brew install ngrok/ngrok/ngrok

# Or download from ngrok.com
```

### 2. Sign up for free account
- Go to [ngrok.com](https://ngrok.com)
- Sign up for free account
- Get your auth token

### 3. Setup Ngrok
```bash
ngrok config add-authtoken YOUR_AUTH_TOKEN
```

### 4. Run Your Game Server Locally
```bash
cd /Users/matt/spaceloop
godot --headless run_server.gd
```

### 5. Expose with Ngrok
In a new terminal:
```bash
# Expose game server
ngrok tcp 8910
```

You'll see something like:
```
Forwarding tcp://2.tcp.ngrok.io:12345 -> localhost:8910
```

### 6. Update Your Game
Use the ngrok URL in your game:
- Host: `2.tcp.ngrok.io`
- Port: `12345` (the number ngrok gives you)

### Pros:
- Completely free
- No cloud setup
- Works immediately
- Good for testing

### Cons:
- URL changes each time
- Needs your computer running
- Some latency

### Pro Tip: Stable URL (Paid)
With ngrok paid plan ($8/month), you get stable URLs:
```bash
ngrok tcp 8910 --domain=spaceloop.ngrok.io
```