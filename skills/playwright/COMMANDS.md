# playwright-cli Command Reference

Comprehensive reference for all playwright-cli commands.

## Navigation Commands

| Command | Description |
|---------|-------------|
| `open <url>` | Navigate to URL |
| `go-back` | Go back in history |
| `go-forward` | Go forward in history |
| `reload` | Reload current page |
| `close` | Close browser session |
| `resize <w> <h>` | Resize browser window |

### Navigation Examples

```bash
# Basic navigation
playwright-cli open https://example.com

# History navigation
playwright-cli go-back
playwright-cli go-forward

# Window management
playwright-cli resize 1920 1080
playwright-cli close
```

## Snapshot Command

The `snapshot` command returns an accessibility tree with element references.

```bash
playwright-cli snapshot
```

**Output format**: Elements are returned with refs like `e1`, `e2`, `e3` that can be used in subsequent commands.

### Example Snapshot Output

```
- textbox "Email" [ref=e1]
- textbox "Password" [ref=e2]
- button "Sign In" [ref=e3]
- link "Forgot Password?" [ref=e4]
```

## Interaction Commands

### Click Actions

| Command | Description |
|---------|-------------|
| `click <ref> [button]` | Click element (button: left/right/middle) |
| `dblclick <ref> [button]` | Double-click element |
| `hover <ref>` | Hover over element |

```bash
playwright-cli click e1           # Left click
playwright-cli click e1 right     # Right click
playwright-cli dblclick e3        # Double click
playwright-cli hover e4           # Hover
```

### Text Input

| Command | Description |
|---------|-------------|
| `type <text>` | Type text into focused element |
| `fill <ref> <text>` | Clear field and type text |

```bash
# Type into currently focused element
playwright-cli type "Hello World"

# Fill specific field (clears existing content)
playwright-cli fill e2 "user@example.com"
```

### Form Controls

| Command | Description |
|---------|-------------|
| `check <ref>` | Check checkbox/radio |
| `uncheck <ref>` | Uncheck checkbox |
| `select <ref> <value>` | Select dropdown option |
| `upload <file>` | Upload file |
| `drag <startRef> <endRef>` | Drag and drop |

```bash
playwright-cli check e5              # Check checkbox
playwright-cli uncheck e5            # Uncheck
playwright-cli select e6 "option1"   # Select dropdown
playwright-cli upload ./doc.pdf      # Upload file
playwright-cli drag e7 e8            # Drag from e7 to e8
```

## Keyboard Commands

| Command | Description |
|---------|-------------|
| `press <key>` | Press and release key |
| `keydown <key>` | Press key down |
| `keyup <key>` | Release key |

### Key Names

**Navigation**: `Enter`, `Tab`, `Escape`, `Backspace`, `Delete`
**Arrows**: `ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`
**Modifiers**: `Control`, `Shift`, `Alt`, `Meta` (Cmd on Mac)
**Function**: `F1`-`F12`
**Special**: `Home`, `End`, `PageUp`, `PageDown`, `Space`

```bash
playwright-cli press Enter
playwright-cli press Tab
playwright-cli press ArrowDown

# Modifier combinations (use keydown/keyup)
playwright-cli keydown Shift
playwright-cli press ArrowDown
playwright-cli keyup Shift
```

## Mouse Commands

| Command | Description |
|---------|-------------|
| `mousemove <x> <y>` | Move mouse to coordinates |
| `mousedown [button]` | Press mouse button (left/right) |
| `mouseup [button]` | Release mouse button |
| `mousewheel <dx> <dy>` | Scroll wheel |

```bash
# Move and click
playwright-cli mousemove 100 200
playwright-cli mousedown
playwright-cli mouseup

# Right click
playwright-cli mousedown right
playwright-cli mouseup right

# Scroll
playwright-cli mousewheel 0 500    # Scroll down
playwright-cli mousewheel 0 -500   # Scroll up
playwright-cli mousewheel 100 0    # Scroll right
```

## Dialog Commands

| Command | Description |
|---------|-------------|
| `dialog-accept [prompt]` | Accept dialog (optional input text) |
| `dialog-dismiss` | Dismiss/cancel dialog |

