# University Guest Lecture: From Localhost to GitOps

This exercise will guide you through deploying a Go application using various
methods, starting from a traditional local setup and progressively moving
towards a fully automated GitOps workflow.

_This exercise is only supported on MacOS._

## Setup

1.  **Fork the Repository:** Start by forking this repository to your own GitHub account.
2.  **Clone Your Fork:** Clone your forked repository to your local machine.
    ```bash
    git clone https://github.com/<YOUR_GITHUB_USERNAME>/go-restful-api-example.git
    cd go-restful-api-example
    ```

## Requirements

Before you begin, please ensure you have the following tools installed on your local machine:

- **make**: A build automation tool.
- **Docker**: For building and running containers.
- **Colima**: A container runtime with support for Kubernetes.
- **kind**: A tool for running local Kubernetes clusters using Docker.
- **kubectl**: The Kubernetes command-line tool.
- **air**: For live-reloading of the Go application during development.
- **ngrok**: To expose a local server to the internet.

## Part 1: The "Golden Path" - Local Development & Manual Deployment

In this part, we'll explore the local development experience set up for this
project and deploy our application to a local Kubernetes cluster manually. This
demonstrates a common, imperative approach to deployment.

### Running the Application Locally

The `Makefile` in this repository provides several commands to streamline
development. To run the application on your local machine, you can use the `dev`
target. This command uses `air` for hot-reloading, which means the application
will automatically restart whenever you save a file.

1.  **Install dependencies:**

    ```bash
    make deps
    ```

2.  **Run the development server:**
    ```bash
    make dev
    ```
    You should now be able to access the application at `http://localhost:8000`.

### Manual Deployment to a Kind Cluster

