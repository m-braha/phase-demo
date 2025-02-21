# Phase Secrets Management Demo

This demo application showcases how to use Phase for secrets management across different environments: local development, GitHub Actions, and AWS ECS.

## Prerequisites

- Docker
- Docker Compose
- Node.js (for local development)
- AWS CLI (for ECS deployment)
- Terraform (for infrastructure deployment)
- Phase CLI (optional for local development)

## Environment Variables

The application expects the following environment variables:

- `DEMO_API_KEY`
- `DEMO_DATABASE_URL`
- `DEMO_ENCRYPTION_KEY`
- `DEMO_SERVICE_URL`
- `DEMO_SECRET_TOKEN`

These can be provided either through Phase or set directly.

For Phase configuration (optional):

- `PHASE_APP` - The name of your Phase application
- `PHASE_ENVIRONMENT` - The environment to use (e.g., development, staging, production)
- `PHASE_SERVICE_TOKEN` - Service token for authenticating with Phase

## Local Development

### Quick Start with Docker Compose

1. Clone the repository
2. Edit `docker-compose.yml` to uncomment and configure either Phase variables or direct environment variables
3. Start the development server:
   ```bash
   docker-compose up --build
   ```

The application will run with live reload enabled - any changes to the source code will automatically restart the server.

### Alternative: Running the Container Directly

#### Option 1: Using Phase

```bash
docker run \
  -e PHASE_APP=your-app-name \
  -e PHASE_ENVIRONMENT=development \
  -e PHASE_SERVICE_TOKEN=your-token \
  phase-demo
```

#### Option 2: Direct Environment Variables

```bash
docker run \
  -e DEMO_API_KEY=value1 \
  -e DEMO_DATABASE_URL=value2 \
  -e DEMO_ENCRYPTION_KEY=value3 \
  -e DEMO_SERVICE_URL=value4 \
  -e DEMO_SECRET_TOKEN=value5 \
  phase-demo
```

## GitHub Actions

The workflow will automatically:

1. Build the container
2. Run it with test secrets
3. Verify the secrets are correctly injected

Required GitHub Secrets:

- `PHASE_SERVICE_TOKEN_TEST` - Your Phase service token for the test environment

## AWS ECS Deployment

1. Configure your AWS credentials

2. Create the Phase service token in AWS Secrets Manager:

   ```bash
   aws secretsmanager create-secret \
     --name "phase/production/service-token" \
     --secret-string "your-production-token"
   ```

3. Initialize Terraform:

   ```bash
   cd terraform
   terraform init
   ```

4. Deploy:
   ```bash
   terraform apply \
     -var="container_image=your-image:tag" \
     -var="phase_app=your-app-name" \
     -var="phase_environment=production"
   ```

## API Endpoints

- `GET /` - Health check endpoint
- `GET /env` - Returns all configured environment variables and their values

## Security Notes

- The application never stores secrets locally
- Secrets can be injected at runtime through Phase or set directly
- Different environments use different Phase service tokens
- Service tokens are stored securely:
  - Local: Environment variables (optional)
  - GitHub Actions: GitHub Secrets
  - ECS: AWS Secrets Manager
- No secrets or tokens are committed to the repository or included in the container image
