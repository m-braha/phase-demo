# Phase Secrets Management Demo

This demo application showcases how to use Phase for secrets management across different environments: local development, GitHub Actions, and AWS ECS.

## Prerequisites

- Docker
- Docker Compose
- Node.js (for local development)
- AWS CLI (for ECS deployment)
- Terraform (for infrastructure deployment)
- Phase CLI (for local development)

## Environment Variables

The application expects the following secret environment variables at runtime:

- `DEMO_API_KEY`
- `DEMO_DATABASE_URL`
- `DEMO_ENCRYPTION_KEY`
- `DEMO_SERVICE_URL`
- `DEMO_SECRET_TOKEN`

To mimic build time secrets, like credentials to private registries, these variables are expected:

- `DEMO_TROVE_AUTH`

All of these variables can be provided either through Phase. To demonstrate fallback behavior if Phase is not desired, they can also be set directly.

For Phase configuration, set these as well:

- `PHASE_APP` - The name of the Phase application
- `PHASE_ENVIRONMENT` - The environment to use (e.g., development, staging, production)
- `PHASE_SERVICE_TOKEN` - Service token for authenticating with Phase

## Local Development

### Quick Start with Docker Compose

1. Clone the repository
1. Source the Phase tokens
   ```bash
   . tokens
   ```
1. Start the development server:
   ```bash
   docker-compose up --build -d
   ```

You can edit the [`docker-compose`](./docker-compose.yml) file and comment out the Phase variables and uncomment the lines to set the variables directly, bypassing Phase.

The application will run with live reload enabled - any changes to the source code will instantly be seen.

### Alternative: Running the Container Directly

#### Option 1: Using Phase

```bash
# Build container first
docker build . -t phase-demo
docker run \
  --detach \
  --name phase-demo \
  -p 3000:3000 \
  -e PHASE_APP=example-app \
  -e PHASE_ENVIRONMENT=development \
  -e PHASE_SERVICE_TOKEN=${PHASE_SERVICE_TOKEN_DEV} \
  -e DEMO_TROVE_AUTH=yes \
  phase-demo
```

#### Option 2: Direct Environment Variables

This bypasses Phase completely.

```bash
# Build container first
docker build . -t phase-demo
docker run \
  --detach \
  --name phase-demo \
  -p 3000:3000 \
  -e DEMO_API_KEY=value1 \
  -e DEMO_DATABASE_URL=value2 \
  -e DEMO_ENCRYPTION_KEY=value3 \
  -e DEMO_SERVICE_URL=value4 \
  -e DEMO_SECRET_TOKEN=value5 \
  -e DEMO_TROVE_AUTH=yes \
  phase-demo
```

### Testing the Container

Once running, you can call the API to see the environment variables:

```bash
# Confirm the app is running
curl localhost:3000
# Print the env vars for the development environment
curl localhost:3000/env
# If using docker compose, print the env vars for prod and staging too
curl localhost:3001/env
curl localhost:3002/env
```

### Cleanup

If you ran the Docker Compose, shut it down with:

    docker compose down

If you ran the container directly, shut it down and remove it with:

    docker rm -f phase-demo

## GitHub Actions

The workflow demonstrates how to use Phase secrets in a CI/CD pipeline. When triggered by a push to main, pull request, or manual dispatch, it will:

1. Check out the repository
2. Fetch Phase secrets for the staging environment
3. Build the container using the fetched secrets

### Quick Start with GitHub Actions

1. Add the required GitHub Secret (already done):
   - `PHASE_SERVICE_TOKEN_STAGING` - The Phase service token for the staging environment
2. Trigger the workflow either by:
   - Pushing to the main branch
   - Creating a pull request
   - Using the "Run workflow" button in the Actions tab

The workflow showcases how Phase can securely inject secrets during the CI/CD process, similar to how it works in local development. A local GitHub action demonstrates how this can be abstracted for general use.

## AWS ECS Deployment

Terraform is used to deploy a minimal stack to AWS account "Eng-Experiments".

1. Configure AWS credentials, probably with `assume`. You'll need write permissions in the target account.

2. Initialize Terraform:

   ```bash
   cd terraform
   terraform init
   ```

3. Create initial infrastructure with a dummy container image (this creates the ECR repository). Normally, a GitHub action might push this image but we skip that:

   ```bash
   terraform plan -var="phase_service_token=dummy" -var="phase_app=demo-app" -var="phase_environment=prod"
   terraform apply -var="phase_service_token=dummy" -var="phase_app=demo-app" -var="phase_environment=prod"
   ```

4. Note the ECR repository URL from the terraform output. Build and push your container:

   ```bash
   # Login to ECR
   aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <ECR_REPO_URL>

   # Build for x86_64 (required for ECS)
   docker build --platform linux/amd64 -t phase-demo-prod .

   # Tag and push
   docker tag phase-demo-prod:latest <ECR_REPO_URL>:latest
   docker push <ECR_REPO_URL>:latest
   ```

5. Deploy the full infrastructure with your Phase service token:

   ```bash
   terraform apply \
     -var="phase_service_token=your-actual-token" \
     -var="phase_app=example-app" \
     -var="phase_environment=prod"
   ```

6. The ALB DNS name will be shown in the terraform output as `alb_dns_name`. You can access the application now:

   ```bash
   # using the httpie client
   http -b phase-demo-prod-164751846.us-west-2.elb.amazonaws.com/env
   {
      "app": "example-app",
      "environment": "prod",
      "variables": {
         "DEMO_API_KEY": "prod-value1",
         "DEMO_DATABASE_URL": "prod-value2",
         "DEMO_ENCRYPTION_KEY": "prod-value3",
         "DEMO_SECRET_TOKEN": "prod-value5",
         "DEMO_SERVICE_URL": "prod-value4",
         "PHASE_APP": "example-app",
         "PHASE_ENVIRONMENT": "prod"
      }
   }
   ```

   Note: The ALB is configured to only allow traffic from the office IP (50.203.25.222/32)

## API Endpoints

- `GET /` - Health check endpoint
- `GET /env` - Returns all configured environment variables and their values

## Security Notes

### Secret Storage and Access

- The application never stores secrets locally on disk
- Secrets are fetched at runtime through Phase's secure API
- Service tokens are the only long-lived credentials and are stored securely:
  - Locally: In your environment or secure token files
  - CI/CD: In GitHub Secrets
  - Production: In AWS Secrets Manager

### Environment Isolation

- Each environment (development, staging, production) has its own:
  - Phase service token with specific permissions
  - Set of secrets
  - Access controls
- This prevents staging secrets from being used in production and vice-versa

### Local Development Security

- Docker Compose setup demonstrates secure secret injection without storing values in the compose file
- Direct environment variables option shows how Phase can be bypassed for local testing

### CI/CD Security

- GitHub Actions workflow fetches secrets at build time
- Phase service tokens are scoped to specific environments and stored securely

### Runtime Security

- Secrets are fetched on container start
- No secret values are exposed in logs or environment dumps
- If Phase becomes unavailable, the application can fall back to environment variables
- Service tokens can be rotated without rebuilding containers

### Best Practices Demonstrated

- Separation of configuration from secrets
- Environment-specific secret management
- No secret values in version control
- Minimal secret access scope (service tokens limited by environment)
- Secure secret injection at runtime
- Clear fallback mechanisms for local development
