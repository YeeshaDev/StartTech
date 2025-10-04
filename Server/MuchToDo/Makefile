run: generate-docs
	go run ./cmd/api/main.go

build:
	go build -o much-to-do ./cmd/api/main.go
	mv much-to-do ./bin/much-to-do

clean:
	rm -f ./bin/much-to-do

tidy:
	go mod tidy

dc-up:
	docker-compose -f docker-compose.yaml up -d --build

dc-down:
	docker-compose -f docker-compose.yaml down

generate-docs:
	swag init -g ./cmd/api/main.go -o ./docs

.PHONY: run build clean tidy