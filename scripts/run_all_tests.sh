#!/bin/bash
#
# Comprehensive Testing Script for GentleQuest
# Runs all tests: unit, integration, performance, security
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Configuration
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENV_PATH="$PROJECT_ROOT/venv"
FLUTTER_DIR="$PROJECT_ROOT/ai_buddy_web"
TEST_REPORTS="$PROJECT_ROOT/test_reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create test reports directory
mkdir -p "$TEST_REPORTS"

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}       GentleQuest Comprehensive Test Suite              ${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo

# Function to run a test and track results
run_test() {
    local test_name=$1
    local test_command=$2
    
    echo -e "${YELLOW}Running: $test_name${NC}"
    
    if eval "$test_command" > "$TEST_REPORTS/${test_name// /_}_$TIMESTAMP.log" 2>&1; then
        echo -e "${GREEN}✓ $test_name passed${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ $test_name failed${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to check dependencies
check_dependencies() {
    echo -e "${BLUE}Checking dependencies...${NC}"
    
    local deps_ok=true
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}✗ Python 3 not found${NC}"
        deps_ok=false
    else
        echo -e "${GREEN}✓ Python 3 found${NC}"
    fi
    
    # Check Flutter
    if ! command -v flutter &> /dev/null; then
        echo -e "${YELLOW}⚠ Flutter not found (skipping Flutter tests)${NC}"
        ((TESTS_SKIPPED++))
    else
        echo -e "${GREEN}✓ Flutter found${NC}"
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}⚠ Docker not found (skipping container tests)${NC}"
        ((TESTS_SKIPPED++))
    else
        echo -e "${GREEN}✓ Docker found${NC}"
    fi
    
    # Check PostgreSQL client
    if ! command -v psql &> /dev/null; then
        echo -e "${YELLOW}⚠ PostgreSQL client not found (skipping DB tests)${NC}"
        ((TESTS_SKIPPED++))
    else
        echo -e "${GREEN}✓ PostgreSQL client found${NC}"
    fi
    
    if [ "$deps_ok" = false ]; then
        echo -e "${RED}Missing required dependencies. Exiting.${NC}"
        exit 1
    fi
    
    echo
}

# Function to setup test environment
setup_test_env() {
    echo -e "${BLUE}Setting up test environment...${NC}"
    
    # Create virtual environment if not exists
    if [ ! -d "$VENV_PATH" ]; then
        python3 -m venv "$VENV_PATH"
    fi
    
    # Activate virtual environment
    source "$VENV_PATH/bin/activate"
    
    # Install dependencies
    pip install -q --upgrade pip
    pip install -q -r "$PROJECT_ROOT/requirements.txt"
    pip install -q pytest pytest-cov pytest-asyncio pytest-mock pytest-timeout
    pip install -q black flake8 mypy safety bandit
    pip install -q locust selenium
    
    echo -e "${GREEN}✓ Test environment ready${NC}"
    echo
}

# Function to run Python unit tests
run_python_unit_tests() {
    echo -e "${BLUE}═══ Python Unit Tests ═══${NC}"
    
    cd "$PROJECT_ROOT"
    
    # Run pytest with coverage
    run_test "Python Unit Tests" \
        "python -m pytest tests/ -v --cov=. --cov-report=html --cov-report=term --junit-xml=$TEST_REPORTS/pytest_junit.xml"
    
    # Run specific test categories
    run_test "Crisis Detection Tests" \
        "python -m pytest tests/test_app.py::TestCrisisDetection -v"
    
    run_test "Session Management Tests" \
        "python -m pytest tests/test_app.py::TestSessionManagement -v"
    
    run_test "API Endpoint Tests" \
        "python -m pytest tests/test_app.py::TestHealthEndpoints -v"
    
    echo
}

# Function to run Python linting and static analysis
run_python_static_analysis() {
    echo -e "${BLUE}═══ Python Static Analysis ═══${NC}"
    
    cd "$PROJECT_ROOT"
    
    # Black formatting check
    run_test "Black Format Check" \
        "black --check app.py models.py crisis_detection.py community.py"
    
    # Flake8 linting
    run_test "Flake8 Linting" \
        "flake8 app.py models.py crisis_detection.py --max-line-length=127 --max-complexity=10"
    
    # Type checking with mypy
    run_test "MyPy Type Checking" \
        "mypy app.py models.py --ignore-missing-imports"
    
    echo
}

