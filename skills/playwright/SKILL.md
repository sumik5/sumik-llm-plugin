---
name: playwright
description: Lightweight browser automation using Microsoft's Playwright MCP for simple workflows. Use when basic navigation, form filling, screenshots, or JavaScript evaluation is needed. For complex scenarios requiring semantic locators, state persistence, or network interception, use agent-browser instead.
allowed-tools:
  - Bash(playwright-cli:*)
  - Bash(which playwright-cli*)
  - Bash(command -v playwright-cli*)
  - Bash(npm install -g @playwright/mcp*)
---

# Browser Automation with playwright-cli

## Prerequisites Check (Auto-Install)

**IMPORTANT:** Before using playwright-cli, run this command to ensure installation:

```bash
# Auto-install if not present (run this first!)
which playwright-cli || npm install -g @playwright/mcp@latest
```

This single command checks if `playwright-cli` exists, and installs it automatically if missing.

## Quick Start Workflow

```bash
# 1. Navigate to page
playwright-cli open https://example.com

# 2. Get page snapshot with element refs (e1, e2, etc.)
playwright-cli snapshot

# 3. Interact using refs from snapshot
playwright-cli click e1
playwright-cli fill e5 "input text"

# 4. Re-snapshot after DOM changes
playwright-cli snapshot

# 5. Close browser when done
playwright-cli close
```

## Core Workflow Pattern

1. **Navigate**: `playwright-cli open <url>`
2. **Snapshot**: `playwright-cli snapshot` (returns elements with refs like `e1`, `e2`)
3. **Interact**: Use refs from snapshot for clicks, fills, etc.
4. **Re-snapshot**: After navigation or significant DOM changes
5. **Repeat**: Until task is complete

## Essential Commands

### Navigation
```bash
playwright-cli open <url>      # Navigate to URL
playwright-cli go-back         # Go back in history
playwright-cli go-forward      # Go forward in history
playwright-cli reload          # Reload current page
playwright-cli close           # Close browser
```

### Page Analysis
```bash
playwright-cli snapshot        # Get accessibility tree with element refs
```

### Interactions
```bash
playwright-cli click e1           # Click element
playwright-cli dblclick e1        # Double-click
playwright-cli fill e2 "text"     # Clear field and type text
playwright-cli type "text"        # Type text into focused element
playwright-cli hover e1           # Hover over element
playwright-cli check e1           # Check checkbox
playwright-cli uncheck e1         # Uncheck checkbox
playwright-cli select e1 "value"  # Select dropdown option
playwright-cli drag e1 e2         # Drag from e1 to e2
playwright-cli upload file.pdf    # Upload file
```

### Keyboard
```bash
playwright-cli press Enter        # Press key
playwright-cli press ArrowDown    # Arrow keys
playwright-cli keydown Shift      # Press key down
playwright-cli keyup Shift        # Release key
```

### Mouse
```bash
playwright-cli mousemove 150 300  # Move mouse
playwright-cli mousedown          # Mouse button down
playwright-cli mouseup            # Mouse button up
playwright-cli mousewheel 0 100   # Scroll wheel
```

### Screenshots & Export
```bash
playwright-cli screenshot         # Screenshot to stdout
playwright-cli screenshot e5      # Screenshot specific element
playwright-cli pdf                # Export page as PDF
```

### Dialogs
```bash
playwright-cli dialog-accept              # Accept dialog
playwright-cli dialog-accept "input"      # Accept prompt with text
playwright-cli dialog-dismiss             # Dismiss dialog
```

### Tabs
```bash
playwright-cli tab-list           # List all tabs
playwright-cli tab-new            # Open new tab
playwright-cli tab-new <url>      # Open new tab with URL
playwright-cli tab-select 0       # Switch to tab by index
playwright-cli tab-close          # Close current tab
playwright-cli tab-close 2        # Close tab by index
```

### DevTools
```bash
playwright-cli console            # View console messages
playwright-cli console warning    # Filter by level (log/warning/error)
playwright-cli network            # View network requests
playwright-cli run-code "code"    # Run Playwright code snippet
playwright-cli tracing-start      # Start trace recording
playwright-cli tracing-stop       # Stop trace recording
```

### Sessions (Parallel Browsers)
```bash
playwright-cli --session=site1 open https://site1.com
playwright-cli --session=site2 open https://site2.com
playwright-cli session-list              # List active sessions
playwright-cli session-stop mysession    # Stop specific session
playwright-cli session-stop-all          # Stop all sessions
playwright-cli session-delete mysession  # Delete session data
```

## Common Patterns

### Form Submission
```bash
playwright-cli open https://example.com/form
playwright-cli snapshot
playwright-cli fill e1 "user@example.com"    # Email
playwright-cli fill e2 "password123"          # Password
playwright-cli click e3                       # Submit
playwright-cli snapshot                       # Verify result
```

### Multi-tab Workflow
```bash
playwright-cli open https://example.com
playwright-cli tab-new https://example.com/other
playwright-cli tab-list
playwright-cli tab-select 0
playwright-cli snapshot
```

### JavaScript Execution
```bash
playwright-cli eval "document.title"
playwright-cli eval "el => el.textContent" e5
playwright-cli run-code "await page.waitForTimeout(1000)"
```

## Tips

1. **Always snapshot before interacting** - refs change after DOM updates
2. **Re-snapshot after actions** that modify the page
3. **Use sessions** for parallel independent browser instances
4. **Check console/network** when debugging issues

## Additional Resources

- **Detailed Command Reference**: See [COMMANDS.md](COMMANDS.md)
- **Practical Examples**: See [EXAMPLES.md](EXAMPLES.md)
- **Playwright MCP**: https://github.com/microsoft/playwright-mcp
