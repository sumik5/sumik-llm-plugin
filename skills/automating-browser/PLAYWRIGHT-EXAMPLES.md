# playwright-cli Practical Examples

Real-world usage examples for common automation scenarios.

## Example 1: Login Flow

```bash
# Navigate to login page
playwright-cli open https://app.example.com/login
playwright-cli snapshot
# Output: textbox "Email" [ref=e1], textbox "Password" [ref=e2], button "Sign In" [ref=e3]

# Fill credentials
playwright-cli fill e1 "user@example.com"
playwright-cli fill e2 "secretPassword123"
playwright-cli click e3

# Wait for navigation and verify
playwright-cli run-code "await page.waitForURL('**/dashboard')"
playwright-cli snapshot
# Now on dashboard page
```

## Example 2: Form with Multiple Input Types

```bash
playwright-cli open https://example.com/registration
playwright-cli snapshot

# Text inputs
playwright-cli fill e1 "John Doe"           # Name
playwright-cli fill e2 "john@example.com"   # Email
playwright-cli fill e3 "+1-555-123-4567"    # Phone

# Dropdown selection
playwright-cli select e4 "USA"              # Country

# Checkbox
playwright-cli check e5                     # Terms agreement

# Date input (native)
playwright-cli fill e6 "2024-12-31"

# File upload
playwright-cli upload /path/to/document.pdf

# Submit
playwright-cli click e7
playwright-cli snapshot
```

## Example 3: Data Extraction

```bash
playwright-cli open https://example.com/products
playwright-cli snapshot

# Get page title
playwright-cli eval "document.title"

# Get specific text content
playwright-cli eval "el => el.textContent" e1

# Get attribute
playwright-cli eval "el => el.getAttribute('href')" e3

# Count elements
playwright-cli eval "document.querySelectorAll('.product-card').length"

# Get all product names (returns array)
playwright-cli eval "Array.from(document.querySelectorAll('.product-name')).map(el => el.textContent)"
```

## Example 4: Screenshot Documentation

```bash
# Full page screenshot
playwright-cli open https://example.com/features
playwright-cli run-code "await page.waitForLoadState('networkidle')"
playwright-cli screenshot

# Screenshot specific element
playwright-cli snapshot
playwright-cli screenshot e5

# Multiple viewport screenshots
playwright-cli resize 1920 1080
playwright-cli screenshot

playwright-cli resize 768 1024
playwright-cli screenshot

playwright-cli resize 375 667
playwright-cli screenshot

# Generate PDF
playwright-cli pdf
```

## Example 5: Parallel Sessions

```bash
# Start multiple isolated sessions
playwright-cli --session=user1 open https://app.example.com/login
playwright-cli --session=user2 open https://app.example.com/login
playwright-cli --session=admin open https://app.example.com/admin/login

# Login as user1
playwright-cli --session=user1 snapshot
playwright-cli --session=user1 fill e1 "user1@example.com"
playwright-cli --session=user1 fill e2 "password1"
playwright-cli --session=user1 click e3

# Login as user2 (parallel)
playwright-cli --session=user2 snapshot
playwright-cli --session=user2 fill e1 "user2@example.com"
playwright-cli --session=user2 fill e2 "password2"
playwright-cli --session=user2 click e3

# Login as admin
playwright-cli --session=admin snapshot
playwright-cli --session=admin fill e1 "admin@example.com"
playwright-cli --session=admin fill e2 "adminpass"
playwright-cli --session=admin click e3

# Each session has separate cookies, storage, auth state
playwright-cli session-list

# Cleanup
playwright-cli session-stop-all
```

## Example 6: E2E Test Pattern

```bash
#!/bin/bash
# e2e-test.sh - Complete E2E test example

set -e  # Exit on error

echo "Starting E2E test..."

# Setup
playwright-cli open https://app.example.com

# Test: User can search for products
playwright-cli snapshot
playwright-cli fill e1 "laptop"  # Search input
playwright-cli click e2          # Search button
playwright-cli run-code "await page.waitForLoadState('networkidle')"
echo "✓ Search works"

# Test: User can click on a product
playwright-cli snapshot
playwright-cli click e3          # First product
playwright-cli run-code "await page.waitForURL('**/product/*')"
echo "✓ Product navigation works"

# Test: User can add to cart
playwright-cli snapshot
playwright-cli click e4          # Add to cart button
playwright-cli run-code "await page.waitForSelector('.cart-notification')"
echo "✓ Add to cart works"

# Cleanup
playwright-cli close
echo "All tests passed!"
```

## Example 7: Handling Dynamic Content

