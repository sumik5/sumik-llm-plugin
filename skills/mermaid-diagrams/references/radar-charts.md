# Radar Charts

Radar charts (also called spider charts or web charts) visualize multi-dimensional data with multiple axes radiating from a center point. They're useful for comparing multiple entities across the same set of metrics.

## Basic Syntax

```mermaid
radar-beta
    title Team Skill Assessment
    axis Design, Frontend, Backend, DevOps, Testing
    curve "Senior Dev"{8, 9, 9, 7, 8}
    curve "Junior Dev"{5, 7, 4, 3, 6}
```

## Axis Definition

### Simple Axis Labels

```mermaid
radar-beta
    title Technology Stack Proficiency
    axis React, TypeScript, Node.js, PostgreSQL, Docker
    curve "Team A"{9, 8, 7, 6, 8}
    curve "Team B"{7, 9, 8, 7, 9}
```

### Axis with Custom IDs and Labels

```mermaid
radar-beta
    title Code Quality Metrics
    axis perf["Performance"], sec["Security"], maint["Maintainability"], docs["Documentation"], test["Test Coverage"]
    curve "Service A"{8, 7, 9, 6, 8}
    curve "Service B"{6, 9, 7, 8, 9}
```

## Data Curves

### Sequential Values

Provide values in the same order as axes:

```mermaid
radar-beta
    title Sprint Velocity Comparison
    axis Planning, Development, Testing, Review, Deployment
    curve "Sprint 1"{7, 8, 6, 7, 8}
    curve "Sprint 2"{8, 9, 8, 9, 9}
    curve "Sprint 3"{9, 9, 9, 8, 9}
```

### Key-Value Mapping

Explicitly map values to specific axes:

```mermaid
radar-beta
    title Team Performance
    axis axis1["Code Quality"], axis2["Speed"], axis3["Collaboration"]
    curve team1["Alpha Team"]{axis1: 90, axis2: 75, axis3: 85}
    curve team2["Beta Team"]{axis2: 90, axis1: 80, axis3: 70}
```

## Display Configuration

### Legend and Scale

```mermaid
radar-beta
    title Performance Benchmarks
    showLegend: true
    max: 100
    min: 0
    axis Latency, Throughput, CPU, Memory, Disk
    curve "Before Optimization"{45, 60, 70, 65, 50}
    curve "After Optimization"{80, 85, 75, 80, 85}
```

### Graticule Type and Ticks

```mermaid
radar-beta
    title System Health Score
    graticule: polygon
    ticks: 10
    axis Availability, Response Time, Error Rate, Resource Usage, Security
    curve "Production"{95, 90, 88, 85, 92}
    curve "Staging"{85, 80, 75, 70, 85}
```

**Options:**
- `graticule`: `circle` (default) or `polygon`
- `ticks`: Number of concentric divisions (default: 5)

## Size and Margin

```mermaid
radar-beta
    title API Performance Metrics
    width: 600
    height: 450
    marginTop: 20
    marginBottom: 20
    marginLeft: 60
    marginRight: 60
    axis Latency, Throughput, Error Rate, Cache Hit, CPU
    curve "API v1"{70, 65, 60, 55, 70}
    curve "API v2"{85, 80, 75, 85, 65}
```

## Advanced Styling

### Axis Scaling

```mermaid
radar-beta
    title Code Metrics (Scaled)
    axisScaleFactor: 1.2
    axisLabelFactor: 1.1
    axis Complexity, Coverage, Duplication, Dependencies, Documentation
    curve "Module A"{7, 9, 8, 6, 7}
    curve "Module B"{6, 8, 9, 7, 8}
```

### Curve Tension

Adjust smoothness of curves:

```mermaid
radar-beta
    title System Maturity Assessment
    curveTension: 0.5
    axis Architecture, Testing, CI/CD, Monitoring, Security
    curve "Microservice A"{8, 9, 9, 8, 7}
    curve "Microservice B"{6, 7, 8, 9, 8}
```

