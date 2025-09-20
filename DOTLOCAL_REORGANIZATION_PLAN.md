# 📋 Dotlocal Reorganization Plan

**Created**: 2025-01-20
**Last Updated**: 2025-01-20
**Status**: Phase 1 Complete ✅
**Risk Level**: High (affects core infrastructure)
**Estimated Timeline**: 2-3 weeks for full implementation

---

## 📌 Executive Summary

The `~/.dotfiles/.dotlocal/` directory has become difficult to manage due to mixing:
- True microdots (self-contained configuration microservices)
- Simple configuration files
- Private/sensitive data
- Infrastructure symlinks

This plan outlines a **phased, low-risk approach** to reorganize the dotlocal structure for better maintainability while ensuring zero downtime and full backward compatibility.

---

## 🎯 Goals

1. **Clear Visual Organization** - Immediately obvious what is a microdot vs config vs private data
2. **Maintain Zero Coupling** - Preserve microdots architecture principles
3. **Zero Downtime** - System remains functional throughout migration
4. **Backward Compatible** - Existing setups continue to work
5. **Future Scalability** - Easy to add new microdots without confusion

---

## 📊 Current State Analysis

### Directory Classification

| Type | Count | Examples | Characteristics |
|------|-------|----------|-----------------|
| **True Microdots** | 9 | atuin, backup, claude, node, z | Has install.sh, __tests__, or multiple .zsh files |
| **Simple Configs** | 7 | bin, editors, functions, vim | Single .zsh file or minimal setup |
| **Private Data** | 1 | ssh.symlink | Sensitive information |
| **Infrastructure** | 6 | core, docs, *.md symlinks | Shared resources |

### Current Problems

1. **Visual Confusion** - Can't distinguish types at a glance
2. **Management Overhead** - Mixed concerns in single directory
3. **Scaling Issues** - Gets worse as more items added
4. **Testing Complexity** - Hard to identify what needs tests

---

## 🔍 Infrastructure Dependencies Analysis

### Critical Discovery Mechanisms

| Component | File | Current Implementation | Impact of Subdirs |
|-----------|------|------------------------|-------------------|
| **Shell Loading** | `zsh/zshrc.symlink:39` | `$LOCAL_DIR/**/*.zsh` | ✅ Works (recursive) |
| **Installer Discovery** | `core/commands/install:197` | `$DOTLOCAL_EXPANDED/*/` | ❌ Broken (not recursive) |
| **Symlink Discovery** | `core/lib/symlink.sh:~335` | `find -name "*.symlink"` | ✅ Works (recursive) |
| **Status Display** | `core/commands/status` | Direct directory scan | ❌ Needs update |
| **Test Discovery** | Various test scripts | Multiple patterns | ⚠️ Needs verification |

### Infrastructure That Must Be Updated

1. **core/commands/install** - Lines 117-142, 197-217
2. **core/commands/status** - Topic counting and display
3. **Documentation** - MICRODOTS.md, LOCAL_OVERRIDES.md
4. **Tests** - Integration tests for discovery

---

## 📊 Phase 1 Completion Report (2025-01-20)

### What Was Accomplished

1. **Created `dots-classify` tool** - Full-featured classification script
   - Auto-discovers dotlocal location (including iCloud)
   - Analyzes directory characteristics
   - Creates YAML-like marker files
   - Supports multiple operation modes

2. **Classified 17 directories**:
   - **8 Microdots**: atuin, backup, claude, git, node, system, z, zsh
   - **8 Configs**: aws, bin, editors, functions, homebrew, misc, python, vim
   - **1 Private**: ssh.symlink

3. **Enhanced `dots status` command**:
   - Shows organization breakdown
   - Lists categories with counts
   - Verbose mode shows individual directories
   - Clear visual distinction between types

### Key Benefits Achieved

- ✅ **Zero breaking changes** - Everything works exactly as before
- ✅ **Immediate visibility** - Can see organization at a glance
- ✅ **Foundation ready** - Marker files enable future reorganization
- ✅ **Completely reversible** - `dots-classify --clean` removes all markers

### Tools Created

