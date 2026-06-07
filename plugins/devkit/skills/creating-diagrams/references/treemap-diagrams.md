# Treemap Diagrams

Treemap diagrams visualize hierarchical data as nested rectangles, where each node's size represents a quantitative value. They're excellent for showing proportional relationships within hierarchies.

## Basic Syntax

```mermaid
treemap-beta
    "Frontend"
        "React": 45
        "Vue": 25
        "Angular": 15
    "Backend"
        "Node.js": 30
        "Python": 35
        "Go": 20
```

## Node Types

### Section/Parent Nodes

Section nodes group child nodes but have no value themselves:

```mermaid
treemap-beta
    "Web Application"
        "Client Side"
        "Server Side"
```

### Leaf Nodes

Leaf nodes have numeric values that determine their size:

```mermaid
treemap-beta
    "Services"
        "Auth Service": 1200
        "User Service": 2500
        "Order Service": 3100
```

## Hierarchy with Indentation

Define hierarchy using spaces or tabs:

```mermaid
treemap-beta
    "Codebase"
        "Frontend"
            "Components": 5000
            "Utils": 1200
            "Styles": 800
        "Backend"
            "Controllers": 2500
            "Models": 1800
            "Services": 3200
```

## Use Cases in Software Development

### Codebase Size Analysis

Visualize lines of code or file count across modules:

```mermaid
treemap-beta
    title Codebase Distribution (Lines of Code)
    "Project"
        "src"
            "components": 8500
            "services": 6200
            "utils": 2100
            "types": 1500
        "tests"
            "unit": 4200
            "integration": 3100
            "e2e": 2800
        "docs": 1200
```

### Bundle Size Breakdown

Show JavaScript bundle composition:

```mermaid
treemap-beta
    title JavaScript Bundle Size (KB)
    "Total Bundle"
        "Dependencies"
            "react": 45
            "react-dom": 120
            "lodash": 72
            "axios": 31
            "date-fns": 28
        "Application Code"
            "components": 85
            "services": 42
            "utils": 23
            "routes": 18
```

### API Request Distribution

Visualize API endpoint usage:

```mermaid
treemap-beta
    title API Request Count (Last 24h)
    "API Endpoints"
        "User Endpoints"
            "/users/profile": 15000
            "/users/settings": 8200
            "/users/login": 25000
        "Order Endpoints"
            "/orders/list": 12000
            "/orders/create": 9500
            "/orders/status": 18000
        "Product Endpoints"
            "/products/search": 32000
            "/products/details": 28000
```

### Resource Allocation

Show cloud resource usage or cost:

```mermaid
treemap-beta
    title AWS Monthly Cost ($)
    "Total Infrastructure"
        "Compute"
            "EC2 Instances": 1250
            "Lambda": 420
            "ECS": 680
        "Storage"
            "S3": 350
            "EBS": 520
            "RDS": 890
        "Network"
            "CloudFront": 280
            "Data Transfer": 190
```

### Test Coverage

Visualize test coverage by module:

```mermaid
treemap-beta
    title Test Coverage (Test Count)
    "Test Suite"
        "Unit Tests"
            "Components": 145
            "Services": 98
            "Utils": 67
            "Models": 54
        "Integration Tests"
            "API": 42
            "Database": 31
            "Auth": 23
        "E2E Tests"
            "User Flows": 18
            "Admin Flows": 12
```

### Error Rate by Service

Monitor error distribution across microservices:

```mermaid
treemap-beta
    title Error Count (Last Hour)
    "Production Errors"
        "Backend Services"
            "User Service": 23
            "Order Service": 45
            "Payment Service": 12
            "Notification Service": 8
        "Frontend"
            "Web App": 67
            "Mobile App": 34
        "Infrastructure"
            "Load Balancer": 5
            "Cache": 3
```

### Technical Debt

Quantify technical debt by category:

```mermaid
treemap-beta
    title Technical Debt (Story Points)
    "Technical Debt"
        "Code Quality"
            "Duplicated Code": 34
            "Complex Functions": 28
            "Long Methods": 21
        "Testing"
            "Missing Tests": 45
            "Flaky Tests": 18
        "Architecture"
            "Tight Coupling": 32
            "Missing Abstractions": 25
        "Documentation"
            "Outdated Docs": 15
            "Missing Docs": 29
```

### Memory Usage by Component

Show runtime memory allocation:

```mermaid
treemap-beta
    title Memory Usage (MB)
    "Application Memory"
        "Core Modules"
            "React Renderer": 12.5
            "State Management": 8.3
            "Router": 3.2
        "Third-party Libraries"
            "UI Components": 18.7
            "Data Visualization": 15.4
            "Utilities": 6.1
        "Application Data"
            "Cached Data": 45.2
            "User Session": 8.9
            "Media Assets": 32.1
```

### Team Velocity

Compare team productivity across sprints:

```mermaid
treemap-beta
    title Sprint Velocity (Story Points)
    "Q4 2024"
        "Team Alpha"
            "Sprint 1": 42
            "Sprint 2": 38
            "Sprint 3": 45
        "Team Beta"
            "Sprint 1": 35
            "Sprint 2": 40
            "Sprint 3": 43
        "Team Gamma"
            "Sprint 1": 30
            "Sprint 2": 32
            "Sprint 3": 36
```

### Database Table Size

