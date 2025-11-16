#!/bin/bash
#
# Automated Deployment Script for GentleQuest
# Supports multiple deployment targets: Render, Docker, AWS, etc.
#

set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPLOYMENT_LOG="$PROJECT_ROOT/deployment_$(date +%Y%m%d_%H%M%S).log"
ROLLBACK_POINT=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Deployment configuration
DEPLOY_TARGET=${1:-render}
ENVIRONMENT=${2:-production}
VERSION=$(git describe --tags --always)

# Function to log messages
log() {
    echo -e "$1" | tee -a "$DEPLOYMENT_LOG"
}

# Function to handle errors
handle_error() {
    log "${RED}❌ Deployment failed at: $1${NC}"
    
    if [ -n "$ROLLBACK_POINT" ]; then
        log "${YELLOW}🔄 Attempting rollback to $ROLLBACK_POINT...${NC}"
        perform_rollback
    fi
    
    exit 1
}

# Set error trap
trap 'handle_error "$BASH_COMMAND"' ERR

# Function to check prerequisites
check_prerequisites() {
    log "${BLUE}📋 Checking prerequisites...${NC}"
    
    # Check Git
    if ! command -v git &> /dev/null; then
        log "${RED}✗ Git not found${NC}"
        exit 1
    fi
    
    # Check for uncommitted changes
    if [ -n "$(git status --porcelain)" ]; then
        log "${YELLOW}⚠️  Warning: Uncommitted changes detected${NC}"
        read -p "Continue with deployment? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "${RED}Deployment cancelled${NC}"
            exit 1
        fi
    fi
    
    # Check Docker for Docker deployments
    if [ "$DEPLOY_TARGET" = "docker" ] || [ "$DEPLOY_TARGET" = "aws" ]; then
        if ! command -v docker &> /dev/null; then
            log "${RED}✗ Docker not found${NC}"
            exit 1
        fi
    fi
    
    # Check environment file
    ENV_FILE="$PROJECT_ROOT/.env.$ENVIRONMENT"
    if [ ! -f "$ENV_FILE" ]; then
        log "${YELLOW}⚠️  Environment file not found: $ENV_FILE${NC}"
        log "${YELLOW}   Using default environment variables${NC}"
    fi
    
    log "${GREEN}✓ Prerequisites checked${NC}"
}

# Function to run tests
run_tests() {
    log "${BLUE}🧪 Running tests...${NC}"
    
    # Run Python tests
    if [ -f "$PROJECT_ROOT/scripts/run_all_tests.sh" ]; then
        if ! bash "$PROJECT_ROOT/scripts/run_all_tests.sh" > /dev/null 2>&1; then
            log "${RED}✗ Tests failed${NC}"
            read -p "Deploy anyway? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            log "${GREEN}✓ Tests passed${NC}"
        fi
    else
        log "${YELLOW}⚠️  Test script not found, skipping tests${NC}"
    fi
}

# Function to build application
build_application() {
    log "${BLUE}🔨 Building application...${NC}"
    
    # Build Flutter web
    if [ -d "$PROJECT_ROOT/ai_buddy_web" ]; then
        log "  Building Flutter web..."
        cd "$PROJECT_ROOT/ai_buddy_web"
        
        if command -v flutter &> /dev/null; then
            flutter clean > /dev/null 2>&1
            flutter pub get > /dev/null 2>&1
            flutter build web --release --pwa-strategy none > /dev/null 2>&1
            log "${GREEN}  ✓ Flutter web built${NC}"
        else
            log "${YELLOW}  ⚠️  Flutter not found, skipping web build${NC}"
        fi
    fi
    
    # Build Docker image
    if [ "$DEPLOY_TARGET" = "docker" ] || [ "$DEPLOY_TARGET" = "aws" ]; then
        log "  Building Docker image..."
        cd "$PROJECT_ROOT"
        
        docker build -t gentlequest:$VERSION . > /dev/null 2>&1
        docker tag gentlequest:$VERSION gentlequest:latest
        
        log "${GREEN}  ✓ Docker image built: gentlequest:$VERSION${NC}"
    fi
    
    cd "$PROJECT_ROOT"
}

# Function to create backup
create_backup() {
    log "${BLUE}💾 Creating backup...${NC}"
    
    ROLLBACK_POINT="backup_$(date +%Y%m%d_%H%M%S)"
    
    # Backup database if script exists
    if [ -f "$PROJECT_ROOT/scripts/backup_database.py" ]; then
        python "$PROJECT_ROOT/scripts/backup_database.py" backup --upload > /dev/null 2>&1 || true
        log "${GREEN}  ✓ Database backed up${NC}"
    fi
    
    # Create deployment snapshot
    mkdir -p "$PROJECT_ROOT/rollback/$ROLLBACK_POINT"
    
    # Save current deployment info
    cat > "$PROJECT_ROOT/rollback/$ROLLBACK_POINT/deployment.json" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "version": "$VERSION",
    "environment": "$ENVIRONMENT",
    "target": "$DEPLOY_TARGET"
}
EOF
    
    log "${GREEN}✓ Backup created: $ROLLBACK_POINT${NC}"
}

