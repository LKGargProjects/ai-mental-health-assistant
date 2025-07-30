#!/bin/bash

# AI Mental Health Assistant - Quick Reload Script
# For efficient development without full rebuilds

echo "🔄 AI Mental Health Assistant - Quick Reload"
echo "==========================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to reload backend only
reload_backend() {
    print_info "Reloading backend service..."
    docker-compose restart backend
    sleep 3
    if curl -s http://localhost:5055/api/health | grep -q "healthy"; then
        print_success "Backend reloaded successfully"
    else
        print_warning "Backend may need more time to start"
    fi
}

# Function to reload frontend only
reload_frontend() {
    print_info "Rebuilding Flutter web app..."
    cd ai_buddy_web
    flutter build web
    cd ..
    
    print_info "Copying built files to static folder..."
    cp -r ai_buddy_web/build/web/* static/
    
    print_info "Restarting frontend service..."
    docker-compose restart flutter-web
    sleep 2
    
    if curl -s http://localhost:8080 | grep -q "html"; then
        print_success "Frontend reloaded successfully"
    else
        print_warning "Frontend may need more time to start"
    fi
}

# Function to reload everything
reload_all() {
    print_info "Performing full reload..."
    docker-compose down
    docker-compose up -d
    sleep 5
    
    if curl -s http://localhost:5055/api/health | grep -q "healthy"; then
        print_success "Full reload completed successfully"
    else
        print_warning "Services may need more time to start"
    fi
}

# Function to clear browser cache hint
clear_cache_hint() {
    echo ""
    print_warning "Browser Cache Management:"
    echo "  • Chrome/Edge: Ctrl+Shift+R (hard refresh)"
    echo "  • Firefox: Ctrl+F5 (hard refresh)"
    echo "  • Safari: Cmd+Option+R (hard refresh)"
    echo "  • Or open in incognito/private mode"
}

# Main script logic
case "${1:-all}" in
    "backend")
        reload_backend
        ;;
    "frontend")
        reload_frontend
        ;;
    "all")
        reload_all
        ;;
    "test")
        ./test_complete_system.sh
        ;;
    "cache")
        clear_cache_hint
        ;;
    *)
        echo "Usage: $0 [backend|frontend|all|test|cache]"
        echo ""
        echo "Commands:"
        echo "  backend  - Reload only backend service"
        echo "  frontend - Rebuild Flutter app and reload frontend"
        echo "  all      - Full reload of all services (default)"
        echo "  test     - Run complete system test"
        echo "  cache    - Show browser cache management tips"
        echo ""
        echo "Examples:"
        echo "  $0 backend   # Quick backend restart"
        echo "  $0 frontend  # Rebuild and reload frontend"
        echo "  $0 test      # Verify everything works"
        ;;
esac

echo ""
print_info "Quick Reload Complete!"
echo "🌐 Open http://localhost:8080 to test the application" 