```bash
# Wait for AJAX-loaded content
playwright-cli open https://example.com/dashboard
playwright-cli run-code "await page.waitForLoadState('networkidle')"
playwright-cli snapshot

# Wait for specific element
playwright-cli run-code "await page.waitForSelector('.data-loaded')"
playwright-cli snapshot

# Wait for JavaScript condition
playwright-cli run-code "await page.waitForFunction(() => window.dataLoaded === true)"
playwright-cli snapshot

# Scroll to load more content (infinite scroll)
playwright-cli mousewheel 0 1000
playwright-cli run-code "await page.waitForTimeout(500)"
playwright-cli snapshot  # Re-snapshot to get new elements
```

## Example 8: Dialog Handling

```bash
playwright-cli open https://example.com/settings
playwright-cli snapshot

# Click button that triggers confirm dialog
playwright-cli click e1  # "Delete Account" button

# Accept the confirm dialog
playwright-cli dialog-accept

# Or dismiss it
# playwright-cli dialog-dismiss

# Handle prompt dialog with input
playwright-cli click e2  # Button that triggers prompt
playwright-cli dialog-accept "my confirmation text"
```

## Example 9: Multi-Tab Workflow

```bash
# Open main page
playwright-cli open https://example.com
playwright-cli snapshot

# Open new tab with different page
playwright-cli tab-new https://example.com/settings

# List tabs
playwright-cli tab-list

# Switch between tabs
playwright-cli tab-select 0  # Main page
playwright-cli snapshot
# ... do something ...

playwright-cli tab-select 1  # Settings page
playwright-cli snapshot
# ... do something else ...

# Close settings tab
playwright-cli tab-close 1

# Back to main (now only tab)
playwright-cli tab-select 0
playwright-cli snapshot
```

## Example 10: Debugging Session

```bash
# Open page
playwright-cli open https://buggy-app.example.com

# Perform actions
playwright-cli snapshot
playwright-cli click e4
playwright-cli fill e7 "test"
playwright-cli click e3

# Check for JavaScript errors
playwright-cli console error

# View all console messages
playwright-cli console

# Check network requests
playwright-cli network

# Start tracing for detailed analysis
playwright-cli tracing-start
playwright-cli snapshot
playwright-cli click e1
playwright-cli fill e2 "test"
playwright-cli click e3
playwright-cli tracing-stop
# Trace file can be viewed in Playwright Trace Viewer
```

## Example 11: Keyboard Shortcuts

```bash
playwright-cli open https://docs.example.com

# Select all text (Ctrl+A)
playwright-cli keydown Control
playwright-cli press a
playwright-cli keyup Control

# Copy (Ctrl+C)
playwright-cli keydown Control
playwright-cli press c
playwright-cli keyup Control

# Navigate with Tab
playwright-cli press Tab
playwright-cli press Tab
playwright-cli press Enter

# Form navigation
playwright-cli snapshot
playwright-cli fill e1 "first field"
playwright-cli press Tab
playwright-cli type "second field"
playwright-cli press Tab
playwright-cli press Enter  # Submit
```

## Example 12: Mouse Interactions

```bash
playwright-cli open https://example.com/canvas-app

# Draw on canvas
playwright-cli mousemove 100 100
playwright-cli mousedown
playwright-cli mousemove 200 100
playwright-cli mousemove 200 200
playwright-cli mousemove 100 200
playwright-cli mousemove 100 100
playwright-cli mouseup

# Right-click context menu
playwright-cli mousemove 150 150
playwright-cli mousedown right
playwright-cli mouseup right

# Scroll with mouse wheel
playwright-cli mousewheel 0 500    # Scroll down
playwright-cli mousewheel 0 -500   # Scroll up
```

## Tips for Effective Automation

1. **Always snapshot before interacting** - refs change after DOM updates
2. **Re-snapshot after actions** that modify the page
3. **Use `run-code` for waits** - `await page.waitForTimeout(1000)`, `await page.waitForSelector('.loaded')`
4. **Use sessions for parallel tests** - each session is isolated
5. **Check console/network** when debugging unexpected behavior
6. **Use `eval` for data extraction** - returns values directly
7. **Combine multiple actions** in one `run-code` for complex sequences

## Common Wait Patterns

```bash
# Wait for network idle
playwright-cli run-code "await page.waitForLoadState('networkidle')"

# Wait for specific element
playwright-cli run-code "await page.waitForSelector('#loaded')"

# Wait for URL change
playwright-cli run-code "await page.waitForURL('**/dashboard')"

# Wait for timeout
playwright-cli run-code "await page.waitForTimeout(1000)"

# Wait for function
playwright-cli run-code "await page.waitForFunction(() => document.querySelector('.data').textContent.length > 0)"
```
