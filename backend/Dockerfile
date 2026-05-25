FROM golang:1.22-alpine AS base
WORKDIR /app
RUN apk add --no-cache git

# Development stage — with Air for hot reload
FROM base AS development
RUN go install github.com/air-verse/air@v1.52.3
COPY go.mod go.sum ./
RUN go mod download
COPY . .
EXPOSE 8080
CMD ["air", "-c", ".air.toml"]

# Build stage
FROM base AS builder
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/hapa-api ./cmd/api

# Production stage
FROM gcr.io/distroless/static-debian12 AS production
COPY --from=builder /app/hapa-api /hapa-api
EXPOSE 8080
ENTRYPOINT ["/hapa-api"]
