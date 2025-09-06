#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

echo "🔧 Installing Git hooks..."
echo ""

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    print_error "Not in a git repository. Please run this from the project root."
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p .git/hooks

# Install pre-commit hook
print_status "Installing pre-commit hook..."

cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

set -e

echo "🔍 Running pre-commit checks..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "mix.exs" ]; then
    print_error "mix.exs not found. Are you in the project root?"
    exit 1
fi

# Check if we have staged changes
if git diff --staged --quiet; then
    print_warning "No staged changes found. Skipping pre-commit hooks."
    exit 0
fi

echo "=================================================="
print_status "1/5 Checking Elixir formatting..."
echo "=================================================="

if ! mix format --check-formatted; then
    print_error "Elixir code is not properly formatted!"
    echo ""
    print_status "Run 'mix format' to fix formatting issues."
    exit 1
fi
print_success "Elixir formatting check passed"
echo ""

echo "=================================================="
print_status "2/5 Checking Rust formatting..."
echo "=================================================="

cd native/ex_jsonschema
if ! cargo fmt --all -- --check; then
    print_error "Rust code is not properly formatted!"
    echo ""
    print_status "Run 'cd native/ex_jsonschema && cargo fmt --all' to fix formatting issues."
    exit 1
fi
print_success "Rust formatting check passed"
cd ../..
echo ""

echo "=================================================="
print_status "3/5 Running Rust clippy checks..."
echo "=================================================="

cd native/ex_jsonschema
if ! cargo clippy -- -D warnings; then
    print_error "Rust clippy checks failed!"
    echo ""
    print_status "Fix the clippy warnings above before committing."
    exit 1
fi
print_success "Rust clippy checks passed"
cd ../..
echo ""

echo "=================================================="
print_status "4/5 Running Elixir tests..."
echo "=================================================="

if ! mix test; then
    print_error "Elixir tests failed!"
    echo ""
    print_status "Fix the failing tests before committing."
    exit 1
fi
print_success "Elixir tests passed"
echo ""

echo "=================================================="
print_status "5/5 Running additional checks..."
echo "=================================================="

# Check for compile warnings
print_status "Checking for compile warnings..."
if ! mix compile --warnings-as-errors; then
    print_error "Compilation warnings found!"
    echo ""
    print_status "Fix compilation warnings before committing."
    exit 1
fi
print_success "No compilation warnings found"

# Check for unused dependencies (optional - can be slow)
if command -v mix_audit &> /dev/null; then
    print_status "Running security audit..."
    if ! mix deps.audit; then
        print_warning "Security audit found issues - review and fix if necessary"
    else
        print_success "Security audit passed"
    fi
fi

echo ""
echo "=================================================="
print_success "All pre-commit checks passed! 🎉"
echo "=================================================="
echo ""
EOF

# Make the hook executable
chmod +x .git/hooks/pre-commit

print_success "Pre-commit hook installed successfully!"
echo ""
print_status "The hook will now run automatically before each commit and check:"
echo "  • Elixir code formatting (mix format)"
echo "  • Rust code formatting (cargo fmt)"
echo "  • Rust clippy warnings (cargo clippy)"
echo "  • Elixir tests (mix test)"
echo "  • Compilation warnings"
echo ""
print_status "To skip the hook for emergency commits, use: git commit --no-verify"
echo ""