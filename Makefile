.PHONY: all deps swag build docker-build k8s-apply k8s-delete dev lint fmt check-fmt test scan ci

# Go parameters
GO_CMD=go
GOBUILD=$(GO_CMD) build
GOCLEAN=$(GO_CMD) clean
GOTEST=$(GO_CMD) test
GOGET=$(GO_CMD) get
GOINSTALL=$(GO_CMD) install
BINARY_NAME=bin/go-restful-api-example
SWAG_CMD=swag
AIR_CMD=air
GOLANGCILINT_CMD=golangci-lint
GOFMT_CMD=$(GO_CMD) fmt
GOVULNCHECK_CMD=govulncheck

all: build

deps:
	@echo "Installing dependencies..."
	@$(GOGET) -u github.com/gin-gonic/gin
	@$(GOGET) -u github.com/swaggo/gin-swagger
	@$(GOINSTALL) github.com/swaggo/swag/cmd/swag@latest
	@$(GOINSTALL) github.com/air-verse/air@latest
	@$(GOINSTALL) github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@$(GOINSTALL) golang.org/x/vuln/cmd/govulncheck@latest
	@$(GO_CMD) mod tidy

swag:
	@echo "Initializing Swagger..."
	@$(SWAG_CMD) init

build:
	@echo "Building binary..."
	@$(GOBUILD) -o $(BINARY_NAME) .

clean:
	@echo "Cleaning up..."
	@$(GOCLEAN)
	@rm -rf bin

dev:
	@echo "Starting dev server with air..."
	@$(AIR_CMD)

# CI/CD targets
lint:
	@echo "Running linter..."
	@$(GOLANGCILINT_CMD) run ./...

fmt:
	@echo "Formatting code..."
	@$(GOFMT_CMD) ./...

check-fmt:
	@echo "Checking formatting..."
	@if [ -n "$($(GOFMT_CMD) -l .)" ]; then \
		echo "Go files are not formatted. Please run 'make fmt'."; \
		$(GOFMT_CMD) -d .; \
		exit 1; \
	fi

test:
	@echo "Running tests..."
	@$(GOTEST) -v -cover ./...

scan:
	@echo "Scanning for vulnerabilities..."
	@$(GOVULNCHECK_CMD) ./...

ci:
	@echo "Running CI pipeline..."
	@$(MAKE) lint
	@$(MAKE) check-fmt
	@$(MAKE) test
	@$(MAKE) scan

# Docker parameters
DOCKER_CMD=docker
DOCKER_BUILDX=$(DOCKER_CMD) buildx
DOCKER_TAG=latest
DOCKER_IMAGE_NAME=go-restful-api-example

docker-build:
	@echo "Building Docker image..."
	@$(DOCKER_BUILDX) build -t $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) . --load

docker-buildx:
	@echo "Building multi-platform Docker image..."
	@$(DOCKER_BUILDX) build --platform linux/amd64,linux/arm64 -t $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) .

# Kubernetes parameters
K8S_CMD=kubectl
K8S_APPLY=$(K8S_CMD) apply -f
K8S_DELETE=$(K8S_CMD) delete -f
K8S_YAML_PATH=k8s

# Kind parameters
KIND_CMD=kind
KIND_CLUSTER_NAME=go-restful-api-example
KIND_CREATE_CLUSTER=$(KIND_CMD) create cluster --name $(KIND_CLUSTER_NAME) --config kind-config.yaml
KIND_DELETE_CLUSTER=$(KIND_CMD) delete cluster --name $(KIND_CLUSTER_NAME)
KIND_LOAD_IMAGE=$(KIND_CMD) load docker-image $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) --name $(KIND_CLUSTER_NAME)

build-and-load:
	@echo "Building and loading Docker image with tag $(COMMIT_SHA)..."
	@$(DOCKER_BUILDX) build -t $(DOCKER_IMAGE_NAME):$(COMMIT_SHA) . --load
	@$(KIND_CMD) load docker-image $(DOCKER_IMAGE_NAME):$(COMMIT_SHA) --name $(KIND_CLUSTER_NAME)

kind-cluster-create:
	@echo "Creating Kind cluster..."
	@$(KIND_CREATE_CLUSTER)

kind-cluster-delete:
	@echo "Deleting Kind cluster..."
	@$(KIND_DELETE_CLUSTER)

kind-load-image: docker-build
	@echo "Loading Docker image into Kind cluster..."
	@$(KIND_LOAD_IMAGE)

k8s-apply:
	@echo "Applying Kubernetes manifests..."
	@$(K8S_APPLY) $(K8S_YAML_PATH)/namespace.yaml
	@$(K8S_APPLY) $(K8S_YAML_PATH)

k8s-delete:
	@echo "Deleting Kubernetes resources..."
	@$(K8S_DELETE) $(K8S_YAML_PATH)

k8s-port-forward:
	@echo "Port-forwarding service..."
	@$(K8S_CMD) port-forward service/go-restful-api-example 8000:8000 -n go-restful-api &

run-on-kind: kind-cluster-create kind-load-image k8s-apply
	@echo "Waiting for service to be ready..."
	@sleep 5
	@$(MAKE) k8s-port-forward