Visualize database storage usage:

```mermaid
treemap-beta
    title Database Storage (GB)
    "Production DB"
        "Core Tables"
            "users": 12.5
            "orders": 28.3
            "products": 8.7
        "Logging Tables"
            "audit_logs": 45.2
            "event_logs": 32.1
        "Analytics Tables"
            "user_analytics": 18.9
            "order_analytics": 22.4
```

## Styling

### Custom Classes

Apply custom styles to specific nodes:

```mermaid
%%{
  init: {
    'themeVariables': {
      'treemapTextColor': '#000',
      'treemapShapeColor': '#f0f0f0'
    }
  }
}%%
treemap-beta
    classDef critical fill:#ff6b6b,color:#fff
    classDef warning fill:#ffd93d,color:#000
    classDef healthy fill:#6bcf7f,color:#fff

    "System Health"
        "Critical Services":::critical
            "Auth": 98
            "Payment": 156
        "Warning Services":::warning
            "Email": 45
            "SMS": 32
        "Healthy Services":::healthy
            "Logging": 23
            "Analytics": 18
```

## Configuration

### Scale and Padding

```javascript
%%{
  init: {
    'treemap': {
      'useMaxWidth': true,
      'padding': 15,
      'diagramPadding': 10
    }
  }
}%%
```

**Options:**
- `useMaxWidth`: Scale to container width (default: `true`)
- `padding`: Internal padding between nodes (default: `10`)
- `diagramPadding`: Outer padding around diagram (default: `8`)

### Value Display

```javascript
%%{
  init: {
    'treemap': {
      'showValues': true,
      'valueFontSize': '14px',
      'labelFontSize': '16px'
    }
  }
}%%
```

**Options:**
- `showValues`: Display numeric values (default: `true`)
- `valueFontSize`: Font size for values
- `labelFontSize`: Font size for labels

### Value Formatting

Use D3 format specifiers for value display:

```javascript
%%{
  init: {
    'treemap': {
      'valueFormat': ',.2f'
    }
  }
}%%
```

**Common format specifiers:**
- `,` - Thousands separator: `1,234`
- `$,.2f` - Currency: `$1,234.56`
- `.1%` - Percentage: `45.2%`
- `.2s` - SI prefix: `1.23k`, `4.56M`

Example with currency formatting:

```mermaid
%%{
  init: {
    'treemap': {
      'valueFormat': '$,.0f'
    }
  }
}%%
treemap-beta
    title Monthly Revenue by Product
    "Products"
        "Subscriptions": 45000
        "One-time Sales": 28000
        "Add-ons": 12000
```

## Tips for Effective Treemap Diagrams

1. **Use meaningful values** - Values should represent the metric being analyzed (LOC, bytes, count, cost)
2. **Limit depth to 2-3 levels** - Deep hierarchies become hard to read
3. **Keep node count reasonable** - Too many small rectangles create clutter
4. **Use consistent units** - All leaf nodes should use the same unit of measurement
5. **Add titles** - Use `title` keyword to clarify what the treemap represents
6. **Color code by category** - Use custom classes to highlight different types of nodes
7. **Format large numbers** - Use D3 format specifiers for readability
8. **Group small items** - Combine tiny values into an "Other" category
9. **Compare similar data** - Multiple treemaps side-by-side work well for before/after comparisons
10. **Label clearly** - Ensure labels are descriptive enough without needing external context

## Comparison with Other Diagrams

| Use Treemap When | Use Instead When |
|-----------------|------------------|
| Showing proportional size within hierarchy | **Pie Chart**: Flat data, few categories |
| Comparing many items at once | **Bar Chart**: Emphasizing precise values |
| Visualizing nested part-to-whole relationships | **Sunburst**: Emphasizing hierarchical depth |
| Space efficiency is important | **Tree Diagram**: Showing connections/flow |

## Common Anti-patterns

❌ **Too many small nodes** - Below 1-2% of total, nodes become unreadable
❌ **Mixed units** - Combining different metrics in one treemap
❌ **Deep hierarchies** - More than 3 levels reduce clarity
❌ **No value differentiation** - All equal values produce a grid, not insights
❌ **Unlabeled sections** - Missing context makes data meaningless

## Advanced Example

```mermaid
%%{
  init: {
    'treemap': {
      'padding': 12,
      'showValues': true,
      'valueFontSize': '13px',
      'labelFontSize': '15px',
      'valueFormat': ',.0f'
    },
    'themeVariables': {
      'treemapTextColor': '#333'
    }
  }
}%%
treemap-beta
    title Cloud Infrastructure Cost ($)
    classDef compute fill:#5DADE2,color:#fff
    classDef storage fill:#58D68D,color:#fff
    classDef network fill:#F7DC6F,color:#333

    "AWS Monthly Cost"
        "Compute":::compute
            "Production EC2": 3250
            "Staging EC2": 890
            "Lambda Functions": 1420
            "ECS Containers": 2100
        "Storage":::storage
            "S3 Buckets": 1850
            "EBS Volumes": 1280
            "RDS Databases": 2640
            "ElastiCache": 920
        "Network":::network
            "CloudFront CDN": 1680
            "Data Transfer": 740
            "Load Balancers": 560
```

This produces a visually organized, color-coded breakdown of cloud costs with proper formatting and clear visual hierarchy.
