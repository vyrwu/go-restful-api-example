# Go RESTful API Example

This project provides a comprehensive example of a RESTful API built with Go
(Golang), complete with Swagger documentation, multi-arch Docker support,
live-reloading for development, and manifests for deployment on a local Kind
Kubernetes cluster.

## Features

- **RESTful API**: A simple, extendable REST API built with the Gin framework.
- **Swagger Documentation**: Automatically generated and interactive API
  documentation using `swaggo`.
- **Live Reloading**: Integrated with `air` for automatic rebuilding and
  restarting of the application during development.
- **Dockerized**: Comes with a multi-stage, multi-platform `Dockerfile` to
  create a lightweight and efficient container for both `amd64` and `arm64`
  architectures.
- **Kubernetes Ready**: Includes Kubernetes manifests to deploy the application
  in a local `kind` cluster.
- **Makefile Driven**: A comprehensive `Makefile` provides a simple and
  consistent interface for all common development and deployment tasks.

## Requirements

To use this project, you will need the following tools installed on your system:

- **Go**: Version 1.24 or higher.
- **Docker**: To build and run the containerized application.
- **kubectl**: The Kubernetes command-line tool.
- **Kind**: A tool for running local Kubernetes clusters using Docker container
  "nodes".
- **Make**: To use the commands defined in the `Makefile`.
- **Air**: For live-reloading during development. Can be installed by running
  `make deps`.

## Getting Started

1.  **Clone the repository:**

    ```sh
    git clone https://github.com/vyrwu/go-restful-api-example.git
    cd go-restful-api-example
    ```

2.  **Install dependencies:** This command will install the Go modules and the
    `air` live-reloading tool.
    ```sh
    make deps
    ```

## Code Quality and CI/CD

This project is equipped with a suite of tools to ensure code quality and
security. You can run these checks locally using the following `make` commands.

- **`make lint`**: Runs `golangci-lint` to analyze the source code for style
  issues, errors, and complexity.
- **`make test`**: Executes the unit tests and reports code coverage.
- **`make fmt`**: Formats the Go source code according to the standard Go style.
- **`make check-fmt`**: Checks if the code is formatted. This is useful in a CI
  pipeline to enforce formatting.
- **`make scan`**: Uses `govulncheck` to scan the project for known
  vulnerabilities.
- **`make ci`**: A convenience target that runs `lint`, `check-fmt`, `test`, and
  `scan` in sequence.

## Usage

### Local Development with Live Reload

For local development, you can run the application with `air`, which will
automatically rebuild and restart the server whenever you make changes to the
source code.

```sh
make dev
```

The server will be running at `http://localhost:8000`.

### Running on Kubernetes with Kind

This project is configured to run on a local Kind Kubernetes cluster. A single
command sets up the cluster, builds the Docker image, loads it into the cluster,
deploys the application, and sets up port forwarding.

1.  **Run the application on Kind:**

    ```sh
    make run-on-kind
    ```

2.  **Access the application:**
    - The API will be accessible at `http://localhost:8000`.
    - The Swagger documentation will be at
      `http://localhost:8000/swagger/index.html`.

3.  **Clean up the Kind cluster:** When you are finished, you can delete the
    Kind cluster with:
    ```sh
    make kind-cluster-delete
    ```

### API Documentation

The API documentation is generated using Swagger. When the application is
running, you can access the interactive Swagger UI at:

`http://localhost:8000/swagger/index.html`

If you make changes to the API (e.g., add new routes or update models), the
documentation will be automatically regenerated when you run `make dev` or
`make build`.

## Makefile Commands

The `Makefile` provides a convenient way to perform common tasks.

| Command                    | Description                                                                                             |
| -------------------------- | ------------------------------------------------------------------------------------------------------- |
| `make deps`                | Installs all Go dependencies and tools like `air`, `golangci-lint`, and `govulncheck`.                  |
| `make dev`                 | Runs the application in development mode with live-reloading using `air`.                               |
| `make build`               | Compiles the Go application into a binary named `go-restful-api-example`.                               |
| `make clean`               | Removes the compiled binary.                                                                            |
| `make swag`                | Manually initializes or updates the Swagger documentation files in the `docs/` directory.               |
| `make lint`                | Runs the linter to check for code quality issues.                                                       |
| `make fmt`                 | Formats the Go source code.                                                                             |
| `make check-fmt`           | Checks if the code is formatted, and fails if it is not.                                                |
| `make test`                | Runs the unit tests and calculates coverage.                                                            |
| `make scan`                | Scans for known vulnerabilities in dependencies.                                                        |
| `make ci`                  | Runs all CI checks (`lint`, `check-fmt`, `test`, `scan`).                                               |
| `make docker-build`        | Builds a Docker image for your local architecture and loads it into the Docker daemon.                  |
| `make docker-buildx`       | Builds multi-platform Docker images for `linux/amd64` and `linux/arm64`.                                |
| `make kind-cluster-create` | Creates a new Kind cluster named `go-restful-api-example`.                                              |
| `make kind-cluster-delete` | Deletes the Kind cluster.                                                                               |
| `make kind-load-image`     | Loads the locally built Docker image into the Kind cluster.                                             |
| `make k8s-apply`           | Applies the Kubernetes manifests from the `k8s/` directory to the cluster.                              |
| `make k8s-delete`          | Deletes the Kubernetes resources from the cluster.                                                      |
| `make k8s-port-forward`    | Forwards local port 8000 to the application running in the cluster.                                     |
| `make run-on-kind`         | A meta-command that runs `kind-cluster-create`, `kind-load-image`, `k8s-apply`, and `k8s-port-forward`. |