## Theme Customization

Radar charts support theme variables for customization:

```javascript
%%{
  init: {
    'themeVariables': {
      'cScale0': '#ff6384',
      'cScale1': '#36a2eb',
      'cScale2': '#ffce56',
      'axisColor': '#666',
      'axisStrokeWidth': '2',
      'curveOpacity': '0.3',
      'graticuleColor': '#ccc'
    }
  }
}%%
```

**Available theme variables:**
- `cScale0` to `cScale12`: Curve colors
- `axisColor`: Axis line color
- `axisStrokeWidth`: Thickness of axis lines
- `curveOpacity`: Transparency of curve fill
- `curveStrokeWidth`: Thickness of curve outline
- `graticuleColor`: Background grid color
- `graticuleStrokeWidth`: Grid line thickness

## Use Cases in Software Development

### Team Skill Gap Analysis

Compare team members' proficiency across technical areas to identify training needs:

```mermaid
radar-beta
    title Full-Stack Skills Assessment
    axis React, Node.js, PostgreSQL, AWS, Docker, Git
    curve "Developer A"{9, 7, 8, 6, 7, 9}
    curve "Developer B"{6, 9, 9, 8, 8, 8}
    curve "Developer C"{8, 8, 6, 7, 9, 9}
```

### Architecture Quality Evaluation

Assess different service architectures against quality attributes:

```mermaid
radar-beta
    title Microservice Architecture Quality
    axis Scalability, Maintainability, Performance, Security, Observability
    curve "User Service"{9, 8, 9, 8, 7}
    curve "Order Service"{8, 7, 8, 9, 9}
    curve "Payment Service"{7, 9, 7, 9, 8}
```

### Sprint Health Metrics

Track agile team health across multiple dimensions:

```mermaid
radar-beta
    title Sprint Health Comparison
    axis Velocity, Quality, Collaboration, Documentation, Technical Debt
    curve "Sprint 5"{7, 8, 9, 6, 7}
    curve "Sprint 6"{8, 9, 8, 7, 8}
    curve "Sprint 7"{9, 9, 9, 8, 9}
```

### Technology Stack Comparison

Evaluate competing technology stacks for a project:

```mermaid
radar-beta
    title Technology Stack Evaluation
    max: 10
    axis Performance, Community, Learning Curve, Ecosystem, Maturity, Cost
    curve "Stack A (MERN)"{8, 9, 6, 9, 9, 9}
    curve "Stack B (Django)"{9, 8, 7, 8, 10, 8}
    curve "Stack C (Rails)"{7, 7, 8, 7, 10, 7}
```

### Code Quality Dashboard

Monitor multiple quality metrics across services:

```mermaid
radar-beta
    title Service Code Quality
    max: 100
    axis Test Coverage, Cyclomatic Complexity, Duplication, Maintainability, Documentation
    curve "Auth Service"{95, 85, 90, 88, 80}
    curve "API Gateway"{90, 90, 85, 92, 85}
    curve "Data Pipeline"{80, 75, 70, 78, 75}
```

### Security Posture Assessment

Compare security metrics across different environments:

```mermaid
radar-beta
    title Security Compliance Score
    axis Authentication, Authorization, Encryption, Audit Logging, Vulnerability Scanning
    curve "Production"{95, 90, 100, 85, 90}
    curve "Staging"{85, 85, 90, 80, 85}
    curve "Development"{70, 75, 80, 60, 70}
```

## Tips for Effective Radar Charts

1. **Limit axes to 5-7** - Too many dimensions make the chart hard to read
2. **Use consistent scales** - Ensure all axes use the same scale range
3. **Compare 2-4 entities** - More curves create visual clutter
4. **Normalize data** - Convert different units to a common scale (e.g., 0-100)
5. **Order axes logically** - Group related metrics together
6. **Label clearly** - Use descriptive axis names
7. **Show legend** - Enable `showLegend: true` when comparing multiple curves
8. **Consider polygon graticule** - Works well for symmetrical data
