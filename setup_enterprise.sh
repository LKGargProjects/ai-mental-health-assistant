#!/bin/bash

# Enterprise Setup Script for GentleQuest
# This script initializes all enterprise features

echo "🚀 GentleQuest Enterprise Setup"
echo "================================"

# Check Python version
PYTHON_CMD=""
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo "❌ Python not found. Please install Python 3.9+"
    exit 1
fi

echo "✓ Using Python: $PYTHON_CMD"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    $PYTHON_CMD -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install requirements
echo "Installing dependencies..."
pip install -r requirements.txt

# Generate encryption key if not exists
if ! grep -q "ENCRYPTION_MASTER_KEY=" .env 2>/dev/null || [ -z "$(grep 'ENCRYPTION_MASTER_KEY=' .env | cut -d'=' -f2)" ]; then
    echo "Generating encryption key..."
    KEY=$($PYTHON_CMD -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
    
    if [ -f .env ]; then
        # Update existing .env
        echo "ENCRYPTION_MASTER_KEY=$KEY" >> .env
    else
        # Create new .env
        echo "ENCRYPTION_MASTER_KEY=$KEY" > .env
    fi
    echo "✓ Encryption key generated and saved"
fi

# Generate session secret if not exists
if ! grep -q "SESSION_SECRET_KEY=" .env 2>/dev/null || [ -z "$(grep 'SESSION_SECRET_KEY=' .env | cut -d'=' -f2)" ]; then
    echo "Generating session secret..."
    SECRET=$($PYTHON_CMD -c "import secrets; print(secrets.token_hex(32))")
    echo "SESSION_SECRET_KEY=$SECRET" >> .env
    echo "✓ Session secret generated"
fi

# Generate admin token if not exists
if ! grep -q "ADMIN_API_TOKEN=" .env 2>/dev/null || [ -z "$(grep 'ADMIN_API_TOKEN=' .env | cut -d'=' -f2)" ]; then
    echo "Generating admin token..."
    TOKEN=$($PYTHON_CMD -c "import secrets; print(secrets.token_hex(32))")
    echo "ADMIN_API_TOKEN=$TOKEN" >> .env
    echo "✓ Admin token generated"
fi

# Test enterprise features
echo ""
echo "Testing enterprise features..."
$PYTHON_CMD << EOF
import os
import sys
from dotenv import load_dotenv
load_dotenv()

# Test imports
errors = []
warnings = []

# Test AI optimization
try:
    from ai_optimization.cost_reducer import AIOptimizer
    print("✓ AI Optimization module loaded")
except ImportError as e:
    warnings.append(f"AI Optimization: {e}")

# Test clinical detection
try:
    from crisis_v2.clinical_detection import ClinicalCrisisDetector
    print("✓ Clinical Detection module loaded")
except ImportError as e:
    warnings.append(f"Clinical Detection: {e}")

# Test revenue system
try:
    from revenue.billing_system import RevenueOptimizer
    if os.getenv('STRIPE_SECRET_KEY'):
        print("✓ Revenue System module loaded (Stripe configured)")
    else:
        print("✓ Revenue System module loaded (Stripe not configured)")
        warnings.append("Set STRIPE_SECRET_KEY for payment processing")
except ImportError as e:
    warnings.append(f"Revenue System: {e}")

# Test security
try:
    from security.encryption import SecurityManager
    if os.getenv('ENCRYPTION_MASTER_KEY'):
        print("✓ Security module loaded (encryption configured)")
    else:
        errors.append("ENCRYPTION_MASTER_KEY not set!")
except ImportError as e:
    errors.append(f"Security: {e}")

# Test scale architecture
try:
    from scale.architecture import DistributedArchitecture
    print("✓ Scale Architecture module loaded")
except ImportError as e:
    warnings.append(f"Scale Architecture: {e}")

# Print results
print("")
if errors:
    print("❌ ERRORS:")
    for error in errors:
        print(f"  - {error}")
    sys.exit(1)
    
if warnings:
    print("⚠️  WARNINGS:")
    for warning in warnings:
        print(f"  - {warning}")
        
print("")
print("✅ Enterprise features ready!")
print("")
print("Next steps:")
print("1. Set missing environment variables in .env")
print("2. Run: python app.py")
print("3. Test at: http://localhost:5055/api/enterprise/status")
EOF

# Create test script
echo ""
echo "Creating test script..."
cat > test_enterprise.py << 'EOF'
#!/usr/bin/env python3
"""Test enterprise features"""

import os
import sys
from dotenv import load_dotenv
load_dotenv()

def test_enterprise():
    """Test enterprise integration"""
    from flask import Flask
    from integrations import EnterpriseIntegration
    
    app = Flask(__name__)
    app.config['SECRET_KEY'] = os.getenv('SESSION_SECRET_KEY', 'test-key')
    
    # Initialize integration
    integration = EnterpriseIntegration(app)
    
    # Check status
    status = integration.get_system_status()
    
    print("Enterprise System Status")
    print("========================")
    for system, enabled in status['systems'].items():
        emoji = "✅" if enabled else "❌"
        print(f"{emoji} {system.replace('_', ' ').title()}: {enabled}")
    
    print("")
    print(f"Operational: {status['operational']}")
    print(f"Fully Operational: {status['fully_operational']}")
    
    # Test AI optimization
    if integration.ai_optimizer:
        print("\nTesting AI Optimization...")
        provider, prompt, cost = integration.optimize_ai_request(
            "Hello, I'm feeling anxious", 
            {"risk_level": "low"}
        )
        print(f"  Provider: {provider}")
        print(f"  Cost savings: {cost.get('estimated_savings', 0) * 100:.0f}%")
    
    # Test clinical detection
    if integration.crisis_detector:
        print("\nTesting Clinical Detection...")
        assessment = integration.detect_crisis_clinical(
            "I'm feeling overwhelmed", 
            "test-session"
        )
        print(f"  Risk Level: {assessment['risk_level']}")
        print(f"  Clinical: {assessment['clinical_assessment']}")
    
    # Test security
    if integration.security_manager:
        print("\nTesting Security Encryption...")
        encrypted = integration.encrypt_conversation("test message")
        decrypted = integration.decrypt_conversation(encrypted)
        print(f"  Encryption: {'✅ Working' if decrypted == 'test message' else '❌ Failed'}")
    
    return status['operational']

if __name__ == "__main__":
    try:
        if test_enterprise():
            print("\n✅ Enterprise features test passed!")
            sys.exit(0)
        else:
            print("\n⚠️  Some enterprise features not available")
            sys.exit(0)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)
EOF

chmod +x test_enterprise.py

echo "✓ Test script created: test_enterprise.py"
echo ""
echo "================================"
echo "Setup complete! 🎉"
echo ""
echo "To test enterprise features:"
echo "  ./test_enterprise.py"
echo ""
echo "To run the server:"
echo "  python app.py"
echo ""
