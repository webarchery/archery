
---

# Archery Deployment Guide — AWS EC2 (Ubuntu 22.04)

This guide walks you through deploying an Archery application on an AWS EC2 instance using:

* Ubuntu 22.04 LTS
* Nginx reverse proxy
* Dart SDK (AOT compiled binary)
* Namecheap for DNS
* Let’s Encrypt SSL (Certbot)
* Systemd for process management

The final result is a **fully secured production server** running Archery at your custom domain.

---

## 1. Launch the EC2 Instance

1. Go to **AWS EC2 → Launch Instance**
2. Choose:

    * **AMI:** Ubuntu Server 22.04 LTS
    * **Instance type:** t3.micro or t3.small
    * **Storage:** 20–40GB gp3
3. Download your `.pem` key
4. Configure security group inbound rules:

    * `22/tcp` — your IP only
    * `80/tcp` — anywhere (web traffic)
    * `443/tcp` — anywhere (HTTPS)

---

## 2. SSH Into the Server

```bash
chmod 400 mykey.pem
ssh -i mykey.pem ubuntu@YOUR_EC2_PUBLIC_IP
```

---

## 3. Install System Dependencies

```bash
sudo apt update && sudo apt upgrade -y

sudo apt install -y \
  git curl unzip build-essential \
  nginx software-properties-common \
  python3-certbot-nginx apt-transport-https
```

---

## 4. Install Dart SDK

```bash
sudo sh -c 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -'
sudo sh -c 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'

sudo apt update
sudo apt install -y dart
```

Verify:

```bash
dart --version
```

---

## 5. Clone the Archery App

```bash
sudo mkdir -p /var/www/archery
sudo chown -R ubuntu:ubuntu /var/www/archery

cd /var/www/archery
git clone -b main https://github.com/YOUR_REPO_HERE.git .
dart pub get
```

---

## 6. Compile Archery to a Native Binary (AOT)

This makes your server much faster and more stable:

```bash
dart compile exe bin/server.dart -o bootstrap
chmod +x bootstrap
```

---

## 7. Create a Systemd Service

This ensures Archery runs on boot and restarts automatically.

Create the service:

```bash
sudo nano /etc/systemd/system/archery.service
```

Paste:

```ini
[Unit]
Description=Archery Dart Server
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/var/www/archery
ExecStart=/var/www/archery/bootstrap
Restart=always
RestartSec=3
Environment=PORT=5501

[Install]
WantedBy=multi-user.target
```

Enable & start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable archery
sudo systemctl start archery
sudo systemctl status archery
```

---

## 8. Configure Nginx Reverse Proxy

Create a site config:

```bash
sudo nano /etc/nginx/sites-available/archery.conf
```

Paste:

```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;

    location / {
        proxy_pass         http://127.0.0.1:5501;
        proxy_http_version 1.1;

        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

Enable the site:

```bash
sudo ln -s /etc/nginx/sites-available/archery.conf /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default 2>/dev/null
sudo nginx -t
sudo systemctl reload nginx
```

---

## 9. Connecting a Domain

Create two **A records**:

| Host | Value              |
| ---- | ------------------ |
| @    | YOUR_EC2_PUBLIC_IP |
| www  | YOUR_EC2_PUBLIC_IP |

Wait 5–20 minutes for propagation.

---

## 10. Install SSL (Let’s Encrypt)

After DNS resolves:

```bash
sudo certbot --nginx \
  -d yourdomain.com \
  -d www.yourdomain.com
```

Choose **redirect HTTP→HTTPS** when asked.

Test renewal:

```bash
sudo certbot renew --dry-run
```

---

## 11. Deploying Updates (Git Pull)

SSH into the server:

```bash
cd /var/www/archery
git pull origin main
dart pub get
dart compile exe bin/server.dart -o bootstrap
sudo systemctl restart archery
```

---

## 12. Optional: Automatic Deploy Script

Create `deploy.sh`:

```bash
cd /var/www/archery
git pull origin main
dart pub get
dart compile exe bin/server.dart -o bootstrap
sudo systemctl restart archery
```

Run:

```bash
bash deploy.sh
```

---

## 13. Folder Permissions

If Archery writes to JSON files (e.g., `users.json`, `auth_sessions.json`), ensure the service user owns them:

```bash
sudo chown -R ubuntu:ubuntu /var/www/archery
chmod -R 775 /var/www/archery/lib/src/storage/json_file_models
```

---

## Deployment Complete

You now have:

* Archery running behind Nginx
* HTTPS via Let’s Encrypt
* Systemd-managed process
* Full EC2 production environment
