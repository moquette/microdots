#!/usr/bin/env bash
#
# Test script to verify CLAUDE.md documentation requirements
# This simulates what an AI agent should do when initialized

# Don't exit on error - we want to run all tests
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

test_case() {
    echo -e "\n${BLUE}▶ Testing:${NC} $1"
    ((TESTS_RUN++))
}

print_header() {
    echo -e "\n${BLUE}══════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}"
}

# Main test suite
print_header "CLAUDE.md Documentation Compliance Tests"

# Test 1: Verify all required documentation files exist
test_case "Required documentation files exist"
REQUIRED_DOCS=(
    "CLAUDE.md"
    "MICRODOTS.md"
    "README.md"
    "docs/IMPLEMENTATION.md"
    "docs/COMPLIANCE.md"
    "docs/LOCAL_OVERRIDES.md"
    "docs/UI_STYLE_GUIDE.md"
)

ALL_DOCS_EXIST=true
for doc in "${REQUIRED_DOCS[@]}"; do
    if [[ -f "$HOME/.dotfiles/$doc" ]]; then
        pass "Found: $doc"
    else
        fail "Missing: $doc"
        ALL_DOCS_EXIST=false
    fi
done

# Test 2: Verify CLAUDE.md contains mandatory reading section
test_case "CLAUDE.md contains mandatory reading requirements"
if grep -q "MANDATORY READING REQUIREMENTS" "$HOME/.dotfiles/CLAUDE.md"; then
    pass "Mandatory reading section found"
else
    fail "Mandatory reading section missing"
fi

# Test 3: Verify confirmation checklist is defined
test_case "Confirmation checklist requirement"
if grep -q "Documentation Initialized:" "$HOME/.dotfiles/CLAUDE.md"; then
    pass "Confirmation checklist found"
    
    # Check for specific checklist items
    CHECKLIST_ITEMS=(
        "~/.claude/README.md - Global configuration loaded"
        "~/.claude/PROTOCOL.md - Autonomous execution protocol internalized"
        "MICRODOTS.md - Architecture guide understood"
        "docs/IMPLEMENTATION.md - Technical details reviewed"
        "docs/COMPLIANCE.md - Compliance standards acknowledged"
        "docs/LOCAL_OVERRIDES.md - Dotlocal system understood"
        "docs/UI_STYLE_GUIDE.md - UI standards loaded"
    )
    
    for item in "${CHECKLIST_ITEMS[@]}"; do
        if grep -q "$item" "$HOME/.dotfiles/CLAUDE.md"; then
            pass "  ✓ Checklist item: $item"
        else
            fail "  ✗ Missing checklist item: $item"
        fi
    done
else
    fail "Confirmation checklist missing"
fi

# Test 4: Verify all docs are referenced in CLAUDE.md
test_case "All documentation files are referenced"
for doc in "${REQUIRED_DOCS[@]}"; do
    if [[ "$doc" == "CLAUDE.md" ]]; then
        continue  # Skip self-reference
    fi
    
    # Check if the document is referenced (handle both @docs/ and docs/ formats)
    doc_name=$(basename "$doc")
    if grep -q "$doc" "$HOME/.dotfiles/CLAUDE.md" || grep -q "@$doc" "$HOME/.dotfiles/CLAUDE.md"; then
        pass "Referenced: $doc"
    else
        fail "Not referenced: $doc"
    fi
done

# Test 5: Verify documentation structure section exists
test_case "Documentation Structure section"
if grep -q "Documentation Structure" "$HOME/.dotfiles/CLAUDE.md"; then
    pass "Documentation Structure section found"
else
    fail "Documentation Structure section missing"
fi

# Test 6: Simulate AI initialization (demonstration)
test_case "AI Agent initialization simulation"
echo -e "\n${BLUE}This is what an AI agent should output when initialized:${NC}\n"
cat << 'EOF'
✅ Documentation Initialized:
- [x] ~/.claude/README.md - Global configuration loaded
- [x] ~/.claude/PROTOCOL.md - Autonomous execution protocol internalized
- [x] MICRODOTS.md - Architecture guide understood
- [x] docs/IMPLEMENTATION.md - Technical details reviewed
- [x] docs/COMPLIANCE.md - Compliance standards acknowledged
- [x] docs/LOCAL_OVERRIDES.md - Dotlocal system understood
- [x] docs/UI_STYLE_GUIDE.md - UI standards loaded
EOF
echo ""
pass "Demonstration of expected output shown"

# Test 7: Verify documentation is accessible via symlinks
test_case "Documentation accessibility via dotlocal"
DOTLOCAL_PATH="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Dotfiles/dotlocal"

if [[ -L "$DOTLOCAL_PATH/CLAUDE.md" ]]; then
    TARGET=$(readlink "$DOTLOCAL_PATH/CLAUDE.md")
    if [[ "$TARGET" == *"/.dotfiles/CLAUDE.md" ]]; then
        pass "CLAUDE.md symlink points to correct location"
    else
        fail "CLAUDE.md symlink points to wrong location: $TARGET"
    fi
else
    warning "No dotlocal symlink found (check if dotlocal is set up)"
fi

if [[ -L "$DOTLOCAL_PATH/docs" ]]; then
    pass "docs/ directory is symlinked from dotlocal"
else
    warning "No docs/ symlink in dotlocal (check if dotlocal is set up)"
fi

# Test 8: Practical test - Check if reading the docs provides necessary context
test_case "Documentation provides complete context"
echo -e "\n${BLUE}Checking if documentation covers key topics:${NC}"

KEY_TOPICS=(
    "Microdots architecture"
    "Four-stage loading"
    "Topic independence"
    "Installation"
    "Testing"
    "Troubleshooting"
)

for topic in "${KEY_TOPICS[@]}"; do
    if grep -qi "$topic" "$HOME/.dotfiles/MICRODOTS.md" || \
       grep -qi "$topic" "$HOME/.dotfiles/docs/IMPLEMENTATION.md"; then
        pass "Topic covered: $topic"
    else
        warning "Topic might be missing: $topic"
    fi
done

# Summary
print_header "Test Summary"
echo -e "Tests run:    ${TESTS_RUN}"
echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}"
    echo -e "\nThe CLAUDE.md documentation requirements are properly configured."
    echo -e "AI agents will be required to read and acknowledge all documentation."
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed.${NC}"
    echo -e "Please review the failures above and update the documentation."
    exit 1
fi