# Deploying to AWS EC2

This guide walks you through deploying the Suspicious Activity Detection app
to an AWS EC2 instance using Docker Compose. The stack is:

- **Postgres 16** (in a container, data persisted to a volume)
- **API server** (Express, Node 24)
- **Web** (Vite SPA served by nginx, which also reverse-proxies `/api` to the API container)

---

## 1. Launch an EC2 instance

1. Sign in to the AWS Console → EC2 → **Launch instance**.
2. Choose:
   - **AMI**: Ubuntu Server 24.04 LTS
   - **Instance type**: `t3.small` recommended (`t2.micro` works for testing — free tier)
   - **Key pair**: create one and download the `.pem` file
   - **Storage**: at least 20 GB
3. **Security group** — allow inbound:
   - SSH (port 22) from **My IP**
   - HTTP (port 80) from **Anywhere**
   - HTTPS (port 443) from **Anywhere** (for later, when adding TLS)
4. Launch and note the **Public IPv4 address**.

## 2. SSH into the instance

```bash
chmod 400 your-key.pem
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>
```

## 3. Install Docker and Git

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git ca-certificates curl gnupg

# Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
newgrp docker
```

## 4. Clone the repo

```bash
git clone https://github.com/RITHVIKREDDY02/Suspicious-Activity-Detection.git
cd Suspicious-Activity-Detection
```

## 5. Configure environment variables

```bash
cp .env.example .env
nano .env
```

Set strong values for `POSTGRES_PASSWORD` and `SESSION_SECRET`. Generate the
session secret with:

```bash
openssl rand -hex 32
```

Update `DATABASE_URL` in the `.env` file to use the same password.

## 6. Build and start the stack

```bash
docker compose up -d --build
```

First build takes ~5–10 minutes. Check status with:

```bash
docker compose ps
docker compose logs -f api
```

## 7. Push the database schema

The first time you run the stack, the database is empty. Push the Drizzle
schema (creates `users`, `detections`, `monitors` tables):

```bash
# Install Node 24 + pnpm on the host (one-time, only needed for migrations)
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo bash -
sudo apt install -y nodejs
sudo npm install -g pnpm

# Install workspace deps and push schema
pnpm install --frozen-lockfile
pnpm --filter @workspace/db run push
```

You should see Drizzle report the tables it created.

## 8. Verify the database tables

Connect to the running Postgres container and inspect the schema:

```bash
docker compose exec db psql -U sar -d sardb
```

Inside `psql`:

```sql
-- list all tables
\dt

-- expected output:
--             List of relations
--  Schema |    Name    | Type  | Owner
-- --------+------------+-------+-------
--  public | users      | table | sar
--  public | detections | table | sar
--  public | monitors   | table | sar

-- inspect a specific table
\d users
\d detections
\d monitors

-- count rows
SELECT COUNT(*) FROM users;
SELECT COUNT(*) FROM detections;

-- exit
\q
```

## 9. Visit the site

Open `http://<EC2_PUBLIC_IP>` in your browser. You should see the SAR landing page.

## 10. (Optional) Add HTTPS with a domain

If you have a domain pointed at the EC2 IP, install Certbot and get a free Let's Encrypt cert:

```bash
sudo apt install -y certbot
sudo certbot certonly --standalone -d yourdomain.com
```

Then mount the certs into the nginx container and add a `listen 443 ssl;`
block to `nginx/default.conf`. Restart with `docker compose up -d`.

---

## Useful commands

```bash
# Stop the stack
docker compose down

# Stop and wipe the database volume (DANGEROUS — deletes all data)
docker compose down -v

# Pull latest code and rebuild
git pull
docker compose up -d --build

# Tail logs from any service
docker compose logs -f api
docker compose logs -f web
docker compose logs -f db

# Open a shell in a container
docker compose exec api sh
docker compose exec db sh
```

## Troubleshooting

- **API returns 502 / connection refused** → check `docker compose logs api`. Most common cause: `DATABASE_URL` mismatch with Postgres credentials.
- **Frontend loads but API calls 404** → confirm nginx is proxying `/api` (see `nginx/default.conf`).
- **Out of memory during build** → use a `t3.small` or larger, or build images locally and push to ECR/Docker Hub instead of building on the instance.
- **Port 80 blocked** → check the EC2 security group inbound rules.