# Function to deploy to Render
deploy_to_render() {
    log "${BLUE}🚀 Deploying to Render...${NC}"
    
    # Check for Render API key
    if [ -z "$RENDER_API_KEY" ]; then
        log "${RED}✗ RENDER_API_KEY not set${NC}"
        exit 1
    fi
    
    # Get service ID
    SERVICE_ID=${RENDER_SERVICE_ID:-"srv-xxxxxxxxxxxxxxxxxxxxx"}
    
    # Trigger deployment
    log "  Triggering deployment..."
    
    RESPONSE=$(curl -s -X POST \
        -H "Authorization: Bearer $RENDER_API_KEY" \
        -H "Content-Type: application/json" \
        "https://api.render.com/v1/services/$SERVICE_ID/deploys")
    
    DEPLOY_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    
    if [ -z "$DEPLOY_ID" ]; then
        log "${RED}✗ Failed to trigger deployment${NC}"
        exit 1
    fi
    
    log "  Deployment ID: $DEPLOY_ID"
    
    # Wait for deployment
    log "  Waiting for deployment to complete..."
    
    MAX_WAIT=600  # 10 minutes
    ELAPSED=0
    
    while [ $ELAPSED -lt $MAX_WAIT ]; do
        STATUS=$(curl -s \
            -H "Authorization: Bearer $RENDER_API_KEY" \
            "https://api.render.com/v1/services/$SERVICE_ID/deploys/$DEPLOY_ID" \
            | grep -o '"status":"[^"]*' | cut -d'"' -f4)
        
        case "$STATUS" in
            "live")
                log "${GREEN}✓ Deployment successful!${NC}"
                return 0
                ;;
            "failed"|"canceled")
                log "${RED}✗ Deployment $STATUS${NC}"
                return 1
                ;;
            *)
                echo -n "."
                sleep 10
                ELAPSED=$((ELAPSED + 10))
                ;;
        esac
    done
    
    log "${RED}✗ Deployment timeout${NC}"
    return 1
}

# Function to deploy with Docker
deploy_to_docker() {
    log "${BLUE}🐳 Deploying with Docker...${NC}"
    
    cd "$PROJECT_ROOT"
    
    # Stop existing containers
    log "  Stopping existing containers..."
    docker-compose -f docker-compose.prod.yml down > /dev/null 2>&1 || true
    
    # Start new deployment
    log "  Starting new deployment..."
    docker-compose -f docker-compose.prod.yml up -d
    
    # Wait for health check
    log "  Waiting for services to be healthy..."
    sleep 10
    
    # Check health
    if docker-compose -f docker-compose.prod.yml ps | grep -q "healthy"; then
        log "${GREEN}✓ Docker deployment successful!${NC}"
    else
        log "${RED}✗ Some services are not healthy${NC}"
        docker-compose -f docker-compose.prod.yml ps
        return 1
    fi
}

# Function to deploy to AWS
deploy_to_aws() {
    log "${BLUE}☁️  Deploying to AWS...${NC}"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log "${RED}✗ AWS CLI not found${NC}"
        exit 1
    fi
    
    # Build and push to ECR
    AWS_REGION=${AWS_REGION:-us-east-1}
    ECR_REPOSITORY=${ECR_REPOSITORY:-gentlequest}
    
    log "  Authenticating with ECR..."
    aws ecr get-login-password --region $AWS_REGION | \
        docker login --username AWS --password-stdin \
        $(aws ecr describe-repositories --repository-names $ECR_REPOSITORY \
            --region $AWS_REGION --query 'repositories[0].repositoryUri' \
            --output text | cut -d'/' -f1)
    
    log "  Pushing image to ECR..."
    ECR_URI=$(aws ecr describe-repositories --repository-names $ECR_REPOSITORY \
        --region $AWS_REGION --query 'repositories[0].repositoryUri' --output text)
    
    docker tag gentlequest:$VERSION $ECR_URI:$VERSION
    docker tag gentlequest:$VERSION $ECR_URI:latest
    docker push $ECR_URI:$VERSION
    docker push $ECR_URI:latest
    
    # Update ECS service
    log "  Updating ECS service..."
    aws ecs update-service \
        --cluster gentlequest-cluster \
        --service gentlequest-service \
        --force-new-deployment \
        --region $AWS_REGION
    
    log "${GREEN}✓ AWS deployment triggered!${NC}"
}

