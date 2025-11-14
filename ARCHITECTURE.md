# Architecture Documentation

## System Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              GitHub Repository                          │
│                                                                         │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────────────┐ │
│  │  Flask App   │      │  Terraform   │      │  GitHub Actions      │ │
│  │  (Python)    │      │  (IaC)       │      │  (CI/CD)             │ │
│  └──────────────┘      └──────────────┘      └──────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Push to main
                                    ▼
                    ┌───────────────────────────────┐
                    │    GitHub Actions Pipeline    │
                    │                               │
                    │  1. Terraform Apply           │
                    │  2. Deploy Application        │
                    │  3. Health Check              │
                    └───────────────────────────────┘
                                    │
                                    │ Deploys to
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           Azure Cloud (Mexico Central)                   │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    Resource Group: flask-app-rg                     │ │
│  │                                                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────┐ │ │
│  │  │              Virtual Network (10.0.0.0/16)                    │ │ │
│  │  │                                                               │ │ │
│  │  │  ┌─────────────────────────┐  ┌────────────────────────────┐│ │ │
│  │  │  │ App Service Subnet      │  │ Private Endpoints Subnet   ││ │ │
│  │  │  │ (10.0.1.0/24)           │  │ (10.0.2.0/24)              ││ │ │
│  │  │  │                         │  │                            ││ │ │
│  │  │  │ ┌─────────────────────┐ │  │ ┌────────────────────────┐││ │ │
│  │  │  │ │   App Service       │ │  │ │  PostgreSQL Flexible   │││ │ │
│  │  │  │ │   (Linux/Python)    │─┼──┼─┤  Server (Private)      │││ │ │
│  │  │  │ │                     │ │  │ │  - Database: appdb     │││ │ │
│  │  │  │ │  - Flask App        │ │  │ │  - SSL: Required       │││ │ │
│  │  │  │ │  - Gunicorn         │ │  │ │  - Version: 15         │││ │ │
│  │  │  │ │  - Port: 8000       │ │  │ └────────────────────────┘││ │ │
│  │  │  │ └─────────────────────┘ │  │                            ││ │ │
│  │  │  │                         │  │  Private DNS Zone:         ││ │ │
│  │  │  │         VNET            │  │  privatelink.postgres...   ││ │ │
│  │  │  │      Integration        │  │                            ││ │ │
│  │  │  └─────────────────────────┘  └────────────────────────────┘│ │ │
│  │  │                                                               │ │ │
│  │  └──────────────────────────────────────────────────────────────┘ │ │
│  │                                                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────┐ │ │
│  │  │              App Service Plan (B1 - Linux)                    │ │ │
│  │  └──────────────────────────────────────────────────────────────┘ │ │
│  │                                                                     │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ HTTPS
                                    ▼
                            ┌───────────────┐
                            │     Users     │
                            │   (Internet)  │
                            └───────────────┘
```

## Network Flow

### Request Flow
1. User makes HTTPS request to `https://<app-name>.azurewebsites.net`
2. Request hits Azure Front Door / App Service Gateway
3. App Service routes traffic to Flask application via Gunicorn
4. Flask app processes request
5. If database access needed:
   - App makes connection through VNET integration
   - Connection routes through App Service Subnet (10.0.1.0/24)
   - Private endpoint in Private Endpoints Subnet (10.0.2.0/24)
   - Private DNS resolves PostgreSQL FQDN to private IP
   - Connection established to PostgreSQL over private network
6. Response flows back to user

### Security Layers

```
Internet → App Service (HTTPS) → VNET Integration → Private Endpoint → PostgreSQL
  ✓           ✓                     ✓                  ✓               ✓
Public      TLS 1.2+           Private Network    No Public IP     SSL Required
```

## Component Details

### 1. Flask Application (app.py)
- **Framework**: Flask 3.0
- **WSGI Server**: Gunicorn (4 workers)
- **ORM**: SQLAlchemy
- **Database Driver**: psycopg2-binary
- **Features**:
  - Health check endpoint with DB connectivity test
  - RESTful API for item management
  - Automatic table creation
  - Connection pooling
  - Error handling and logging

### 2. Azure App Service
- **Type**: Linux Web App
- **Runtime**: Python 3.11
- **Pricing Tier**: B1 (Basic)
- **Features**:
  - Always On enabled
  - VNET integration enabled
  - Environment variables for DB config
  - Auto-deployment from GitHub
  - Application logging enabled

