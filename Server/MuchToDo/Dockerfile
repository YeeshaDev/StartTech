FROM golang:1.25-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/bin/much-to-do ./cmd/api/main.go

FROM gcr.io/distroless/static-debian12

COPY --from=builder /app/bin/much-to-do /app/bin/much-to-do

USER nonroot:nonroot

EXPOSE 8080

CMD ["/app/bin/much-to-do"]
