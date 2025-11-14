# Flask Web App with Azure PostgreSQL - Private VNET Architecture

A production-ready Flask web application deployed on Azure App Service with PostgreSQL Flexible Server, all resources secured within a Virtual Network (VNET) with private connectivity.

## Architecture Overview

This solution implements a secure architecture with:

- **Flask Web Application**: Running on Azure App Service (Linux)
- **PostgreSQL Database**: Azure PostgreSQL Flexible Server
- **Private Networking**: All resources within a VNET with private endpoints
- **Infrastructure as Code**: Terraform for infrastructure provisioning
- **CI/CD**: GitHub Actions for automated deployment

### Network Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Azure VNET (10.0.0.0/16)             │
│                                                          │
│  ┌──────────────────────────┐  ┌────────────────────┐  │
│  │  App Service Subnet      │  │  Private Endpoints │  │
│  │  (10.0.1.0/24)           │  │  Subnet            │  │
│  │                          │  │  (10.0.2.0/24)     │  │
│  │  ┌──────────────────┐    │  │                    │  │
│  │  │  Flask App       │────┼──┼──► PostgreSQL     │  │
│  │  │  (App Service)   │    │  │     Flexible      │  │
│  │  └──────────────────┘    │  │     Server        │  │
│  │                          │  │                    │  │
│  └──────────────────────────┘  └────────────────────┘  │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Features

- ✅ Private database connectivity (no public internet exposure)
- ✅ VNET integration for App Service
- ✅ SSL/TLS encrypted database connections
- ✅ RESTful API with health checks
- ✅ Infrastructure as Code with Terraform
- ✅ Automated CI/CD with GitHub Actions
- ✅ Environment variable configuration
- ✅ Database models with SQLAlchemy ORM

## Prerequisites

- Azure subscription
- Azure CLI installed and configured
- Terraform >= 1.0
- Python 3.11+
- GitHub account (for CI/CD)

## Local Development Setup

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd a
   ```

2. **Create a virtual environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your database credentials
   ```

5. **Run the application**
   ```bash
   python app.py
   ```

   The app will be available at `http://localhost:8000`

## Azure Infrastructure Setup

### Step 1: Configure Azure Authentication

1. **Create a Service Principal**
   ```bash
   az ad sp create-for-rbac \
     --name "flask-app-terraform" \
     --role contributor \
     --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID> \
     --sdk-auth
   ```

   Save the JSON output - you'll need it for GitHub secrets.

2. **Set environment variables for Terraform**
   ```bash
   export ARM_CLIENT_ID="<client_id>"
   export ARM_CLIENT_SECRET="<client_secret>"
   export ARM_SUBSCRIPTION_ID="<subscription_id>"
   export ARM_TENANT_ID="<tenant_id>"
   ```

### Step 2: Deploy Infrastructure with Terraform

1. **Navigate to terraform directory**
   ```bash
   cd terraform
   ```

2. **Initialize Terraform**
   ```bash
   terraform init
   ```

3. **Create terraform.tfvars**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

   Edit `terraform.tfvars` and update values:
   ```hcl
   resource_group_name = "flask-app-rg"
   location            = "mexicocentral"
   app_name            = "flask-webapp"
   environment         = "production"
   ```

4. **Plan the deployment**
   ```bash
   terraform plan -var="db_admin_password=YourSecurePassword123!"
   ```

5. **Apply the configuration**
   ```bash
   terraform apply -var="db_admin_password=YourSecurePassword123!"
   ```

   This will create:
   - Resource Group
   - Virtual Network with subnets
   - PostgreSQL Flexible Server with private endpoint
   - Private DNS Zone
   - App Service Plan
   - App Service with VNET integration

6. **Get outputs**
   ```bash
   terraform output
   ```

### Step 3: Verify Infrastructure

```bash
# Check resource group
az group show --name flask-app-rg

# Check App Service
az webapp list --resource-group flask-app-rg --output table

# Check PostgreSQL server
az postgres flexible-server list --resource-group flask-app-rg --output table

# Check VNET
az network vnet list --resource-group flask-app-rg --output table
```

## GitHub Actions CI/CD Setup

### Configure GitHub Secrets

Add the following secrets to your GitHub repository (Settings → Secrets and variables → Actions):

1. **AZURE_CREDENTIALS**: The JSON output from service principal creation
2. **ARM_CLIENT_ID**: Service principal client ID
3. **ARM_CLIENT_SECRET**: Service principal client secret
4. **ARM_SUBSCRIPTION_ID**: Your Azure subscription ID
5. **ARM_TENANT_ID**: Your Azure tenant ID
6. **DB_ADMIN_PASSWORD**: PostgreSQL admin password

