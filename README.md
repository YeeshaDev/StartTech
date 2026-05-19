# MuchToDo

A full-stack todo app built with React, Go, MongoDB, and Redis.

## Stack

- **Frontend** — React 19 + Vite + TailwindCSS → S3 + CloudFront
- **Backend** — Go + Gin → EC2 (Docker) behind an ALB
- **Cache** — Redis on ElastiCache
- **DB** — MongoDB Atlas

## Running locally

### Backend

```bash
cd Server/MuchToDo
cp .env.example .env   # fill in your values
docker compose up -d   # starts MongoDB + Redis
go run ./cmd/api/main.go
```

Server runs on `http://localhost:8080`.

### Frontend

```bash
cd Client
cp .env.example .env   # set VITE_API_BASE_URL
npm install
npm run dev
```

UI runs on `http://localhost:5173`.

## Environment variables

### Backend (`Server/MuchToDo/.env`)

| Variable | Description |
|----------|-------------|
| `PORT` | Server port (default `8080`) |
| `MONGO_URI` | MongoDB Atlas connection string |
| `DB_NAME` | Database name |
| `JWT_SECRET_KEY` | JWT signing secret |
| `JWT_EXPIRATION_HOURS` | Token lifetime (default `72`) |
| `ENABLE_CACHE` | Set `true` to use Redis |
| `REDIS_ADDR` | Redis address e.g. `localhost:6379` |
| `REDIS_PASSWORD` | Redis password (leave blank if none) |
| `ALLOWED_ORIGINS` | Comma-separated CORS origins |
| `SECURE_COOKIE` | Set `true` in production |
| `LOG_LEVEL` | `DEBUG` / `INFO` / `WARN` / `ERROR` |
| `LOG_FORMAT` | `json` or `text` |

### Frontend (`Client/.env`)

| Variable | Description |
|----------|-------------|
| `VITE_API_BASE_URL` | Backend API base URL |

## API

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/health` | — | Health check |
| GET | `/ping` | — | Liveness ping |
| GET | `/swagger/*` | — | Swagger UI |
| POST | `/auth/register` | — | Register |
| POST | `/auth/login` | — | Login |
| POST | `/auth/logout` | — | Logout |
| GET | `/auth/username-check/:username` | — | Check username availability |
| GET | `/tasks` | ✓ | List tasks |
| POST | `/tasks` | ✓ | Create task |
| GET | `/tasks/:id` | ✓ | Get task |
| PUT | `/tasks/:id` | ✓ | Update task |
| DELETE | `/tasks/:id` | ✓ | Delete task |
| GET | `/users/me` | ✓ | Get profile |
| PUT | `/users/me` | ✓ | Update profile |
| PUT | `/users/me/password` | ✓ | Change password |
| DELETE | `/users/me` | ✓ | Delete account |

## CI/CD

Push to `main` triggers deployment automatically.

- **Frontend** — builds the React app, syncs to S3, invalidates CloudFront
- **Backend** — runs tests, builds Docker image, pushes to ECR, rolls out via SSM to the ASG

PRs run tests and build only (no deploy).

### GitHub Secrets needed

| Secret | What it is |
|--------|-----------|
| `AWS_ACCESS_KEY_ID` | IAM key |
| `AWS_SECRET_ACCESS_KEY` | IAM secret |
| `AWS_REGION` | e.g. `us-east-1` |
| `S3_BUCKET_NAME` | Frontend S3 bucket |
| `CLOUDFRONT_DISTRIBUTION_ID` | CloudFront distribution ID |
| `VITE_API_BASE_URL` | Backend URL injected at build time |
| `ECR_REPOSITORY` | ECR repo name |
| `ASG_NAME` | Auto Scaling Group name |
| `ALB_DNS_NAME` | ALB DNS name |

## Manual deployment

```bash
# frontend
export S3_BUCKET_NAME=...
export CLOUDFRONT_DISTRIBUTION_ID=...
bash scripts/deploy-frontend.sh

# backend
export ECR_REPOSITORY=muchtodo-backend
export ASG_NAME=muchtodo-production-asg
bash scripts/deploy-backend.sh

# rollback backend
bash scripts/rollback.sh <image-tag>

# health check
bash scripts/health-check.sh http://localhost:8080
```