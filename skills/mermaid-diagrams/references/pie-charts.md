# Pie Charts

Pie charts visualize proportional data as slices of a circle. They show relative sizes of parts to a whole, making it easy to compare categories at a glance.

## Basic Syntax

```mermaid
pie
    title Programming Language Usage
    "JavaScript" : 45
    "Python" : 30
    "Go" : 15
    "Rust" : 10
```

## Show Data Values

Add `showData` to display values in the legend:

```mermaid
pie showData
    title API Response Time Distribution
    "< 100ms" : 65
    "100-300ms" : 25
    "300-500ms" : 7
    "> 500ms" : 3
```

## Title Configuration

```mermaid
pie title Infrastructure Cost Breakdown
    "Compute" : 40
    "Storage" : 25
    "Networking" : 20
    "Database" : 15
```

**Title syntax:** `title <text>` (not quoted)

## Real-World Example: Sprint Task Distribution

```mermaid
pie showData title Sprint 23 Task Breakdown
    "Feature Development" : 45.5
    "Bug Fixes" : 22.3
    "Technical Debt" : 18.2
    "Documentation" : 9.0
    "Testing" : 5.0
```

## Technical Metrics Example: Error Types

```mermaid
pie showData title Production Errors by Category
    "Authentication" : 38
    "Database Connection" : 24
    "Rate Limiting" : 18
    "Invalid Input" : 12
    "Server Errors" : 8
```

## Time Allocation Example

```mermaid
pie showData title Developer Time Distribution
    "Writing Code" : 40
    "Code Review" : 15
    "Meetings" : 20
    "Debugging" : 15
    "Documentation" : 10
```

## Resource Usage Example

```mermaid
pie showData title Cloud Resource Costs
    "EC2 Instances" : 42.5
    "RDS Databases" : 28.0
    "S3 Storage" : 15.5
    "Lambda Functions" : 8.5
    "CloudFront CDN" : 5.5
```

## Value Rules

- **Positive numbers only** - Values must be greater than 0
- **Decimal precision** - Up to 2 decimal places
- **No negative values** - Will cause rendering errors

```mermaid
pie title Valid Values Example
    "Category A" : 33.33
    "Category B" : 33.33
    "Category C" : 33.34
```

## Slice Order

Slices are rendered clockwise starting from the top, in the order defined:

```mermaid
pie showData title Priority Distribution
    "Critical" : 10
    "High" : 25
    "Medium" : 35
    "Low" : 30
```

First defined category ("Critical") appears at 12 o'clock position.

## Configuration Options

### Text Position

Adjust label position with `textPosition` (0.0 = center, 1.0 = outer edge, default 0.75):

```mermaid
%%{init: {'pie': {'textPosition': 0.9}}}%%
pie showData title Deployment Targets
    "Production" : 40
    "Staging" : 30
    "Development" : 20
    "QA" : 10
```

## Use Cases

1. **Resource Allocation** - Visualize budget, time, or compute distribution
2. **Technology Stack** - Show language, framework, or library usage
3. **Error Analysis** - Display error types or failure categories
4. **Performance Metrics** - Represent response time buckets
5. **User Segmentation** - Show user distribution by plan, region, or behavior
6. **Test Coverage** - Illustrate coverage by module or component
7. **Technical Debt** - Categorize debt by type or severity
8. **Sprint Metrics** - Breakdown of task types or story points
9. **API Usage** - Endpoint call distribution
10. **Infrastructure Costs** - Cloud service cost breakdown

## Real-World Scenarios

### Test Coverage by Module

```mermaid
pie showData title Test Coverage Distribution
    "API Layer (95%)" : 35
    "Business Logic (88%)" : 30
    "Data Access (82%)" : 20
    "UI Components (65%)" : 15
```

### CI/CD Pipeline Time

```mermaid
pie showData title Pipeline Execution Time
    "Build & Compile" : 35
    "Unit Tests" : 25
    "Integration Tests" : 20
    "Security Scan" : 15
    "Deployment" : 5
```

### Issue Priority Backlog

```mermaid
pie showData title Issue Backlog by Priority
    "P0 - Critical" : 5
    "P1 - High" : 18
    "P2 - Medium" : 42
    "P3 - Low" : 35
```

### Database Query Types

```mermaid
pie showData title Database Query Distribution
    "SELECT" : 68
    "INSERT" : 18
    "UPDATE" : 10
    "DELETE" : 4
```

## Tips for Effective Pie Charts

1. **Limit categories** - 5-7 slices maximum for readability
2. **Combine small slices** - Merge categories under 5% into "Other"
3. **Order by size** - Largest to smallest (or by priority)
4. **Use showData** - Display exact percentages for precision
5. **Clear labels** - Use descriptive category names
6. **Avoid 3D effects** - Keep it simple and flat (Mermaid does this by default)
7. **Total should make sense** - Ensure values represent parts of a whole
8. **Compare with caution** - Pie charts are best for showing proportions, not comparing absolute values

## When NOT to Use Pie Charts

- **Too many categories** (> 7) - Use bar chart instead
- **Similar values** - Hard to distinguish slice sizes; use table or bar chart
- **Trends over time** - Use line or area chart
- **Precise comparisons** - Use bar chart for easier comparison
- **Negative values** - Not supported; use different chart type

## Alternatives for Common Scenarios

| Scenario | Better Alternative |
|----------|-------------------|
| Many categories (> 7) | Bar chart or table |
| Time series data | Line or area chart |
| Comparing magnitudes | Bar chart |
| Showing trends | Line chart |
| Multiple dimensions | Stacked bar or grouped bar |