### Workflow Files

Two workflows are included:

1. **`deploy.yml`**: Automatically deploys infrastructure and application on push to main
2. **`terraform-destroy.yml`**: Manual workflow to destroy infrastructure (requires typing "destroy" to confirm)

### Trigger Deployment

```bash
git add .
git commit -m "Initial deployment"
git push origin main
```

The GitHub Actions workflow will:
1. Provision/update infrastructure with Terraform
2. Deploy the Flask application
3. Run health checks

## API Endpoints

### Root Endpoint
```bash
GET /
```
Returns API information and available endpoints.

### Health Check
```bash
GET /health
```
Returns application health status and database connectivity.

**Response:**
```json
{
  "status": "healthy",
  "database": "connected",
  "timestamp": "2024-11-14T12:00:00"
}
```

### Get All Items
```bash
GET /items
```

### Create Item
```bash
POST /items
Content-Type: application/json

{
  "name": "Sample Item",
  "description": "This is a sample item"
}
```

### Get Item by ID
```bash
GET /items/{id}
```

## Testing the Deployment

After deployment, test the endpoints:

```bash
# Get the app URL from Terraform output
APP_URL=$(cd terraform && terraform output -raw app_service_url)

# Test root endpoint
curl $APP_URL

# Test health endpoint
curl $APP_URL/health

# Create an item
curl -X POST $APP_URL/items \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Item", "description": "Testing the API"}'

# Get all items
curl $APP_URL/items
```

## Security Features

1. **Private Network**: Database is only accessible within the VNET
2. **No Public Endpoints**: PostgreSQL has no public IP address
3. **SSL/TLS**: Database connections use SSL encryption
4. **Managed Identities**: Can be extended to use Azure Managed Identities
5. **Network Isolation**: App Service integrated with VNET
6. **Private DNS**: Private DNS zone for internal name resolution

## Monitoring and Troubleshooting

### View Application Logs

```bash
# Stream logs
az webapp log tail --name <app-name> --resource-group flask-app-rg

# Download logs
az webapp log download --name <app-name> --resource-group flask-app-rg
```

### Check App Service Configuration

```bash
az webapp config appsettings list \
  --name <app-name> \
  --resource-group flask-app-rg
```

### Test Database Connectivity from App Service

```bash
az webapp ssh --name <app-name> --resource-group flask-app-rg
# Inside the container:
python -c "from app import db; db.session.execute(db.text('SELECT 1'))"
```

### Common Issues

**Issue: Database connection timeout**
- Check VNET integration is properly configured
- Verify private DNS zone is linked to VNET
- Ensure PostgreSQL firewall rules allow VNET traffic

**Issue: App Service won't start**
- Check application logs: `az webapp log tail`
- Verify environment variables are set correctly
- Check startup.sh has execute permissions

**Issue: Terraform apply fails**
- Ensure service principal has correct permissions
- Check resource naming (must be globally unique)
- Verify subscription quota limits

## Cost Optimization

Current configuration uses:
- **App Service Plan**: B1 (Basic) - ~$13/month
- **PostgreSQL**: B_Standard_B1ms - ~$12/month
- **Networking**: Minimal costs for VNET and private endpoints

Total estimated cost: ~$30-40/month

To reduce costs:
- Use F1 (Free) tier for development/testing
- Scale down during non-business hours
- Use Azure Dev/Test pricing if eligible

## Cleanup

### Using Terraform
```bash
cd terraform
terraform destroy -var="db_admin_password=YourSecurePassword123!"
```

### Using GitHub Actions
1. Go to Actions tab
2. Select "Terraform Destroy" workflow
3. Click "Run workflow"
4. Type "destroy" to confirm

### Manual Cleanup
```bash
az group delete --name flask-app-rg --yes --no-wait
```

## Project Structure

```
.
├── app.py                          # Flask application
├── requirements.txt                # Python dependencies
├── startup.sh                      # App Service startup script
├── .env.example                    # Environment variables template
├── README.md                       # This file
├── terraform/
│   ├── main.tf                     # Terraform configuration
│   ├── terraform.tfvars.example    # Terraform variables template
│   └── .gitignore                  # Terraform gitignore
└── .github/
    └── workflows/
        ├── deploy.yml              # CI/CD deployment workflow
        └── terraform-destroy.yml   # Infrastructure cleanup workflow
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License

## Support

For issues and questions:
- Open an issue in the GitHub repository
- Check Azure documentation: https://docs.microsoft.com/azure
- Terraform Azure Provider: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