### 3. PostgreSQL Flexible Server
- **Version**: PostgreSQL 15
- **Tier**: B_Standard_B1ms (Burstable)
- **Storage**: 32 GB
- **Backup**: 7 days retention
- **Network**: Private access only (no public endpoint)
- **SSL**: Required
- **Features**:
  - High availability zone (Zone 1)
  - Automatic backups
  - Private DNS integration
  - VNET integration via delegated subnet

### 4. Virtual Network
- **Address Space**: 10.0.0.0/16
- **Subnets**:
  - **App Service Subnet** (10.0.1.0/24)
    - Delegated to Microsoft.Web/serverFarms
    - Used for App Service VNET integration
  - **Private Endpoints Subnet** (10.0.2.0/24)
    - Hosts PostgreSQL private endpoint
    - No delegation required

### 5. Private DNS Zone
- **Zone Name**: privatelink.postgres.database.azure.com
- **Purpose**: Internal name resolution for PostgreSQL
- **Link**: Attached to VNET for automatic resolution

## Infrastructure as Code (Terraform)

### Resources Created
| Resource Type | Name Pattern | Purpose |
|--------------|--------------|---------|
| Resource Group | `flask-app-rg` | Container for all resources |
| Virtual Network | `flask-webapp-vnet` | Network isolation |
| Subnet | `app-service-subnet` | App Service integration |
| Subnet | `private-endpoints-subnet` | Database private endpoint |
| Private DNS Zone | `privatelink.postgres...` | Internal DNS |
| DNS Zone Link | `postgres-vnet-link` | Link DNS to VNET |
| PostgreSQL Server | `flask-webapp-postgres-*` | Database server |
| PostgreSQL Database | `appdb` | Application database |
| Firewall Rule | `allow-vnet` | VNET access only |
| Service Plan | `flask-webapp-plan` | App hosting plan |
| Web App | `flask-webapp-*` | Application host |

### Terraform State
- Stored locally by default
- **Recommendation**: Use Azure Storage Account for remote state in production

## CI/CD Pipeline (GitHub Actions)

### Deploy Workflow
```
┌─────────────────┐
│   Push to Main  │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│  Job 1: Terraform Infrastructure│
│  ─────────────────────────────  │
│  1. Checkout code               │
│  2. Setup Terraform             │
│  3. Azure login                 │
│  4. Terraform init              │
│  5. Terraform plan              │
│  6. Terraform apply             │
│  7. Export outputs              │
└────────┬────────────────────────┘
         │ Outputs: app_name,
         │          resource_group
         ▼
┌─────────────────────────────────┐
│  Job 2: Deploy Application      │
│  ─────────────────────────────  │
│  1. Checkout code               │
│  2. Setup Python 3.11           │
│  3. Create virtual environment  │
│  4. Install dependencies        │
│  5. Azure login                 │
│  6. Deploy to Web App           │
│  7. Health check test           │
│  8. Azure logout                │
└─────────────────────────────────┘
```

### Secrets Required
- `AZURE_CREDENTIALS`: Service principal JSON
- `ARM_CLIENT_ID`: Azure client ID
- `ARM_CLIENT_SECRET`: Azure client secret
- `ARM_SUBSCRIPTION_ID`: Azure subscription
- `ARM_TENANT_ID`: Azure tenant
- `DB_ADMIN_PASSWORD`: PostgreSQL password

## Data Flow

### Database Operations
```
┌──────────────┐
│ Flask App    │
│ (SQLAlchemy) │
└──────┬───────┘
       │ Connection String:
       │ postgresql://user:pass@server:5432/db?sslmode=require
       ▼
┌──────────────────┐
│ psycopg2 Driver  │
└──────┬───────────┘
       │ SSL/TLS Connection
       ▼
┌──────────────────────┐
│ VNET Integration     │
│ (Private Network)    │
└──────┬───────────────┘
       │ Private IP
       ▼
┌──────────────────────┐
│ Private DNS Zone     │
│ Resolves FQDN        │
└──────┬───────────────┘
       │ 10.0.2.x
       ▼
┌──────────────────────┐
│ PostgreSQL Server    │
│ (Private Endpoint)   │
└──────────────────────┘
```

## Security Architecture

### Network Security
1. **Isolation**: All resources within VNET
2. **No Public Access**: PostgreSQL has no public endpoint
3. **Private Connectivity**: App Service → Database via private network
4. **Firewall**: PostgreSQL only accepts VNET traffic

