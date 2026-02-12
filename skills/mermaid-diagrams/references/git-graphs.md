# Git Graphs

Git graphs visualize version control history, showing branches, commits, merges, and tags. Useful for documenting branching strategies and release workflows.

## Basic Syntax

```mermaid
gitGraph
    commit
    commit
    branch develop
    checkout develop
    commit
    commit
    checkout main
    merge develop
```

## Commits

### Simple Commits

```mermaid
gitGraph
    commit
    commit
    commit
```

### Commits with IDs

```mermaid
gitGraph
    commit id: "init"
    commit id: "add-auth"
    commit id: "fix-bug"
```

### Commits with Tags

```mermaid
gitGraph
    commit id: "setup"
    commit id: "feature-a"
    commit id: "release" tag: "v1.0.0"
```

### Commit Types

```mermaid
gitGraph
    commit id: "normal" type: NORMAL
    commit id: "feature" type: HIGHLIGHT
    commit id: "revert" type: REVERSE
```

**Commit types:**
- `NORMAL` - Solid circle (default)
- `HIGHLIGHT` - Filled rectangle
- `REVERSE` - Circle with X (for reverts)

## Branches

### Creating Branches

```mermaid
gitGraph
    commit
    branch feature
    checkout feature
    commit
    commit
```

### Branch Names with Spaces

```mermaid
gitGraph
    commit
    branch "feature/user-auth"
    checkout "feature/user-auth"
    commit id: "add login"
    commit id: "add logout"
```

### Multiple Branches

```mermaid
gitGraph
    commit id: "init"

    branch develop
    checkout develop
    commit id: "setup"

    branch feature-a
    checkout feature-a
    commit id: "feat-a-1"
    commit id: "feat-a-2"

    checkout develop
    branch feature-b
    checkout feature-b
    commit id: "feat-b-1"

    checkout develop
    merge feature-a
    merge feature-b
```

## Merges

### Basic Merge

```mermaid
gitGraph
    commit
    branch feature
    checkout feature
    commit
    commit
    checkout main
    merge feature
    commit
```

### Merge with ID and Tag

```mermaid
gitGraph
    commit
    branch develop
    checkout develop
    commit id: "feature-1"
    commit id: "feature-2"
    checkout main
    merge develop id: "merge-develop" tag: "v1.1.0"
```

### Merge with Type

```mermaid
gitGraph
    commit
    branch hotfix
    checkout hotfix
    commit id: "urgent-fix"
    checkout main
    merge hotfix id: "apply-hotfix" type: REVERSE tag: "v1.0.1"
```

## Cherry-Pick

```mermaid
gitGraph
    commit id: "a"
    branch develop
    checkout develop
    commit id: "b"
    commit id: "important-fix"
    checkout main
    cherry-pick id: "important-fix"
    commit id: "c"
```

## Checkout / Switch

Both `checkout` and `switch` work identically:

```mermaid
gitGraph
    commit
    branch feature
    switch feature
    commit
    switch main
    commit
```

## Branch Order

Control visual positioning of branches:

```mermaid
gitGraph
    commit
    branch feature-a order: 3
    branch feature-b order: 1
    branch feature-c order: 2
    checkout feature-a
    commit
    checkout feature-b
    commit
    checkout feature-c
    commit
```

## Direction

### Left-to-Right (Default)

```mermaid
gitGraph LR:
    commit
    branch develop
    checkout develop
    commit
    checkout main
    merge develop
```

### Top-to-Bottom

```mermaid
gitGraph TB:
    commit id: "1"
    commit id: "2"
    branch feature
    checkout feature
    commit id: "3"
    checkout main
    commit id: "4"
    merge feature
```

### Bottom-to-Top

```mermaid
gitGraph BT:
    commit
    branch develop
    checkout develop
    commit
    checkout main
    merge develop
```

## Configuration

### Theme Settings

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'git0':'#ff0000', 'git1':'#00ff00'}}}%%
gitGraph
    commit
    branch develop
    checkout develop
    commit
```

### Available Themes

- `base` - Clean, minimal
- `forest` - Green tones
- `dark` - Dark background
- `default` - Standard colors
- `neutral` - Grayscale

## Use Cases

### Feature Branch Workflow

```mermaid
gitGraph
    commit id: "init" tag: "v1.0.0"
    commit id: "update deps"

    branch feature/authentication
    checkout feature/authentication
    commit id: "add user model"
    commit id: "add login endpoint"
    commit id: "add jwt auth"

    checkout main
    commit id: "hotfix: cors"

    checkout feature/authentication
    commit id: "add tests"

    checkout main
    merge feature/authentication id: "merge auth" tag: "v1.1.0"
    commit id: "update docs"
