# MuchToDo API

A robust RESTful API for a ToDo application built with Go (Golang). This project features user authentication, JWT-based session management, CRUD operations for ToDo items, and an optional Redis caching layer.

The API is built with a clean, layered architecture to separate concerns, making it scalable and easy to maintain. It includes a full suite of unit and integration tests and provides interactive API documentation via Swagger.

## Features

* **User Management**: Secure user registration, login, update, and deletion.
* **Authentication**: JWT-based authentication that supports both `httpOnly` cookies (for web clients) and `Authorization` headers.
* **CRUD for ToDos**: Full create, read, update, and delete functionality for user-specific ToDo items.
* **Structured Logging**: Configurable, structured JSON logging with request context for production-ready monitoring.
* **Optional Caching**: Redis-backed caching layer that can be toggled on or off via environment variables.
* **API Documentation**: Auto-generated interactive Swagger documentation.
* **Testing**: Comprehensive unit and integration test suites.
* **Graceful Shutdown**: The server shuts down gracefully, allowing active requests to complete.

## Prerequisites

To run this project locally, you will need the following installed:

* **Go**: Version 1.21 or later.
* **Docker** and **Docker Compose**: To easily run the required MongoDB and Redis services.
* **Swag CLI**: To generate the Swagger API documentation.

```bash
go install github.com/swaggo/swag/cmd/swag@latest
```

## Getting Started

### 1. Clone the Repository

```bash
git clone <your-repository-url>
cd much-todo-api
```

### 2. Configure Environment Variables

Create a `.env` file in the root of the project by copying the example.

```bash
cp .env.example .env
```

Now, open the `.env` file and **change the** `JWT_SECRET_KEY` to a new, long, random string. You can leave the other variables as they are for local development.

### 3. Start Local Dependencies

With Docker running, start the MongoDB and Redis containers using Docker Compose.

```bash
docker-compose up -d
```

This command will pull the required images and start the services in the background.

### 4. Install Go Dependencies

Download the necessary Go modules.

```bash
go mod tidy
```

### 5. Generate API Documentation

Generate the Swagger/OpenAPI documentation from the code comments.

```bash
swag init -g cmd/api/main.go
```

### 6. Run the Application

You can now run the API server.

```bash
go run ./cmd/api/main.go
```

The server will start, and you should see log output in your terminal.

* The API will be available at `http://localhost:8080`.
* The interactive Swagger documentation will be at `http://localhost:8080/swagger/index.html`.

## Running Tests

The project includes both unit and integration tests.

### Run Unit Tests

These tests are fast and do not require any external dependencies.

```bash
go test ./...
```

### Run Integration Tests

These tests require Docker to be running as they spin up their own temporary database and cache containers.

```bash
INTEGRATION=true go test -v --tags=integration ./...
```

The `INTEGRATION=true` environment variable is required to explicitly enable these tests. The `-v` flag provides verbose output.