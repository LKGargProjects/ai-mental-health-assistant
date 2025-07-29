#!/bin/bash

# =============================================================================
# AI MENTAL HEALTH ASSISTANT - LOCAL DEVELOPMENT STARTUP SCRIPT
# =============================================================================
# This script starts all services for local development
# Usage: ./start_local.sh [option]
# Options: docker, native, clean

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to kill processes on a port
kill_port() {
    local port=$1
    if check_port $port; then
        print_warning "Port $port is in use. Killing existing processes..."
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
}

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
}

# Function to check if .env file exists
check_env() {
    if [ ! -f .env ]; then
        print_warning ".env file not found. Creating from template..."
        if [ -f env.example ]; then
            cp env.example .env
            print_success "Created .env file from template"
        else
            print_error "env.example not found. Please create a .env file manually."
            exit 1
        fi
    fi
}

# Function to load environment variables
load_env() {
    if [ -f .env ]; then
        export $(cat .env | grep -v '^#' | xargs)
        print_success "Loaded environment variables from .env"
    fi
}

# Function to start services with Docker Compose
start_docker() {
    print_status "Starting services with Docker Compose..."
    
    check_docker
    check_env
    load_env
    
    # Kill any existing processes on our ports
    kill_port ${BACKEND_PORT:-5055}
    kill_port ${FLUTTER_WEB_PORT:-8080}
    kill_port ${POSTGRES_PORT:-5432}
    kill_port ${REDIS_PORT:-6379}
    
    # Start all services
    docker-compose up -d
    
    print_success "All services started with Docker Compose!"
    print_status "Services available at:"
    print_status "  Backend API: http://localhost:${BACKEND_PORT:-5055}"
    print_status "  Flutter Web: http://localhost:${FLUTTER_WEB_PORT:-8080}"
    print_status "  Database: localhost:${POSTGRES_PORT:-5432}"
    print_status "  Redis: localhost:${REDIS_PORT:-6379}"
    
    # Wait for services to be ready
    print_status "Waiting for services to be ready..."
    sleep 10
    
    # Test backend health
    if curl -s http://localhost:${BACKEND_PORT:-5055}/api/health >/dev/null; then
        print_success "Backend is healthy!"
    else
        print_warning "Backend health check failed. It may still be starting..."
    fi
}

# Function to start services natively (without Docker)
start_native() {
    print_status "Starting services natively..."
    
    check_env
    load_env
    
    # Kill any existing processes
    kill_port ${BACKEND_PORT:-5055}
    kill_port ${FLUTTER_WEB_PORT:-8080}
    
    # Start backend
    print_status "Starting backend on port ${BACKEND_PORT:-5055}..."
    PORT=${BACKEND_PORT:-5055} python3 app.py &
    BACKEND_PID=$!
    
    # Wait for backend to start
    sleep 5
    
    # Test backend
    if curl -s http://localhost:${BACKEND_PORT:-5055}/api/health >/dev/null; then
        print_success "Backend started successfully!"
    else
        print_error "Backend failed to start"
        exit 1
    fi
    
    # Start Flutter web (if Flutter is available)
    if command -v flutter >/dev/null 2>&1; then
        print_status "Starting Flutter web on port ${FLUTTER_WEB_PORT:-8080}..."
        cd ai_buddy_web
        flutter run -d chrome --web-port=${FLUTTER_WEB_PORT:-8080} &
        FLUTTER_PID=$!
        cd ..
        print_success "Flutter web started!"
    else
        print_warning "Flutter not found. Skipping Flutter web startup."
    fi
    
    print_success "Native services started!"
    print_status "Services available at:"
    print_status "  Backend API: http://localhost:${BACKEND_PORT:-5055}"
    if [ ! -z "$FLUTTER_PID" ]; then
        print_status "  Flutter Web: http://localhost:${FLUTTER_WEB_PORT:-8080}"
    fi
    
    # Save PIDs for cleanup
    echo $BACKEND_PID > .backend.pid
    if [ ! -z "$FLUTTER_PID" ]; then
        echo $FLUTTER_PID > .flutter.pid
    fi
}

# Function to clean up
cleanup() {
    print_status "Cleaning up..."
    
    # Stop Docker services
    if [ -f docker-compose.yml ]; then
        docker-compose down
        print_success "Docker services stopped"
    fi
    
    # Kill native processes
    if [ -f .backend.pid ]; then
        kill $(cat .backend.pid) 2>/dev/null || true
        rm .backend.pid
    fi
    
    if [ -f .flutter.pid ]; then
        kill $(cat .flutter.pid) 2>/dev/null || true
        rm .flutter.pid
    fi
    
    # Kill processes on our ports
    kill_port ${BACKEND_PORT:-5055}
    kill_port ${FLUTTER_WEB_PORT:-8080}
    kill_port ${POSTGRES_PORT:-5432}
    kill_port ${REDIS_PORT:-6379}
    
    print_success "Cleanup completed!"
}

# Function to show status
show_status() {
    print_status "Service Status:"
    
    if check_port ${BACKEND_PORT:-5055}; then
        print_success "Backend: Running on port ${BACKEND_PORT:-5055}"
    else
        print_error "Backend: Not running"
    fi
    
    if check_port ${FLUTTER_WEB_PORT:-8080}; then
        print_success "Flutter Web: Running on port ${FLUTTER_WEB_PORT:-8080}"
    else
        print_error "Flutter Web: Not running"
    fi
    
    if check_port ${POSTGRES_PORT:-5432}; then
        print_success "Database: Running on port ${POSTGRES_PORT:-5432}"
    else
        print_error "Database: Not running"
    fi
    
    if check_port ${REDIS_PORT:-6379}; then
        print_success "Redis: Running on port ${REDIS_PORT:-6379}"
    else
        print_error "Redis: Not running"
    fi
}

# Main script logic
case "${1:-docker}" in
    "docker")
        start_docker
        ;;
    "native")
        start_native
        ;;
    "clean")
        cleanup
        ;;
    "status")
        show_status
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [option]"
        echo "Options:"
        echo "  docker  - Start services with Docker Compose (default)"
        echo "  native  - Start services natively (requires local Python/Flutter)"
        echo "  clean   - Stop all services and cleanup"
        echo "  status  - Show status of all services"
        echo "  help    - Show this help message"
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac 