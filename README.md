# MuchTodo — Containerization Assessment

A Golang REST API backed by MongoDB, fully containerized with Docker and deployable to Kubernetes via Kind.

---

## Project Structure

```
much-to-do/
├── main.go                      # Go application (CRUD API + /health)
├── go.mod                       # Go module file
├── Dockerfile                   # Multi-stage Docker build
├── docker-compose.yml           # Local development setup
├── .dockerignore                # Files excluded from Docker build
├── kubernetes/
│   ├── namespace.yaml
│   ├── mongodb/
│   │   ├── mongodb-secret.yaml
│   │   ├── mongodb-configmap.yaml
│   │   ├── mongodb-pvc.yaml
│   │   ├── mongodb-deployment.yaml
│   │   └── mongodb-service.yaml
│   ├── backend/
│   │   ├── backend-secret.yaml
│   │   ├── backend-configmap.yaml
│   │   ├── backend-deployment.yaml
│   │   └── backend-service.yaml
│   └── ingress.yaml
├── scripts/
│   ├── docker-build.sh
│   ├── docker-run.sh
│   ├── k8s-deploy.sh
│   └── k8s-cleanup.sh
└── evidence/                    # Screenshots for submission
```

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Docker | 24+ | https://docs.docker.com/get-docker/ |
| Docker Compose | v2 | Included with Docker Desktop |
| Kind | 0.20+ | `brew install kind` |
| kubectl | 1.28+ | `brew install kubectl` |

---

## Phase 1 — Docker Setup

### Step 1: Build the image

```bash
bash scripts/docker-build.sh
# OR manually:
docker build -t muchtodo-backend:latest .
```

### Step 2: Run with Docker Compose

```bash
bash scripts/docker-run.sh
# OR manually:
docker compose up --build -d
```

### Step 3: Test the application

```bash
# Health check
curl http://localhost:8080/health

# Create a user
curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice","email":"alice@example.com"}'

# List all users
curl http://localhost:8080/users

# Get a specific user (replace <id> with the id returned above)
curl http://localhost:8080/users/<id>

# Update a user
curl -X PUT http://localhost:8080/users/<id> \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice Updated","email":"alice2@example.com"}'

# Delete a user
curl -X DELETE http://localhost:8080/users/<id>
```

### Step 4: View logs & stop

```bash
docker compose logs -f          # Follow logs
docker compose down             # Stop containers
docker compose down -v          # Stop + delete data volume
```

---

## Phase 2 — Kubernetes Deployment

### Step 1: Deploy everything (one command)

```bash
bash scripts/k8s-deploy.sh
```

This script will:
1. Create a Kind cluster named `muchtodo-cluster`
2. Build the Docker image and load it into Kind
3. Apply all Kubernetes manifests in the correct order
4. Wait for deployments to be healthy
5. Print a summary of running resources

### Step 2: Access the application

```bash
# Forward port 8080 on your machine to the backend service
kubectl port-forward svc/backend-service 8080:80 -n muchtodo

# Then in another terminal:
curl http://localhost:8080/health
curl http://localhost:8080/users
```

### Step 3: Useful kubectl commands (for evidence screenshots)

```bash
# Check all pods
kubectl get pods -n muchtodo

# Check all services
kubectl get services -n muchtodo

# Check ingress
kubectl get ingress -n muchtodo

# Describe a pod (for debugging)
kubectl describe pod -l app=backend -n muchtodo

# View backend logs
kubectl logs -l app=backend -n muchtodo

# View mongodb logs
kubectl logs -l app=mongodb -n muchtodo

# Check all resources at once
kubectl get all -n muchtodo
```

### Step 4: Cleanup

```bash
bash scripts/k8s-cleanup.sh
```

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check (also checks DB) |
| GET | `/users` | List all users |
| POST | `/users` | Create a new user |
| GET | `/users/{id}` | Get a user by ID |
| PUT | `/users/{id}` | Update a user |
| DELETE | `/users/{id}` | Delete a user |

### Example User JSON

```json
{
  "name": "John Doe",
  "email": "john@example.com"
}
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MONGODB_URI` | `mongodb://localhost:27017` | MongoDB connection string |
| `DB_NAME` | `muchtodo` | Database name |
| `PORT` | `8080` | Port the API listens on |

---

## Architecture

```
                    ┌─────────────────────────────────┐
                    │         Kubernetes Cluster        │
                    │                                   │
  Browser/curl ───► │  Ingress (nginx)                  │
                    │       │                           │
                    │  backend-service (NodePort:30080)  │
                    │       │                           │
                    │  backend Pod 1 ──┐                │
                    │  backend Pod 2 ──┼─► mongodb-service ─► MongoDB Pod
                    │                 │                 │
                    └─────────────────┴─────────────────┘
```

---

## Evidence

Screenshots for submission are stored in the `evidence/` folder:

1. `docker-build.png` — Docker image build completing
2. `docker-compose-1.png & docker-compose-2.png` — `docker compose up` running
3. `docker-health-check.png` — `/health` endpoint responding
4. `cluster-creation.png` — Kind cluster creation
5. `deployment.png` — Kubernetes deployments running
6. `kubectl-cmd` — Kubectl commands showing `kubectl get pods -n muchtodo`, `kubectl get services -n muchtodo`, `kubectl get ingress -n muchtodo`
7. `port-service.png` — Application accessible through a NodePort Service type to the host or Kubernetes ingress.