_This section requires [Colima](https://github.com/abiosoft/colima) to be
installed and running._

Next, we'll deploy the application to a local Kubernetes cluster using `kind`.
The `Makefile` automates this process.

1.  **Create a Kind cluster, build and load the image, and apply manifests:**

    ```bash
    make run-on-kind
    ```

    This command does the following:
    - Creates a `kind` cluster named `go-restful-api-example`.
    - Builds the Docker image for our application.
    - Loads the image into the `kind` cluster.
    - Applies the Kubernetes manifests from the `k8s/` directory.
    - Forwards the service port to your local machine.

2.  **Access the application:** You can now access the application running in
    Kubernetes at `http://localhost:8000`.

**Key Takeaway:** This is a traditional deployment method. If you make a change
to the application code, you would need to manually run `make run-on-kind` again
to build the new image and redeploy it. This process is manual, error-prone, and
requires direct access to the cluster.

### Understanding Imperative Deployments: Configuration Drift

Let's explore a key drawback of the traditional, push-based deployment model.

1.  **Simulate a Manual Change:** Let's see what happens when we manually change
    the state of the cluster. Delete the deployment we just created:

    ```bash
    kubectl delete deployment go-restful-api-example -n go-restful-api
    ```

2.  **Observe the Result:** If you try to access the application at
    `http://localhost:8000`, it will no longer be available. The deployment is
    gone, and it will not come back on its own.

**Key Takeaway:** This demonstrates a core characteristic of traditional,
pipeline-driven deployment models. The change we made directly to the cluster is
permanent. To get the application running again, you would need to run
`make run-on-kind` or `kubectl apply` again to push a new deployment. This
illustrates how **infrastructure drift** can occur: over time, manual changes
and side-effects from other operations can cause the cluster's actual state to
diverge from the intended configuration stored in your manifests.

---

## Part 2: Introducing GitOps with ArgoCD

Now, let's introduce GitOps. We'll use ArgoCD to automatically sync our
Kubernetes manifests from this Git repository to our local cluster. This removes
the need for manual `kubectl apply` commands.

1.  **Install ArgoCD:** Run the following commands to install ArgoCD on your
    `kind` cluster.

    ```bash
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    ```

    For more detailed instructions or if you encounter any issues, refer to the
    [ArgoCD Getting Started guide](https://argo-cd.readthedocs.io/en/stable/getting_started/).

2.  **Access the ArgoCD UI:** To access the ArgoCD UI, you'll need to wait for
    the server to be ready, forward the port, and retrieve the initial admin
    password.

    The following commands will wait for the ArgoCD server to start, run the
    port-forward in the background, and then print the login instructions with
    your temporary password.

    ```bash
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
    kubectl port-forward svc/argocd-server -n argocd 8080:443 &
    ARGO_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo "You can now log in to the ArgoCD UI at https://localhost:8080"
    echo "Username: admin"
    echo "Password: $ARGO_PASSWORD"
    ```

    Log in with the username `admin` and the password printed by the command
    above.

3.  **Create the ArgoCD Application:** Instead of creating the application
    manually in the UI, we'll define it declaratively as a Kubernetes manifest.
    This is a core principle of GitOps: the entire state of your system is
    defined in a Git repository.

    Now, save the following manifest as `.argo/application.yaml`. It contains
    the declarative definition of our application, with comments explaining the
    purpose of each section.

    ```yaml
    # .argo/application.yaml

    # The ArgoCD Application resource that defines our GitOps-managed application.
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: go-restful-api-example
      namespace: argocd
    spec:
      # The project this application belongs to. 'default' is a built-in project.
      project: default

      # The source of the application's manifests.
      source:
        # The URL of the Git repository containing the Kubernetes manifests.
        repoURL: https://github.com/<YOUR_GITHUB_USERNAME>/go-restful-api-example.git # TODO: Replace with your fork's URL
        # The branch or commit to track. HEAD follows the default branch.
        targetRevision: HEAD
        # The directory within the repository where the manifests are located.
        path: k8s

      # The destination where the application will be deployed.
      destination:
        # The target Kubernetes cluster. 'https://kubernetes.default.svc' refers to the same cluster where ArgoCD is running.
        server: https://kubernetes.default.svc
        # The namespace to deploy the resources into.
        namespace: go-restful-api

      # The synchronization policy.
      syncPolicy:
        # Enable automated synchronization.
        automated:
          # Prune resources that are no longer defined in the Git repository.
          prune: true
          # Enable self-healing to automatically correct any manual changes (drift) in the cluster.
          selfHeal: true
    ```

    Apply the manifest to your cluster. Make sure you update the `repoURL`
    inside the file to point to your fork of this repository.

    ```bash
    kubectl apply -f .argo/application.yaml
    ```

    ArgoCD will now detect this `Application` resource and automatically start
    syncing the manifests from your repository's `k8s` directory. You can see
    the application and its status in the ArgoCD UI.

**Key Takeaway:** Now, whenever you push a change to the `k8s` directory in your
repository, ArgoCD will automatically detect the change and apply it to the
cluster. The Git repository has become the single source of truth for our
application's desired state.

---

### Exploring GitOps in Action: Self-Healing

Now that ArgoCD is managing our application, let's see one of the core benefits
of GitOps in action: self-healing.

1.  **Find the Application in ArgoCD:** Open the ArgoCD UI at
    `https://localhost:8080`. You should see a single application card for
    `go-restful-api-example`. Click on it.

2.  **Inspect the Resources:** You'll see a tree view of all the Kubernetes
    resources that ArgoCD is tracking for this application, as defined in the
    `k8s/` directory of your repository. The application should be in a
    `Healthy` and `Synced` state.

3.  **Simulate a Manual Change:** Let's simulate an accidental or unauthorized
    change to our cluster. We'll delete the `Deployment` resource directly. You
    can do this either by clicking on the `Deployment` in the ArgoCD UI and
    deleting it, or by running the following command:

    ```bash
    kubectl delete deployment go-restful-api-example -n go-restful-api
    ```

4.  **Observe the Result:** Watch the ArgoCD UI. Within a few moments, you will
    see the `Deployment` resource reappear. ArgoCD has detected that the live
    state of the cluster has drifted from the desired state defined in your Git
    repository and has automatically corrected it.

**Key Takeaway:** This demonstrates the power of GitOps. Because the Git
repository is the single source of truth, ArgoCD will always work to ensure the
cluster's state matches what's in Git. This prevents manual, out-of-band changes
and provides a powerful self-healing capability, making your deployments more
robust and predictable.

---

## Part 3: Full CI/CD with Argo Workflows

In this final part, we'll create a complete CI/CD pipeline using Argo Workflows.
This pipeline will automatically build, test, and deploy our application
whenever we push a code change.

1.  **Install Argo Workflows:** Run the following commands to install Argo
    Workflows on your `kind` cluster.

    ```bash
    kubectl create namespace argo
    kubectl apply -n argo -f https://raw.githubusercontent.com/argoproj/argo-workflows/stable/manifests/install.yaml
    ```

    For more detailed instructions or if you encounter any issues, refer to the
    [Argo Workflows Getting Started guide](https://argoproj.github.io/argo-workflows/quick-start/).

    To access the Argo Workflows UI, you'll need to forward the port. We'll run
    this in the background so we can continue to use the terminal.

    ```bash
    kubectl wait --for=condition=ready pod -l app=argo-server -n argo --timeout=300s
    kubectl -n argo port-forward deployment/argo-server 2746:2746 &
    ```

    You can now access the UI at `https://localhost:2746`.

2.  **Configure Argo Events:** We need to configure Argo Events to trigger a
    pipeline on a `git push` event. This involves setting up several resources
    that work together: an `EventBus` for message transport, an `EventSource` to
    receive the webhook from GitHub, a `Sensor` to trigger our `Workflow`, and
    the necessary RBAC permissions.

    First, install the Argo Events components:

    ```bash
    kubectl create namespace argo-events
    kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
    kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install-validating-webhook.yaml
    ```

    Next, create a secret for your GitHub webhook. This can be any random
    string.

    ```bash
    kubectl -n argo-events create secret generic github-webhook-secret --from-literal=secret="your-super-secret-string"
    ```

    Now, save the following manifest as `.argo/webhook.yaml`. It contains all
    the necessary resources, with comments explaining the purpose of each.

    ```yaml
    # .argo/webhook.yaml

    # 1. EventBus: The transport layer for events in Argo Events.
    # This 'default' EventBus uses NATS Streaming to pass events from EventSources to Sensors.
    apiVersion: argoproj.io/v1alpha1
    kind: EventBus
    metadata:
      name: default
      namespace: argo-events
    spec:
      nats:
        native:
          replicas: 3
    ---
    # 2. EventSource: Listens for external events.
    # This EventSource is configured to receive webhooks from a specific GitHub repository.
    apiVersion: argoproj.io/v1alpha1
    kind: EventSource
    metadata:
      name: github-webhook
      namespace: argo-events
    spec:
      service:
        ports:
          - port: 12000
            targetPort: 12000
      github:
        example:
          repositories:
            - owner: <YOUR_GITHUB_USERNAME> # TODO: Replace with your GitHub username
              names:
                - go-restful-api-example
          webhook:
            endpoint: /push
            port: "12000"
            method: POST
            url: http://localhost # This will be exposed via a port-forward
          events:
            - "push"
          apiToken:
            name: github-webhook-secret
            key: secret
          insecure: true
          active: true
          contentType: json
    ---
    # 3. Sensor: Defines the logic for what to do when an event is received.
    # This Sensor listens for events from the 'github-webhook' EventSource and triggers an Argo Workflow in response.
    apiVersion: argoproj.io/v1alpha1
    kind: Sensor
    metadata:
      name: github-webhook
      namespace: argo-events
    spec:
      dependencies:
        - name: github-event
          eventSourceName: github-webhook
          eventName: example
      triggers:
        - template:
            name: github-workflow-trigger
            argoWorkflow:
              group: argoproj.io
              version: v1alpha1
              resource: workflows
              operation: submit
              source:
                resource:
                  apiVersion: argoproj.io/v1alpha1
                  kind: Workflow
                  metadata:
                    generateName: go-restful-api-ci-
                    namespace: argo
                  spec:
                    workflowTemplateRef:
                      name: go-restful-api-ci-template
                    arguments:
                      parameters:
                        - name: commit_sha
                          value: "placeholder"
              parameters:
                - src:
                    dependencyName: github-event
                    dataKey: body.head_commit.id
                  dest: spec.arguments.parameters.0.value
    ---
    # 4. Role: Defines permissions for a ServiceAccount.
    # This Role grants the permission to 'create' Argo Workflows in the 'argo' namespace.
    apiVersion: rbac.authorization.k8s.io/v1
    kind: Role
    metadata:
      name: submit-workflows
      namespace: argo
    rules:
      - apiGroups: ["argoproj.io"]
        resources: ["workflows"]
        verbs: ["create"]
      - apiGroups: ["argoproj.io"]
        resources: ["workflowtemplates"]
        verbs: ["get"]
    ---
    # 5. RoleBinding: Connects a Role to a ServiceAccount.
    # This RoleBinding grants the 'submit-workflows' Role to the 'default' ServiceAccount in the 'argo-events' namespace,
    # allowing the Sensor to trigger our CI/CD pipeline.
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: sensor-can-submit-workflows
      namespace: argo
    subjects:
      - kind: ServiceAccount
        name: default
        namespace: argo-events
    roleRef:
      kind: Role
      name: submit-workflows
      apiGroup: rbac.authorization.k8s.io
    ```

    Now, apply the consolidated manifest:

    ```bash
    kubectl apply -f .argo/webhook.yaml
    ```

3.  **Configure Git Credentials:** The CI/CD pipeline will need to push changes
    back to your Git repository. To do this, it needs credentials. We'll use a
    GitHub Personal Access Token (PAT).
    1.  **Create a GitHub PAT:** Go to your GitHub settings, then **Developer
        settings** > **Personal access tokens** > **Tokens (classic)**. Generate
        a new token with the `repo` scope.

    2.  **Create a Kubernetes Secret:** Create a secret in the `argo` namespace
        to store your PAT. Replace `<your-pat>` with the token you just created.

        ```bash
        kubectl -n argo create secret generic github-pat --from-literal=token=<your-pat>
        ```

4.  **Define the CI/CD Pipeline (WorkflowTemplate):** Instead of a one-off
    `Workflow`, we'll define a `WorkflowTemplate`. This makes our pipeline
    reusable. The `Sensor` will use this template to create a new `Workflow`
    instance for each `git push`.

    Save this as `.argo/ci-workflow-template.yaml`:

    ```yaml
    # .argo/ci-workflow-template.yaml

    # The WorkflowTemplate resource that defines our reusable CI/CD pipeline.
    apiVersion: argoproj.io/v1alpha1
    kind: WorkflowTemplate
    metadata:
      name: go-restful-api-ci-template
      namespace: argo
    spec:
      entrypoint: ci-pipeline
      arguments:
        parameters:
          - name: commit_sha
            value: main # A default value for manual runs

      templates:
        - name: ci-pipeline
          inputs:
            artifacts:
              - name: repo
                git:
                  repo: https://github.com/vyrwu/go-restful-api-example.git # TODO: Replace with your GitHub username
                  revision: "{{workflow.parameters.commit_sha}}"
          steps:
            - - name: lint-and-test
                template: lint-test-scan
                arguments:
                  artifacts:
                    - name: repo
                      from: "{{inputs.artifacts.repo}}"
            - - name: build-and-push
                template: build-push
                arguments:
                  artifacts:
                    - name: repo
                      from: "{{inputs.artifacts.repo}}"
            - - name: update-manifest
                template: update-manifest
                arguments:
                  artifacts:
                    - name: repo
                      from: "{{inputs.artifacts.repo}}"

        # This template runs the linting, testing, and scanning steps.
        - name: lint-test-scan
          inputs:
            artifacts:
              - name: repo
                path: /src
          container:
            image: golang:1.25
            command: [sh, -c]
            args: ["make deps && make ci"]
            workingDir: /src

        # This template builds the Docker image and loads it into the kind cluster.
        - name: build-push
          inputs:
            artifacts:
              - name: repo
                path: /src
          container:
            image: docker:20.10.17
            command: [sh, -c]
            args:
              - |
                COMMIT_SHA=$(git rev-parse --short HEAD)
                make build-and-load COMMIT_SHA=$COMMIT_SHA
            volumeMounts:
              - name: docker-sock
                mountPath: /var/run/docker.sock
          workingDir: /src

        # This template updates the Kubernetes manifest with the new image tag and pushes the change back to Git.
        - name: update-manifest
          inputs:
            artifacts:
              - name: repo
                path: /src
          container:
            image: alpine/git
            command: [sh, -c]
            args:
              - |
                COMMIT_SHA=$(git rev-parse --short HEAD)
                sed -i "s/image: go-restful-api-example:.*/image: go-restful-api-example:$COMMIT_SHA/" k8s/deployment.yaml
                git config --global user.email "ci@example.com"
                git config --global user.name "CI Bot"
                GIT_PAT=$(cat /etc/git-credentials/token)
                git remote set-url origin https://oauth2:$GIT_PAT@github.com/<YOUR_GITHUB_USERNAME>/go-restful-api-example.git # TODO: Replace with your GitHub username
                git add k8s/deployment.yaml
                git commit -m "Update image tag to $COMMIT_SHA [skip ci]"
                git push
            volumeMounts:
              - name: git-credentials
                mountPath: /etc/git-credentials
                readOnly: true
          workingDir: /src

      # Volumes provide a way to share data between steps in the workflow.
      volumes:
        # The 'docker-sock' volume mounts the Docker socket from the host, allowing us to build images.
        - name: docker-sock
          hostPath:
            path: /var/run/docker.sock
        # The 'git-credentials' volume mounts the GitHub PAT from a Kubernetes secret.
        - name: git-credentials
          secret:
            secretName: github-pat
    ```

    Now, apply the `WorkflowTemplate` to your cluster:

    ```bash
    kubectl apply -f .argo/ci-workflow-template.yaml
    ```

#### A Note on Local vs. Production Image Handling

In our `build-push` step, we use `kind load docker-image`. This is a special
command for local development with `kind`. Here's why it's necessary and how it
differs from a production workflow:

- **Why we use `kind load`:** `kind` runs your Kubernetes cluster inside Docker
  containers. When our workflow builds a new image, that image exists on your
  local machine's Docker daemon, but not inside the `kind` cluster nodes (which
  are separate containers). The `kind load` command pushes the image from your
  machine directly into the image cache of the `kind` nodes, making it available
  for pods to use without needing a remote registry.

- **How a production workflow differs:** In a typical production environment,
  the CI/CD pipeline would build the image and then **push** it to a central,
  network-accessible container registry (like Docker Hub, GCR, or ECR). The
  Kubernetes deployment manifest would then reference the full image URL from
  that registry. The cluster nodes would **pull** the image from the registry
  across the network. This approach is scalable and works for any remote
  Kubernetes cluster.

For this exercise, we use `kind load` to keep the setup simple and avoid the
need for you to configure and authenticate with an external container registry.

5.  **Connect GitHub to the Pipeline:** The final step is to create a GitHub
    webhook. This will send a `push` event to our `EventSource` whenever you
    push a code change, triggering the entire CI/CD pipeline.

    Because our `EventSource` is running inside a local `kind` cluster, it's not
    accessible from the public internet. We'll use a tool called `ngrok` to
    create a secure tunnel from a public URL to our local machine.
    1.  **Configure `ngrok`:** You will need an `ngrok` account for this.
        - Go to the [ngrok dashboard](https://dashboard.ngrok.com/signup) and
          sign up for a free account.
        - Follow the instructions to
          [install the ngrok agent](https://dashboard.ngrok.com/get-started/setup)
          and add your authtoken to the configuration file. This is a one-time
          setup.

    2.  **Expose the `EventSource` Service:** Before starting `ngrok`, we need
        to make the `EventSource`'s service available on a local port. Run the
        following command in a new terminal window. It will run in the
        foreground, so you can see any connection logs.

        ```bash
        kubectl -n argo-events port-forward service/github-webhook-eventsource-svc 7777:7777 &
        ```

    3.  **Start `ngrok`:** In another new terminal window, start `ngrok` to
        create the public tunnel to your local port `12000`.

        ```bash
        ngrok http 7777
        ```

        `ngrok` will display a public "Forwarding" URL (e.g.,
        `https://<random-string>.ngrok.io`). This is the public address that
        GitHub will send webhooks to. Copy this URL.

    4.  **Create the GitHub Webhook:**
        - Go to your forked repository's settings in GitHub.
        - Navigate to **Webhooks** and click **Add webhook**.
        - **Payload URL:** Paste the `ngrok` forwarding URL and add the `/push`
          endpoint (e.g., `https://<random-string>.ngrok.io/push`).
        - **Content type:** Select `application/json`.
        - **Secret:** Enter the same secret string you used in the
          `github-webhook-secret` Kubernetes secret earlier.
        - Click **Add webhook**.

    With this in place, any `git push` to your repository will trigger the
    `Sensor`, which in turn will submit our CI/CD `Workflow`.

**Preventing Workflow Loops:** Notice the commit message in the
`update-manifest` step: `Update image tag to $COMMIT_SHA [skip ci]`. This is
crucial. We must configure our webhook trigger in Argo Workflows to **ignore**
any commits that contain the string `[skip ci]`. This prevents the workflow from
triggering itself in an infinite loop after it pushes the updated manifest.

**Key Takeaway:** We now have a fully automated pipeline. When a developer
pushes a code change, Argo Workflows runs the CI steps, builds a new image, and
updates the deployment manifest. ArgoCD then detects the change in the manifest
and deploys the new version of the application. This is a complete,
GitOps-driven workflow that is efficient, consistent, and requires no manual
intervention.