```

### Gitflow Workflow

```mermaid
gitGraph
    commit id: "init"
    branch develop
    checkout develop
    commit id: "setup project"

    branch feature/user-mgmt
    checkout feature/user-mgmt
    commit id: "add user crud"
    commit id: "add validation"

    checkout develop
    merge feature/user-mgmt

    branch release/v1.0
    checkout release/v1.0
    commit id: "bump version"
    commit id: "update changelog"

    checkout main
    merge release/v1.0 tag: "v1.0.0"

    checkout develop
    merge release/v1.0

    checkout main
    branch hotfix/security
    checkout hotfix/security
    commit id: "patch vuln" type: REVERSE

    checkout main
    merge hotfix/security tag: "v1.0.1"

    checkout develop
    merge hotfix/security
```

### Release Train

```mermaid
gitGraph
    commit id: "v1.0.0" tag: "v1.0.0"

    branch release/v1.1
    checkout release/v1.1
    commit id: "feat: add search"
    commit id: "feat: add filters"
    checkout main
    merge release/v1.1 tag: "v1.1.0"

    branch release/v1.2
    checkout release/v1.2
    commit id: "feat: export csv"
    commit id: "feat: dashboard"
    checkout main
    merge release/v1.2 tag: "v1.2.0"

    branch release/v1.3
    checkout release/v1.3
    commit id: "feat: notifications"
    commit id: "perf: caching"
    checkout main
    merge release/v1.3 tag: "v1.3.0"
```

### Cherry-Pick Example

```mermaid
gitGraph
    commit id: "a"
    commit id: "b"

    branch develop
    checkout develop
    commit id: "feat-1"
    commit id: "critical-fix"
    commit id: "feat-2"

    checkout main
    cherry-pick id: "critical-fix"
    commit id: "release" tag: "v1.0.1"

    checkout develop
    merge main
    commit id: "feat-3"
```

### Trunk-Based Development

```mermaid
gitGraph
    commit id: "stable" tag: "v1.0.0"

    branch short-lived-1
    checkout short-lived-1
    commit id: "quick feature"
    checkout main
    merge short-lived-1

    commit id: "integrate"

    branch short-lived-2
    checkout short-lived-2
    commit id: "small fix"
    checkout main
    merge short-lived-2

    commit id: "release prep"
    commit id: "deploy" tag: "v1.1.0"
```

### Multi-Environment Deployment

```mermaid
gitGraph
    commit id: "code"
    branch staging
    checkout staging
    commit id: "deploy staging" type: HIGHLIGHT
    commit id: "smoke test"

    checkout main
    merge staging id: "promote to prod" tag: "production"

    branch hotfix
    checkout hotfix
    commit id: "urgent fix" type: REVERSE

    checkout main
    merge hotfix tag: "hotfix-prod"

    checkout staging
    merge main
```

### Parallel Feature Development

```mermaid
gitGraph
    commit id: "base"

    branch feature/payments order: 1
    branch feature/notifications order: 2
    branch feature/analytics order: 3

    checkout feature/payments
    commit id: "stripe integration"
    commit id: "payment ui"

    checkout feature/notifications
    commit id: "email service"
    commit id: "push notifications"

    checkout feature/analytics
    commit id: "tracking setup"
    commit id: "dashboard charts"

    checkout main
    merge feature/payments
    merge feature/notifications
    merge feature/analytics tag: "v2.0.0"
```

### Rollback Scenario

```mermaid
gitGraph
    commit id: "v1.0" tag: "v1.0.0"
    commit id: "v1.1" tag: "v1.1.0"
    commit id: "v1.2-broken" tag: "v1.2.0"
    commit id: "revert v1.2" type: REVERSE
    commit id: "v1.2.1-fixed" tag: "v1.2.1"
```

## Tips for Effective Git Graphs

1. **Keep it focused** - Show only relevant branches and commits
2. **Use meaningful IDs** - Describe what each commit does
3. **Tag releases** - Mark version releases clearly
4. **Highlight important commits** - Use `HIGHLIGHT` type for key changes
5. **Show reverts** - Use `REVERSE` type for rollbacks
6. **Branch ordering** - Use `order` to keep related branches together
7. **Document strategy** - Use git graphs to communicate branching workflow
8. **Cherry-pick sparingly** - Show when fixes are backported
