#!/bin/bash

# Akkeris-style Database Addon Script
# Usage: ./scripts/addon-db.sh <environment>
# Example: ./scripts/addon-db.sh dev-infra

set -e

ENVIRONMENT=${1:-dev-infra}
APP_NAME="myapp-db-db"
NAMESPACE="${APP_NAME}-${ENVIRONMENT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    command -v terraform >/dev/null 2>&1 || { log_error "terraform is required but not installed. Aborting."; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { log_error "kubectl is required but not installed. Aborting."; exit 1; }
    command -v aws >/dev/null 2>&1 || { log_error "aws cli is required but not installed. Aborting."; exit 1; }
    
    log_info "All prerequisites met."
}

# Provision database using Terraform
provision_database() {
    log_info "Provisioning PostgreSQL database for ${ENVIRONMENT} environment..."
    
    cd infra/rds-addon
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init
    
    # Apply Terraform configuration
    log_info "Creating database infrastructure..."
    terraform apply -var-file="environments/${ENVIRONMENT}.tfvars" -auto-approve
    
    # Get outputs
    DB_HOST=$(terraform output -raw db_instance_address)
    DB_PORT=$(terraform output -raw db_instance_port)
    DB_NAME=$(terraform output -raw db_instance_name)
    DB_USER=$(terraform output -raw db_instance_username)
    DB_SECRET_ARN=$(terraform output -raw db_credentials_secret_arn)
    
    cd ..
    
    log_info "Database provisioned successfully!"
    log_info "  Host: ${DB_HOST}"
    log_info "  Port: ${DB_PORT}"
    log_info "  Database: ${DB_NAME}"
    log_info "  User: ${DB_USER}"
}

# Get database password from AWS Secrets Manager
get_db_password() {
    log_info "Retrieving database password from AWS Secrets Manager..."
    
    DB_PASSWORD=$(aws secretsmanager get-secret-value \
        --secret-id "${DB_SECRET_ARN}" \
        --query 'SecretString' \
        --output text | jq -r '.password')
    
    if [ -z "$DB_PASSWORD" ]; then
        log_error "Failed to retrieve database password"
        exit 1
    fi
    
    log_info "Password retrieved successfully."
}

# Create Kubernetes namespace if it doesn't exist
create_namespace() {
    log_info "Creating namespace ${NAMESPACE} if it doesn't exist..."
    
    kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    
    log_info "Namespace ready."
}

# Attach database to app by creating Kubernetes secret
attach_database() {
    log_info "Attaching database to ${APP_NAME} application..."
    
    # Create Kubernetes secret with database credentials
    kubectl create secret generic ${APP_NAME}-db-credentials \
        --from-literal=DB_HOST="${DB_HOST}" \
        --from-literal=DB_PORT="${DB_PORT}" \
        --from-literal=DB_NAME="${DB_NAME}" \
        --from-literal=DB_USER="${DB_USER}" \
        --from-literal=DB_PASSWORD="${DB_PASSWORD}" \
        --namespace=${NAMESPACE} \
        --dry-run=client -o yaml | kubectl apply -f -
    
    log_info "Database credentials stored in Kubernetes secret: ${APP_NAME}-db-credentials"
    
    # Label the secret for easy identification
    kubectl label secret ${APP_NAME}-db-credentials \
        app=${APP_NAME} \
        environment=${ENVIRONMENT} \
        addon=postgres \
        --namespace=${NAMESPACE} \
        --overwrite
    
    log_info "Database attached successfully!"
}

# Display connection information
display_info() {
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Database Addon Information"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  App Name:    ${APP_NAME}"
    echo "  Environment: ${ENVIRONMENT}"
    echo "  Namespace:   ${NAMESPACE}"
    echo "  Database:    PostgreSQL"
    echo "  Host:        ${DB_HOST}"
    echo "  Port:        ${DB_PORT}"
    echo "  Database:    ${DB_NAME}"
    echo "  User:        ${DB_USER}"
    echo "  Secret:      ${APP_NAME}-db-credentials"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "Environment variables will be automatically injected into your app:"
    echo "  - DB_HOST"
    echo "  - DB_PORT"
    echo "  - DB_NAME"
    echo "  - DB_USER"
    echo "  - DB_PASSWORD"
    echo ""
    log_info "To test the connection:"
    echo "  kubectl run psql-test --rm -it --image=postgres:15 --namespace=${NAMESPACE} -- psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME}"
}

# Main execution
main() {
    log_info "Creating database addon for ${ENVIRONMENT} environment..."
    check_prerequisites
    provision_database
    get_db_password
    create_namespace
    attach_database
    display_info
    log_info "${GREEN}✓${NC} Database addon created and attached successfully!"
}

# Run main function
main
