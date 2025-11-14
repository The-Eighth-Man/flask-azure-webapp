# Quick Deployment Guide

## Prerequisites Checklist

- [ ] Azure CLI installed and logged in
- [ ] Terraform installed (>= 1.0)
- [ ] Azure subscription active
- [ ] GitHub repository created (for CI/CD)

## Option 1: Deploy with Terraform (Manual)

### 1. Set up Azure Service Principal

```bash
# Login to Azure
az login

# Get your subscription ID
az account show --query id -o tsv

# Create service principal (replace <SUBSCRIPTION_ID>)
az ad sp create-for-rbac \
  --name "flask-app-terraform" \
  --role contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID> \
  --sdk-auth

# Save the JSON output for GitHub secrets
```

### 2. Configure Terraform

```bash
cd terraform

# Set environment variables
export ARM_CLIENT_ID="<appId>"
export ARM_CLIENT_SECRET="<password>"
export ARM_SUBSCRIPTION_ID="<subscription_id>"
export ARM_TENANT_ID="<tenant>"

# Create variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
nano terraform.tfvars
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan -var="db_admin_password=YourSecurePassword123!"

# Apply configuration
terraform apply -var="db_admin_password=YourSecurePassword123!"

# Save outputs
terraform output > ../terraform-outputs.txt
```

### 4. Deploy Application

```bash
cd ..

# Get app name from Terraform output
APP_NAME=$(cd terraform && terraform output -raw app_service_name)
RESOURCE_GROUP=$(cd terraform && terraform output -raw resource_group_name)

# Deploy code
az webapp up \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --runtime "PYTHON:3.11" \
  --sku B1
```

### 5. Test Deployment

```bash
# Get app URL
APP_URL=$(cd terraform && terraform output -raw app_service_url)

# Test endpoints
curl $APP_URL
curl $APP_URL/health
curl $APP_URL/items
```

## Option 2: Deploy with GitHub Actions (Recommended)

### 1. Push Code to GitHub

```bash
# Initialize git repository
git init
git add .
git commit -m "Initial commit: Flask app with Azure infrastructure"

# Add remote and push
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git branch -M main
git push -u origin main
```

### 2. Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:

```
AZURE_CREDENTIALS=<Full JSON output from service principal creation>
ARM_CLIENT_ID=<appId from service principal>
ARM_CLIENT_SECRET=<password from service principal>
ARM_SUBSCRIPTION_ID=<your subscription ID>
ARM_TENANT_ID=<tenant from service principal>
DB_ADMIN_PASSWORD=<your secure PostgreSQL password>
```

### 3. Trigger Deployment

```bash
# Push to main branch triggers deployment
git push origin main

# Or manually trigger from GitHub UI:
# Actions → Deploy Flask App to Azure → Run workflow
```

### 4. Monitor Deployment

- Go to Actions tab in GitHub
- Watch the workflow execution
- Check for any errors in the logs

### 5. Verify Deployment

Once the workflow completes:

```bash
# Get app URL from Terraform outputs in GitHub Actions logs
# Or check in Azure Portal

# Test the application
curl https://YOUR-APP-NAME.azurewebsites.net/health
```

## Quick Commands Reference

### Check Azure Resources

```bash
# List resource groups
az group list --output table

# List web apps
az webapp list --output table

# List PostgreSQL servers
az postgres flexible-server list --output table

# Check app logs
az webapp log tail --name <app-name> --resource-group flask-app-rg
```

### Terraform Commands

```bash
cd terraform

# Show current state
terraform show

# List resources
terraform state list

# Show outputs
terraform output

# Refresh state
terraform refresh -var="db_admin_password=YourPassword123!"

# Plan changes
terraform plan -var="db_admin_password=YourPassword123!"

# Apply changes
terraform apply -var="db_admin_password=YourPassword123!"

# Destroy infrastructure
terraform destroy -var="db_admin_password=YourPassword123!"
```

### Application Testing

```bash
# Set app URL
export APP_URL="https://your-app-name.azurewebsites.net"

# Test health
curl $APP_URL/health

# Create an item
curl -X POST $APP_URL/items \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Item", "description": "API test"}'

# Get all items
curl $APP_URL/items

# Get specific item
curl $APP_URL/items/1
```

### Troubleshooting Commands

```bash
# Check app settings
az webapp config appsettings list \
  --name <app-name> \
  --resource-group flask-app-rg

# Restart app
az webapp restart \
  --name <app-name> \
  --resource-group flask-app-rg

# SSH into container
az webapp ssh \
  --name <app-name> \
  --resource-group flask-app-rg

# Download logs
az webapp log download \
  --name <app-name> \
  --resource-group flask-app-rg \
  --log-file app-logs.zip

# Check VNET integration
az webapp vnet-integration list \
  --name <app-name> \
  --resource-group flask-app-rg

# Test database connection from local machine
psql "host=<postgres-fqdn> port=5432 dbname=appdb user=adminuser sslmode=require"
```

## Cost Estimation

| Resource | Tier | Monthly Cost (approx) |
|----------|------|----------------------|
| App Service Plan | B1 (Basic) | $13 |
| PostgreSQL Flexible Server | B_Standard_B1ms | $12 |
| VNET & Networking | Standard | $5 |
| **Total** | | **~$30** |

### Cost Optimization Tips

1. **Development**: Use F1 (Free) tier for App Service
2. **Off-hours**: Stop App Service during non-business hours
3. **Right-sizing**: Scale down if traffic is low
4. **Reserved Instances**: Save up to 40% with 1-year commitment

## Security Checklist

- [ ] Database password is strong and stored in secrets
- [ ] Service principal has minimum required permissions
- [ ] VNET isolation is configured correctly
- [ ] SSL/TLS is enabled for database connections
- [ ] Application insights enabled (optional)
- [ ] Managed identities configured (optional enhancement)

## Common Issues

### Issue: Terraform fails with authentication error
**Solution**: Verify ARM_* environment variables are set correctly

### Issue: App Service shows "Service Unavailable"
**Solution**:
- Check startup.sh is executable
- Review application logs with `az webapp log tail`
- Verify database connection environment variables

### Issue: Database connection timeout
**Solution**:
- Verify VNET integration is active
- Check private DNS zone is linked to VNET
- Confirm PostgreSQL is accessible from VNET subnet

### Issue: GitHub Actions workflow fails
**Solution**:
- Verify all secrets are configured correctly
- Check service principal has contributor access
- Review workflow logs for specific error messages

## Next Steps

After successful deployment:

1. **Set up monitoring**: Configure Application Insights
2. **Add custom domain**: Configure custom domain and SSL
3. **Configure backup**: Enable database backups
4. **Add CI/CD tests**: Add automated testing to workflow
5. **Scale as needed**: Adjust App Service plan based on traffic

## Support Resources

- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)
- [Azure PostgreSQL Documentation](https://docs.microsoft.com/azure/postgresql/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/actions)