- `bin/dots-classify` - Classification and marker file generator
- Updated `core/commands/status` - Organization display

### Next Steps When Ready

Run Phase 2 to prepare infrastructure for actual reorganization.

---

## 🚀 Proposed Solution: Phased Implementation

## Phase 1: Marker Files (Week 1) ✅ COMPLETE
**Risk: Low | Breaking Changes: None**
**Completed**: 2025-01-20

### 1.1 Marker File Specification

Create `.microdot.type` files to identify directory types:

```yaml
# .microdot.type for true microdots
type: microdot
name: backup
has_install: true
has_tests: true
has_completions: false
maintainer: optional
description: Backup system microdot
```

```yaml
# .microdot.type for simple configs
type: config
name: editors
description: Editor environment variables
```

```yaml
# .microdot.type for private data
type: private
name: ssh
warning: Contains sensitive SSH keys
```

### 1.2 Implementation Steps ✅

1. **Created marker file generator script** (`bin/dots-classify`) ✅
   - Analyzes directories and creates `.microdot.type` files
   - Supports dry-run, verbose, force, and clean modes
   - Auto-discovers dotlocal path using system's 5-level precedence

2. **Added marker files to all directories** ✅
   - 17 directories classified and marked
   - 8 microdots, 8 configs, 1 private
   - Automated detection working perfectly

3. **Updated `dots status` to read and display types** ✅
   ```
   Dotlocal Organization:
   ├── Microdots (9)
   │   ├── ✅ backup (tests, install)
   │   ├── ✅ claude (tests, install)
   │   └── ...
   ├── Configs (7)
   │   ├── bin (path only)
   │   └── ...
   └── Private (1)
       └── ssh.symlink
   ```

4. **Benefits**
   - Zero infrastructure changes
   - Immediate organization visibility
   - Foundation for future phases

---

## Phase 2: Infrastructure Updates (Week 2)
**Risk: Medium | Breaking Changes: None (backward compatible)**

### 2.1 Update Discovery Mechanisms

#### Enhanced Installer Discovery
```bash
# core/commands/install - Support subdirectories
for topic_dir in "$DOTLOCAL_EXPANDED"/*/ \
                 "$DOTLOCAL_EXPANDED"/__microdots__/*/ \
                 "$DOTLOCAL_EXPANDED"/__configs__/*/ \
                 "$DOTLOCAL_EXPANDED"/__private__/*/; do
  [[ -d "$topic_dir" ]] || continue
  # Process installer
done
```

#### Enhanced Shell Loading
```bash
# zsh/zshrc.symlink - Explicit path scanning
local_config_files=(
  $LOCAL_DIR/**/*.zsh
  $LOCAL_DIR/__microdots__/**/*.zsh(N)
  $LOCAL_DIR/__configs__/**/*.zsh(N)
)
```

### 2.2 Create Migration Scripts

1. **Compatibility verification** (`bin/dots-verify-compat`)
   - Tests all discovery mechanisms
   - Validates nothing breaks with new structure

2. **Dry-run capability** for all changes
   - Preview what would change
   - No actual modifications

### 2.3 Update Documentation
- Update MICRODOTS.md with new organization
- Update LOCAL_OVERRIDES.md with directory structure
- Add migration guide

---

## Phase 3: Directory Reorganization (Week 3)
**Risk: High | Breaking Changes: Managed**

### 3.1 Target Structure

```
~/.dotfiles/.dotlocal/
├── __microdots__/        # True microdots (sorts first)
│   ├── atuin/
│   ├── backup/
│   ├── claude/
│   ├── git/
│   ├── node/
│   ├── system/
│   ├── z/
│   └── zsh/
├── __configs__/          # Simple configurations
│   ├── bin/
│   ├── editors/
│   ├── functions/
│   ├── homebrew/
│   ├── misc/
│   ├── python/
│   └── vim/
├── __private__/          # Sensitive data
│   └── ssh.symlink/
└── [infrastructure symlinks remain at root]
    ├── core -> ~/.dotfiles/core
    ├── docs -> ~/.dotfiles/docs
    └── *.md -> ...
```

### 3.2 Migration Process

