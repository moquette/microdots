# UI Test Suite

Comprehensive test suite for the unified dotfiles UI system. These tests validate that all commands use consistent UI functions and formatting.

## What We Test

### Critical Requirements Validated

1. **No Raw Echo Statements**: All commands must use UI functions instead of raw `echo` statements
2. **Consistent Symbols**: All commands use the same symbols (  ! : ó)  
3. **No Extra Spaces**: UI function calls don't have extra spaces in messages
4. **Header Hierarchy**: Proper use of `header()` vs `subheader()`
5. **Error Routing**: Error messages go to stderr correctly
6. **Color Handling**: Terminal capability detection and color usage
7. **Cross-Command Consistency**: All commands produce uniform output

### The "Extra Space Bug" Fix

One major issue we fixed was commands calling UI functions with extra spaces:

```bash
# BAD - extra spaces get added to output
success "  Configuration complete"    # Shows:    Configuration complete

# GOOD - UI function handles spacing
success "Configuration complete"      # Shows:  Configuration complete
```

The tests specifically check for this pattern and flag it as an error.

## Test Structure

### 1. UI Function Unit Tests (`test_ui_functions.sh`)

Tests individual UI library functions:
- `success()` produces  symbol and correct format
- `error()` routes to stderr with  symbol  
- `warning()` uses ! symbol
- `info()` uses : symbol
- `header()` includes separator line
- `subheader()` has no separator line
- Color variables are set correctly
- Symbol consistency across function calls

### 2. UI Consistency Tests (`test_ui_consistency.sh`)

Analyzes source code for consistency violations:
- Searches for raw echo statements with UI symbols
- Detects mixed symbol usage ( vs , etc.)
- Finds extra spaces in UI function calls
- Validates header hierarchy usage
- Checks for missing UI library imports
- Tests actual command stderr routing

### 3. Command Integration Tests (`test_command_integration.sh`)

Tests actual command output:
- Help command consistency
- Status command structure  
- Relink dry-run validation
- Error handling across commands
- Symbol consistency between commands
- Header hierarchy in real output
- Color output validation
- Message formatting consistency

## Running Tests

### Quick Test (Recommended)
```bash
./tests/ui/run_ui_tests.sh --quick
```

### Full Test Suite
```bash
./tests/ui/run_ui_tests.sh
```

### Verbose Output
```bash
./tests/ui/run_ui_tests.sh --verbose
```

### Individual Test Suites
```bash
# Test UI functions only
./tests/ui/test_ui_functions.sh

# Test source code consistency
./tests/ui/test_ui_consistency.sh

# Test command integration
./tests/ui/test_command_integration.sh
```

## Expected Results

When all tests pass, you'll see:
```
<‰ ALL UI TESTS PASSED!

Your unified UI system is working correctly:
   All commands use UI functions consistently
   Symbols are uniform across all commands  
   No extra spaces in messages
   Proper header hierarchy
   Errors route to stderr correctly
   Cross-command consistency maintained

The UI overhaul is complete and validated! =€
```

## Common Failures and Fixes

### Raw Echo Statements
**Problem**: Commands still use `echo " Success"` instead of `success "Success"`

**Fix**: Replace with UI function calls:
```bash
# Replace this:
echo " Configuration complete"

# With this:
success "Configuration complete"
```

### Extra Spaces in Messages
**Problem**: UI functions called with extra spaces

**Fix**: Remove spaces from the message string:
```bash
# Replace this:
success "  No issues detected"

# With this:
success "No issues detected"
```

### Inconsistent Symbols
**Problem**: Mixed use of  vs  or ! vs  

**Fix**: Let UI library handle symbols - just use the functions

### Header Overuse
**Problem**: Too many `header()` calls creating excessive separator lines

**Fix**: Use `header()` once per command, `subheader()` for sections

## Architecture

The UI system is built with these principles:

1. **Single Source of Truth**: All UI formatting in `/core/lib/ui.sh`
2. **Terminal Capability Detection**: Automatic Unicode vs ASCII fallback
3. **Consistent Color Usage**: Standardized color variables
4. **Proper Error Routing**: Errors automatically go to stderr
5. **Extensible Design**: Easy to add new UI functions

## Integration with CI/CD

These tests should be run:
- Before any commit that modifies commands
- After UI library changes
- During release validation
- As part of PR validation

The test suite is designed to catch regressions in UI consistency and ensure the unified system remains intact as the codebase evolves.