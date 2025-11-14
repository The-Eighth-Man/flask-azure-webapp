#!/bin/bash
# Quick setup script for local development

set -e

echo "🚀 Flask App with Azure PostgreSQL - Setup Script"
echo "================================================"

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.11 or higher."
    exit 1
fi

echo "✅ Python found: $(python3 --version)"

# Create virtual environment
echo ""
echo "📦 Creating virtual environment..."
python3 -m venv venv

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "📥 Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Copy environment file
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit .env file with your database credentials"
else
    echo "✅ .env file already exists"
fi

# Check Azure CLI
echo ""
if command -v az &> /dev/null; then
    echo "✅ Azure CLI found: $(az --version | head -n 1)"
    echo "🔐 Current Azure account:"
    az account show --output table 2>/dev/null || echo "⚠️  Not logged in to Azure"
else
    echo "⚠️  Azure CLI not found. Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
fi

# Check Terraform
echo ""
if command -v terraform &> /dev/null; then
    echo "✅ Terraform found: $(terraform --version | head -n 1)"
else
    echo "⚠️  Terraform not found. Install from: https://www.terraform.io/downloads"
fi

echo ""
echo "✨ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Activate the virtual environment: source venv/bin/activate"
echo "2. Edit .env file with your database credentials"
echo "3. Run the app locally: python app.py"
echo "4. Or deploy to Azure using Terraform (see README.md)"
echo ""