1. **Create migration script** (`bin/dots-migrate-dotlocal`)
   ```bash
   #!/usr/bin/env bash
   # 1. Verify Phase 2 infrastructure updates
   # 2. Create new directory structure
   # 3. Move directories based on .microdot.type
   # 4. Verify all discovery mechanisms work
   # 5. Test shell loading
   ```

2. **Migration steps**:
   - Stop all shell sessions
   - Run migration script
   - Test thoroughly
   - Start new shell session

3. **Rollback plan**:
   - Script creates timestamped backup
   - One command to restore original structure

### 3.3 Validation

- All existing tests must pass
- Shell must load without errors
- All installers must be discovered
- Symlinks must be created correctly

---

## 📅 Implementation Timeline

| Week | Phase | Tasks | Risk |
|------|-------|-------|------|
| 1 | Phase 1 | Create marker files, update status command | Low |
| 1 | Phase 1 | Test marker file system | Low |
| 2 | Phase 2 | Update discovery mechanisms | Medium |
| 2 | Phase 2 | Create migration scripts | Medium |
| 2 | Phase 2 | Update documentation | Low |
| 3 | Phase 3 | Test in isolated environment | Medium |
| 3 | Phase 3 | Execute migration | High |
| 3 | Phase 3 | Validate and monitor | Medium |

---

## ✅ Success Criteria

### Phase 1 Success ✅
- [x] All directories have .microdot.type files
- [x] `dots status` shows organized view
- [x] No breaking changes
- [x] Documentation updated (plan and tasks)

### Phase 2 Success
- [ ] All discovery mechanisms support subdirectories
- [ ] Backward compatibility maintained
- [ ] Tests pass with mock structure
- [ ] Migration scripts tested

### Phase 3 Success
- [ ] Directories reorganized into __microdots__, __configs__, __private__
- [ ] All existing functionality works
- [ ] Shell loads without errors
- [ ] All tests pass
- [ ] Rollback tested and verified

---

## 🚨 Risk Mitigation

### Identified Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Shell loading breaks | Medium | High | Test extensively, rollback plan |
| Installer discovery fails | High | High | Fix in Phase 2 before moving |
| User confusion | Low | Medium | Clear documentation, gradual rollout |
| Lost files during migration | Low | High | Backup everything, dry-run first |

### Rollback Procedures

1. **Phase 1 Rollback**: Simply remove .microdot.type files
2. **Phase 2 Rollback**: Revert infrastructure changes (git)
3. **Phase 3 Rollback**: Run restore script from backup

---

## 📝 Decision Points

### Why NOT Direct Reorganization?

1. **High Risk** - Could break shell loading immediately
2. **No Testing** - Can't verify without implementing
3. **No Rollback** - Hard to undo quickly
4. **User Impact** - Immediate breaking changes

### Why Phased Approach?

1. **Low Risk Start** - Marker files are non-breaking
2. **Incremental Value** - Benefits at each phase
3. **Testing Opportunity** - Validate at each step
4. **Easy Rollback** - Can stop or revert at any phase
5. **User Communication** - Time to prepare users

---

## 📋 Pre-Implementation Checklist

- [ ] Review and approve this plan
- [ ] Create feature branch for development
- [ ] Set up test environment
- [ ] Notify team of upcoming changes
- [ ] Document current state (screenshots, file lists)
- [ ] Create backup of current .dotlocal

---

## 🎯 Next Steps

1. **Review this plan** and provide feedback
2. **Approve Phase 1** implementation
3. **Create feature branch**: `feature/dotlocal-reorganization`
4. **Begin Phase 1** implementation

---

## 📚 Related Documentation

- [MICRODOTS.md](MICRODOTS.md) - Architecture principles
- [docs/guides/LOCAL_OVERRIDES.md](docs/guides/LOCAL_OVERRIDES.md) - Current dotlocal system
- [docs/architecture/IMPLEMENTATION.md](docs/architecture/IMPLEMENTATION.md) - Technical details
- [TASKS.md](TASKS.md) - Track implementation progress

---

*This plan is version controlled and will be updated as implementation progresses.*