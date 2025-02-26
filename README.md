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

For Phase configuration (optional), set these too:

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

This bypasses Phase completely.

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

2. Initialize Terraform:

   ```bash
   cd terraform
   terraform init
   ```

3. Create initial infrastructure with a dummy container image (this creates the ECR repository):

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
     -var="phase_app=demo-app" \
     -var="phase_environment=prod"
   ```

6. The ALB DNS name will be shown in the terraform output. You can access your application at:

   ```
   http://<ALB_DNS_NAME>
   ```

   Note: The ALB is configured to only allow traffic from the specified IP (50.203.25.222/32)

## API Endpoints

- `GET /` - Health check endpoint
- `GET /env` - Returns all configured environment variables and their values

## Security Notes

- The application never stores secrets locally
- Secrets are injected at runtime through Phase
- Service tokens are stored securely in AWS Secrets Manager
- ALB is configured to only allow traffic from specified IP addresses
- ECS tasks run in private subnets with access controlled via security groups
- No secrets or tokens are committed to the repository or included in the container image
