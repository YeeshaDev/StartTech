# Build 
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Install git (required by some Go modules)
RUN apk add --no-cache git

# Download dependencies first (cached unless go.mod changes)
COPY go.mod ./
RUN go mod download

# Copy source and build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -mod=mod -a -installsuffix cgo -o main .

# Run 
FROM alpine:3.19

# ca-certificates for TLS; wget for the health-check probe
RUN apk --no-cache add ca-certificates wget

# Non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

COPY --from=builder /app/main .

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

CMD ["./main"]