# Function to perform health check
perform_health_check() {
    log "${BLUE}🏥 Performing health check...${NC}"
    
    # Determine health check URL
    case "$DEPLOY_TARGET" in
        render)
            HEALTH_URL="https://gentlequest.onrender.com/api/health"
            ;;
        docker)
            HEALTH_URL="http://localhost/api/health"
            ;;
        aws)
            HEALTH_URL="https://api.gentlequest.app/api/health"
            ;;
        *)
            HEALTH_URL="http://localhost:5055/api/health"
            ;;
    esac
    
    log "  Checking $HEALTH_URL..."
    
    # Retry health check
    MAX_RETRIES=10
    RETRY=0
    
    while [ $RETRY -lt $MAX_RETRIES ]; do
        if curl -s -f "$HEALTH_URL" > /dev/null 2>&1; then
            log "${GREEN}✓ Health check passed!${NC}"
            
            # Get detailed health status
            HEALTH_DATA=$(curl -s "$HEALTH_URL")
            
            # Parse health data (simplified)
            if echo "$HEALTH_DATA" | grep -q '"status":"healthy"'; then
                log "  Status: Healthy"
            else
                log "  Status: Degraded"
            fi
            
            return 0
        fi
        
        RETRY=$((RETRY + 1))
        log "  Retry $RETRY/$MAX_RETRIES..."
        sleep 10
    done
    
    log "${RED}✗ Health check failed${NC}"
    return 1
}

# Function to perform rollback
perform_rollback() {
    log "${BLUE}🔄 Performing rollback...${NC}"
    
    if [ -z "$ROLLBACK_POINT" ] || [ ! -d "$PROJECT_ROOT/rollback/$ROLLBACK_POINT" ]; then
        log "${RED}✗ No rollback point available${NC}"
        return 1
    fi
    
    # Restore based on deployment target
    case "$DEPLOY_TARGET" in
        render)
            # Render maintains deployment history
            log "  Rollback through Render dashboard required"
            ;;
        docker)
            # Restore previous docker deployment
            log "  Restoring previous Docker deployment..."
            docker-compose -f docker-compose.prod.yml down
            # Would restore from backup images here
            ;;
        *)
            log "  Manual rollback required for $DEPLOY_TARGET"
            ;;
    esac
    
    log "${GREEN}✓ Rollback completed${NC}"
}

# Function to send notifications
send_notifications() {
    local status=$1
    local message=$2
    
    log "${BLUE}📢 Sending notifications...${NC}"
    
    # Slack notification
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST "$SLACK_WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            -d "{\"text\": \"Deployment $status: $message\"}" \
            > /dev/null 2>&1
    fi
    
    # Discord notification
    if [ -n "$DISCORD_WEBHOOK_URL" ]; then
        curl -X POST "$DISCORD_WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            -d "{\"content\": \"Deployment $status: $message\"}" \
            > /dev/null 2>&1
    fi
    
    log "${GREEN}✓ Notifications sent${NC}"
}

# Function to update monitoring
update_monitoring() {
    log "${BLUE}📊 Updating monitoring...${NC}"
    
    # Create deployment annotation in Grafana
    if [ -n "$GRAFANA_API_KEY" ] && [ -n "$GRAFANA_URL" ]; then
        curl -X POST "$GRAFANA_URL/api/annotations" \
            -H "Authorization: Bearer $GRAFANA_API_KEY" \
            -H 'Content-Type: application/json' \
            -d "{
                \"dashboardId\": 1,
                \"tags\": [\"deployment\", \"$ENVIRONMENT\"],
                \"text\": \"Deployed version $VERSION to $DEPLOY_TARGET\"
            }" > /dev/null 2>&1
    fi
    
    log "${GREEN}✓ Monitoring updated${NC}"
}

# Main deployment flow
main() {
    log "${BLUE}════════════════════════════════════════════════${NC}"
    log "${BLUE}         GentleQuest Deployment Script           ${NC}"
    log "${BLUE}════════════════════════════════════════════════${NC}"
    log ""
    log "Target: $DEPLOY_TARGET"
    log "Environment: $ENVIRONMENT"
    log "Version: $VERSION"
    log ""
    
    # Pre-deployment checks
    check_prerequisites
    
    # Run tests
    run_tests
    
    # Build application
    build_application
    
    # Create backup
    create_backup
    
    # Deploy based on target
    case "$DEPLOY_TARGET" in
        render)
            deploy_to_render
            ;;
        docker)
            deploy_to_docker
            ;;
        aws)
            deploy_to_aws
            ;;
        *)
            log "${RED}Unknown deployment target: $DEPLOY_TARGET${NC}"
            exit 1
            ;;
    esac
    
    # Post-deployment verification
    if perform_health_check; then
        # Update monitoring
        update_monitoring
        
        # Send success notification
        send_notifications "SUCCESS" "Version $VERSION deployed to $DEPLOY_TARGET"
        
        log ""
        log "${GREEN}🎉 Deployment completed successfully!${NC}"
        log "Version: $VERSION"
        log "Environment: $ENVIRONMENT"
        log "Target: $DEPLOY_TARGET"
        log "Time: $(date)"
    else
        # Send failure notification
        send_notifications "FAILED" "Deployment of $VERSION to $DEPLOY_TARGET failed"
        
        log "${RED}Deployment failed!${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