### Application Security
1. **HTTPS Only**: TLS 1.2+ enforced
2. **SSL to Database**: Required SSL mode for DB connections
3. **Secrets Management**: Environment variables (can be upgraded to Key Vault)
4. **Managed Identity Ready**: Can implement Azure AD authentication

### Access Control
1. **Service Principal**: Least privilege access for deployments
2. **RBAC**: Azure role-based access control
3. **Network Rules**: Subnet-level restrictions

## Scalability Considerations

### Current Capacity
- **App Service B1**: 1.75 GB RAM, 1 CPU core
- **PostgreSQL B1ms**: 2 vCores, 2 GB RAM
- **Estimated capacity**: ~100 concurrent users

### Scaling Options

#### Vertical Scaling
```
App Service:
B1 → S1 (Standard) → P1V2 (Premium) → P3V3

PostgreSQL:
B_Standard_B1ms → GP_Standard_D2s_v3 → MO_Standard_E4s_v3
```

#### Horizontal Scaling
- App Service: Auto-scale rules (Standard tier+)
- Database: Read replicas (Premium tier+)

## Monitoring and Observability

### Built-in Monitoring
- **App Service Metrics**: CPU, Memory, Response time
- **PostgreSQL Metrics**: Connections, CPU, Storage
- **Network Metrics**: Bandwidth, failed connections

### Logging
- **Application Logs**: Stdout/stderr from Flask
- **Web Server Logs**: Gunicorn access logs
- **Deployment Logs**: GitHub Actions logs

### Recommended Additions
- Application Insights for detailed telemetry
- Log Analytics workspace for centralized logging
- Azure Monitor alerts for critical metrics

## Disaster Recovery

### Backup Strategy
- **Database**: 7-day automated backups
- **Application Code**: Git repository
- **Infrastructure**: Terraform state

### Recovery Procedures
1. **Database Restore**: Point-in-time restore from backup
2. **Infrastructure**: `terraform apply` from saved state
3. **Application**: Redeploy from GitHub

### RTO/RPO
- **Recovery Time Objective (RTO)**: ~30 minutes
- **Recovery Point Objective (RPO)**: Up to 1 hour

## Cost Breakdown

### Monthly Costs (Estimated)
```
Service                      Tier         Cost/Month
─────────────────────────────────────────────────────
App Service Plan             B1           $13.00
PostgreSQL Flexible Server   B_Standard   $12.00
Virtual Network              Standard     $5.00
Private Endpoint             Standard     $7.20
Bandwidth (outbound)         Variable     ~$2.00
─────────────────────────────────────────────────────
Total                                     ~$39.20/mo
```

### Cost Optimization
- **Dev/Test**: Use F1 (Free) tier for App Service
- **Off-hours shutdown**: Stop resources during non-business hours
- **Reserved capacity**: 40% savings with 1-year commitment

## Performance Characteristics

### Expected Performance
- **Response Time**: <100ms (within Azure region)
- **Throughput**: ~50 requests/second (B1 tier)
- **Database Latency**: <10ms (private network)

### Bottlenecks
1. **App Service CPU**: Single core limitation on B1
2. **Database Connections**: Max 50 concurrent on B1ms
3. **Bandwidth**: 5 Mbps egress limit on B1

## Future Enhancements

### Security
- [ ] Implement Azure Key Vault for secrets
- [ ] Enable Managed Identity for database auth
- [ ] Add Web Application Firewall (WAF)
- [ ] Implement Azure AD authentication

### Scalability
- [ ] Configure auto-scaling rules
- [ ] Add Redis cache layer
- [ ] Implement database read replicas
- [ ] Use Azure Front Door for CDN

### Observability
- [ ] Integrate Application Insights
- [ ] Set up custom dashboards
- [ ] Configure alerting rules
- [ ] Implement distributed tracing

### Reliability
- [ ] Multi-region deployment
- [ ] Automated failover
- [ ] Health probes and circuit breakers
- [ ] Rate limiting and throttling

## Compliance and Governance

### Azure Policies
- Resource tagging enforcement
- Allowed locations restriction
- SKU restrictions
- Network security requirements

### Best Practices Implemented
- Infrastructure as Code
- Automated deployments
- Network isolation
- Encryption in transit and at rest
- Least privilege access

## References

- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)
- [Azure PostgreSQL Flexible Server](https://docs.microsoft.com/azure/postgresql/flexible-server/)
- [Azure VNET Integration](https://docs.microsoft.com/azure/app-service/web-sites-integrate-with-vnet)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