# Function to run security tests
run_security_tests() {
    echo -e "${BLUE}═══ Security Tests ═══${NC}"
    
    cd "$PROJECT_ROOT"
    
    # Bandit security scan
    run_test "Bandit Security Scan" \
        "bandit -r app.py models.py crisis_detection.py -f json -o $TEST_REPORTS/bandit_report.json"
    
    # Safety check for dependencies
    run_test "Safety Dependency Check" \
        "safety check --json --output $TEST_REPORTS/safety_report.json"
    
    # SQL injection tests
    run_test "SQL Injection Tests" \
        "python -m pytest tests/test_app.py::TestSecurity::test_sql_injection_protection -v"
    
    # XSS protection tests
    run_test "XSS Protection Tests" \
        "python -m pytest tests/test_app.py::TestSecurity::test_xss_protection -v"
    
    echo
}

# Function to run integration tests
run_integration_tests() {
    echo -e "${BLUE}═══ Integration Tests ═══${NC}"
    
    cd "$PROJECT_ROOT"
    
    # Start test database
    if command -v docker &> /dev/null; then
        echo "Starting test database..."
        docker run -d --name test_postgres \
            -e POSTGRES_DB=test_db \
            -e POSTGRES_USER=test_user \
            -e POSTGRES_PASSWORD=test_pass \
            -p 5433:5432 \
            postgres:15-alpine > /dev/null 2>&1 || true
        
        # Wait for database
        sleep 5
        
        # Run integration tests
        TEST_DATABASE_URL="postgresql://test_user:test_pass@localhost:5433/test_db" \
        run_test "Integration Tests" \
            "python -m pytest tests/test_app.py::TestIntegration -v"
        
        # Stop test database
        docker stop test_postgres > /dev/null 2>&1 || true
        docker rm test_postgres > /dev/null 2>&1 || true
    else
        echo -e "${YELLOW}⚠ Skipping integration tests (Docker not available)${NC}"
        ((TESTS_SKIPPED++))
    fi
    
    echo
}

# Function to run Flutter tests
run_flutter_tests() {
    echo -e "${BLUE}═══ Flutter Tests ═══${NC}"
    
    if command -v flutter &> /dev/null; then
        cd "$FLUTTER_DIR"
        
        # Get dependencies
        flutter pub get > /dev/null 2>&1
        
        # Run Flutter analyze
        run_test "Flutter Analyze" \
            "flutter analyze --no-fatal-infos"
        
        # Run Flutter tests
        run_test "Flutter Unit Tests" \
            "flutter test --coverage"
        
        # Check for unused dependencies
        run_test "Flutter Dependency Check" \
            "flutter pub deps"
    else
        echo -e "${YELLOW}⚠ Flutter not found, skipping Flutter tests${NC}"
        ((TESTS_SKIPPED+=3))
    fi
    
    echo
}

# Function to run performance tests
run_performance_tests() {
    echo -e "${BLUE}═══ Performance Tests ═══${NC}"
    
    cd "$PROJECT_ROOT"
    
    # Create performance test script
    cat > "$TEST_REPORTS/locustfile.py" << 'EOF'
from locust import HttpUser, task, between

class GentleQuestUser(HttpUser):
    wait_time = between(1, 3)
    
    def on_start(self):
        response = self.client.get("/api/get_or_create_session")
        self.session_id = response.json()["session_id"]
    
    @task(3)
    def health_check(self):
        self.client.get("/api/health")
    
    @task(2)
    def ping(self):
        self.client.get("/api/ping")
    
    @task(1)
    def chat(self):
        self.client.post("/api/chat",
            json={"message": "Hello"},
            headers={"X-Session-ID": self.session_id})
EOF
    
    # Run locust performance test (headless)
    if command -v locust &> /dev/null; then
        echo "Running performance tests (10 seconds)..."
        run_test "Performance Test" \
            "locust -f $TEST_REPORTS/locustfile.py --headless --users 10 --spawn-rate 2 --run-time 10s --host http://localhost:5055 --html $TEST_REPORTS/performance_report.html"
    else
        echo -e "${YELLOW}⚠ Locust not found, skipping performance tests${NC}"
        ((TESTS_SKIPPED++))
    fi
    
    echo
}

