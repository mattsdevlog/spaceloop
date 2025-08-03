# Complete SSL/WebSocket Setup Guide for Spaceloop

## Current Status
✅ Domain (mattsdevlog.com) pointed to server IP (35.188.127.102)
✅ SSL certificates obtained from Let's Encrypt
✅ Server code updated to use WebSocket instead of ENet
✅ Client code updated to use wss:// for HTML5 builds

## Remaining Steps

### 1. Configure Nginx Reverse Proxy

SSH into your server:
```bash
gcloud compute ssh spaceloop-server --zone=us-central1-a
```

Install nginx if not already installed:
```bash
sudo apt update
sudo apt install -y nginx
```

### 2. Create Nginx Configuration

Create the nginx site configuration:
```bash
sudo nano /etc/nginx/sites-available/spaceloop
```

Copy this configuration (also available in `nginx-spaceloop.conf`):
```nginx
server {
    listen 443 ssl;
    server_name mattsdevlog.com;

    ssl_certificate /etc/letsencrypt/live/mattsdevlog.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/mattsdevlog.com/privkey.pem;

    # WebSocket proxy configuration
    location / {
        proxy_pass http://localhost:8910;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket specific settings
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 60s;
        
        # Buffer settings
        proxy_buffering off;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name mattsdevlog.com;
    return 301 https://$server_name$request_uri;
}
```

### 3. Enable the Site

```bash
sudo ln -s /etc/nginx/sites-available/spaceloop /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
```

### 4. Test and Restart Nginx

Test the configuration:
```bash
sudo nginx -t
```

If successful, restart nginx:
```bash
sudo systemctl restart nginx
sudo systemctl enable nginx
```

### 5. Update Firewall Rules

Exit SSH and update firewall rules to include HTTPS:
```bash
exit
gcloud compute firewall-rules update spaceloop-game \
  --allow udp:8910,tcp:8911,tcp:443,tcp:80
```

### 6. Ensure Server is Running

SSH back in and make sure the game server is running:
```bash
gcloud compute ssh spaceloop-server --zone=us-central1-a
cd ~/spaceloop
./run_server.sh
```

### 7. Test the Connection

1. Open your HTML5 game on itch.io or any HTTPS website
2. The game should now connect using `wss://mattsdevlog.com`
3. Check the browser console for any connection errors

## Troubleshooting

### If nginx fails to start:
```bash
sudo systemctl status nginx
sudo journalctl -xe
```

### If WebSocket connection fails:
1. Check nginx error logs:
   ```bash
   sudo tail -f /var/log/nginx/error.log
   ```

2. Verify certificates are valid:
   ```bash
   sudo certbot certificates
   ```

3. Test WebSocket connection directly:
   ```bash
   curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" https://mattsdevlog.com
   ```

### If server isn't accessible:
1. Check if nginx is listening:
   ```bash
   sudo netstat -tlnp | grep nginx
   ```

2. Check if game server is running:
   ```bash
   ps aux | grep godot
   ```

## Notes

- The game server runs on port 8910 (WebSocket)
- The HTTP status server runs on port 8911
- Nginx proxies HTTPS/WSS (port 443) to the game server (port 8910)
- SSL certificates auto-renew via certbot's systemd timer