```bash
# Accept alert/confirm
playwright-cli dialog-accept

# Accept prompt with input
playwright-cli dialog-accept "my input text"

# Dismiss/cancel
playwright-cli dialog-dismiss
```

## JavaScript Execution

| Command | Description |
|---------|-------------|
| `eval <expression> [ref]` | Evaluate JS on page or element |
| `run-code <code>` | Run Playwright code snippet |

```bash
# Page-level evaluation
playwright-cli eval "document.title"
playwright-cli eval "window.location.href"
playwright-cli eval "document.querySelectorAll('a').length"

# Element-level evaluation
playwright-cli eval "el => el.textContent" e5
playwright-cli eval "el => el.getAttribute('href')" e3
playwright-cli eval "el => el.getBoundingClientRect()" e1

# Run Playwright code
playwright-cli run-code "await page.waitForTimeout(1000)"
playwright-cli run-code "await page.waitForSelector('.loaded')"
```

## Screenshots & PDF

| Command | Description |
|---------|-------------|
| `screenshot` | Screenshot entire page to stdout |
| `screenshot <ref>` | Screenshot specific element |
| `pdf` | Generate PDF of page |

```bash
# Full page screenshot
playwright-cli screenshot

# Element screenshot
playwright-cli screenshot e5

# Generate PDF
playwright-cli pdf
```

## Tab Management

| Command | Description |
|---------|-------------|
| `tab-list` | List all open tabs |
| `tab-new [url]` | Create new tab |
| `tab-select <index>` | Switch to tab by index (0-based) |
| `tab-close [index]` | Close tab |

```bash
# Tab operations
playwright-cli tab-list
playwright-cli tab-new
playwright-cli tab-new https://example.com/page2
playwright-cli tab-select 0          # First tab
playwright-cli tab-select 1          # Second tab
playwright-cli tab-close             # Close current
playwright-cli tab-close 2           # Close specific tab
```

## DevTools Commands

| Command | Description |
|---------|-------------|
| `console [level]` | View console messages (log/warning/error) |
| `network` | List network requests |
| `tracing-start` | Start trace recording |
| `tracing-stop` | Stop trace and save |

```bash
# Console messages
playwright-cli console             # All messages
playwright-cli console warning     # Warnings only
playwright-cli console error       # Errors only

# Network requests
playwright-cli network

# Performance tracing
playwright-cli tracing-start
# ... perform actions ...
playwright-cli tracing-stop
```

## Session Management

Sessions allow running multiple independent browser instances.

| Command | Description |
|---------|-------------|
| `--session=<name>` | Use named session (prefix any command) |
| `session-list` | List active sessions |
| `session-stop [name]` | Stop session |
| `session-stop-all` | Stop all sessions |
| `session-delete [name]` | Delete session data |

```bash
# Create isolated sessions
playwright-cli --session=auth open https://app.example.com/login
playwright-cli --session=guest open https://app.example.com

# Work in specific session
playwright-cli --session=auth snapshot
playwright-cli --session=auth fill e1 "admin@example.com"
playwright-cli --session=auth click e3

# Session management
playwright-cli session-list
playwright-cli session-stop auth
playwright-cli session-stop-all
playwright-cli session-delete auth
```

## Global Options

| Option | Description |
|--------|-------------|
| `--session=<name>` | Use named session |
| `--headed` | Show browser window (if supported) |
| `--help` | Show help message |

## Command Summary Table

| Category | Commands |
|----------|----------|
| **Navigation** | `open`, `go-back`, `go-forward`, `reload`, `close`, `resize` |
| **Analysis** | `snapshot` |
| **Interaction** | `click`, `dblclick`, `fill`, `type`, `hover`, `check`, `uncheck`, `select`, `drag`, `upload` |
| **Keyboard** | `press`, `keydown`, `keyup` |
| **Mouse** | `mousemove`, `mousedown`, `mouseup`, `mousewheel` |
| **Dialog** | `dialog-accept`, `dialog-dismiss` |
| **JavaScript** | `eval`, `run-code` |
| **Export** | `screenshot`, `pdf` |
| **Tabs** | `tab-list`, `tab-new`, `tab-select`, `tab-close` |
| **DevTools** | `console`, `network`, `tracing-start`, `tracing-stop` |
| **Sessions** | `session-list`, `session-stop`, `session-stop-all`, `session-delete` |