# Function to run API tests
run_api_tests() {
    echo -e "${BLUE}═══ API Tests ═══${NC}"
    
    cd "$PROJECT_ROOT"
    
    # Start the application in test mode
    echo "Starting test server..."
    ENVIRONMENT=test python app.py > /dev/null 2>&1 &
    APP_PID=$!
    
    # Wait for server to start
    sleep 5
    
    # Run API tests
    if curl -s http://localhost:5055/api/health > /dev/null; then
        echo -e "${GREEN}✓ Test server started${NC}"
        
        # Health endpoint test
        run_test "Health Endpoint Test" \
            "curl -s http://localhost:5055/api/health | grep -q 'healthy'"
        
        # Ping endpoint test
        run_test "Ping Endpoint Test" \
            "curl -s http://localhost:5055/api/ping | grep -q 'ok'"
        
        # Rate limiting test
        run_test "Rate Limiting Test" \
            "for i in {1..35}; do curl -s -X POST http://localhost:5055/api/chat -H 'Content-Type: application/json' -d '{\"message\":\"test\"}'; done | grep -q '429'"
        
    else
        echo -e "${RED}✗ Test server failed to start${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Stop test server
    kill $APP_PID 2> /dev/null || true
    
    echo
}

# Function to run database tests
run_database_tests() {
    echo -e "${BLUE}═══ Database Tests ═══${NC}"
    
    if command -v psql &> /dev/null; then
        # Test database migrations
        run_test "Database Migration Test" \
            "python -c 'from app import create_app; from models import db; app = create_app(); app.app_context().push(); db.create_all()'"
        
        # Test backup script
        if [ -f "$PROJECT_ROOT/scripts/backup_database.py" ]; then
            run_test "Database Backup Script Test" \
                "python $PROJECT_ROOT/scripts/backup_database.py status"
        fi
    else
        echo -e "${YELLOW}⚠ PostgreSQL client not found, skipping database tests${NC}"
        ((TESTS_SKIPPED+=2))
    fi
    
    echo
}

# Function to generate test report
generate_report() {
    echo -e "${BLUE}═══ Test Report ═══${NC}"
    
    local total_tests=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    local pass_rate=0
    
    if [ $total_tests -gt 0 ]; then
        pass_rate=$(echo "scale=2; $TESTS_PASSED * 100 / ($TESTS_PASSED + $TESTS_FAILED)" | bc)
    fi
    
    cat > "$TEST_REPORTS/summary_$TIMESTAMP.txt" << EOF
GentleQuest Test Report
========================
Timestamp: $(date)
Total Tests: $total_tests
Passed: $TESTS_PASSED
Failed: $TESTS_FAILED
Skipped: $TESTS_SKIPPED
Pass Rate: $pass_rate%

Test Categories:
- Unit Tests
- Integration Tests
- Security Tests
- Performance Tests
- Flutter Tests
- API Tests
- Database Tests

Test Artifacts:
$(ls -la "$TEST_REPORTS"/*_$TIMESTAMP* 2>/dev/null | wc -l) files generated

Report Location: $TEST_REPORTS/
EOF
    
    echo "Total Tests: $total_tests"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
    echo "Pass Rate: $pass_rate%"
    echo
    echo "Detailed reports saved to: $TEST_REPORTS/"
    
    # Exit with appropriate code
    if [ $TESTS_FAILED -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Main execution
main() {
    # Check dependencies
    check_dependencies
    
    # Setup test environment
    setup_test_env
    
    # Run all test suites
    run_python_unit_tests
    run_python_static_analysis
    run_security_tests
    run_integration_tests
    run_flutter_tests
    run_performance_tests
    run_api_tests
    run_database_tests
    
    # Generate final report
    generate_report
}

# Handle interrupts
trap 'echo -e "\n${RED}Tests interrupted${NC}"; generate_report' INT TERM

# Run main function
main "$@"
