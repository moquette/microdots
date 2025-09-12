# Testing AI Agent Initialization

## How to Test CLAUDE.md Compliance

### Method 1: New Claude Code Session
1. Open a new Claude Code session
2. Navigate to the dotfiles repository
3. Ask Claude: "Please initialize and show me you've read all documentation"
4. Verify Claude displays the confirmation checklist

### Method 2: Test Prompt
Copy and paste this into a new Claude session:

```
I'm working in the ~/.dotfiles repository. Please read all the required documentation as specified in CLAUDE.md and provide the initialization confirmation.
```

### Expected Output
The AI should display:

```
✅ Documentation Initialized:
- [x] ~/.claude/README.md - Global configuration loaded
- [x] ~/.claude/PROTOCOL.md - Autonomous execution protocol internalized
- [x] MICRODOTS.md - Architecture guide understood
- [x] docs/IMPLEMENTATION.md - Technical details reviewed
- [x] docs/COMPLIANCE.md - Compliance standards acknowledged
- [x] docs/LOCAL_OVERRIDES.md - Dotlocal system understood
- [x] docs/UI_STYLE_GUIDE.md - UI standards loaded
```

### Method 3: Automated Test
Run the compliance test:

```bash
/Users/moquette/.dotfiles/tests/test_claude_compliance.sh
```

This verifies that:
- All required documentation exists
- CLAUDE.md has the mandatory reading requirements
- The confirmation checklist is properly defined
- All documents are referenced correctly

### Method 4: Knowledge Test
After initialization, test the AI's knowledge:

```
Without re-reading the files, can you tell me:
1. What is the four-stage loading process?
2. What is the difference between dotfiles and dotlocal?
3. What are the core principles of Microdots?
```

The AI should be able to answer these from the documentation it read during initialization.

## Success Criteria

✅ The test is successful if:
1. AI displays the complete confirmation checklist
2. AI can answer questions about the documentation content
3. The compliance test script passes
4. AI follows the patterns described in the documentation

## Troubleshooting

If the AI doesn't show the checklist:
1. Check if CLAUDE.md is accessible in the repository
2. Verify the symlinks are working (`ls -la ~/Library/Mobile\ Documents/com~apple~CloudDocs/Dotfiles/dotlocal/CLAUDE.md`)
3. Ensure the AI has access to read the files
4. Try explicitly asking: "Please read CLAUDE.md and follow its initialization requirements"