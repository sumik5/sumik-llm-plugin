# Timeline Diagrams

Timeline diagrams visualize events across time periods. They help track project milestones, historical events, and roadmap phases in a clear chronological format.

## Basic Syntax

```mermaid
timeline
    title Project Development Timeline
    2023 : Project kickoff
    2024 : Beta release
    2025 : Production launch
```

## Time Periods and Events

Each event is associated with a time period:

```mermaid
timeline
    title Software Release Cycle
    Q1 2024 : Planning and requirements gathering
             : Team formation
    Q2 2024 : Development sprint 1
             : Infrastructure setup
    Q3 2024 : Beta testing
             : Security audit
    Q4 2024 : Production deployment
             : Post-launch monitoring
```

**Syntax:**
- `{time period} : {event}` - Single event
- Multiple events can be added with additional `:` or on new lines with leading `:`

## Sections

Group related time periods into sections:

```mermaid
timeline
    title Product Development Journey
    section Research Phase
        2023-Q1 : Market research
                : Competitive analysis
        2023-Q2 : User interviews
                : Prototype design
    section Development Phase
        2023-Q3 : MVP development
                : Internal testing
        2023-Q4 : Feature expansion
    section Launch Phase
        2024-Q1 : Beta testing
        2024-Q2 : Public launch
```

## Real-World Example: Feature Development

```mermaid
timeline
    title Authentication Feature Timeline
    section Planning
        Week 1 : Requirements gathering
               : Security standards review
        Week 2 : Architecture design
               : Technology selection
    section Development
        Week 3 : OAuth2 integration
               : JWT token implementation
        Week 4 : Password hashing
               : Session management
        Week 5 : MFA setup
    section Testing & Launch
        Week 6 : Security testing
               : Penetration testing
        Week 7 : Staging deployment
        Week 8 : Production rollout
               : Monitoring setup
```

## Text Formatting

Force line breaks with `<br>`:

```mermaid
timeline
    title API Migration
    2024-01 : REST API v1 <br> (Legacy)
    2024-03 : GraphQL API <br> (New architecture)
    2024-06 : REST API v1 <br> Deprecated
```

## Styling

### Multi-Color Mode (Default)

Each time period automatically gets a different color:

```mermaid
timeline
    title Multi-Color Example
    Phase 1 : Event A
    Phase 2 : Event B
    Phase 3 : Event C
    Phase 4 : Event D
```

### Uniform Color Mode

Disable multi-color for consistent appearance:

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'cScale0':'#ff6b6b', 'cScaleLabel0':'#ffffff'}}}%%
timeline
    disableMulticolor
    title Uniform Color Timeline
    2023 : Event A
    2024 : Event B
    2025 : Event C
```

### Custom Colors

```mermaid
%%{init: {
  'theme': 'base',
  'themeVariables': {
    'cScale0': '#3498db',
    'cScale1': '#2ecc71',
    'cScale2': '#e74c3c',
    'cScaleLabel0': '#ffffff',
    'cScaleLabel1': '#ffffff',
    'cScaleLabel2': '#ffffff'
  }
}}%%
timeline
    title Custom Styled Timeline
    Development : Backend API
    Testing : Integration tests
    Deployment : Production release
```

**Available custom variables:**
- `cScale0` to `cScale11` - Background colors for time periods
- `cScaleLabel0` to `cScaleLabel11` - Text colors for labels

## Themes

```mermaid
%%{init: {'theme':'dark'}}%%
timeline
    title Dark Theme Example
    2023 : Planning
    2024 : Development
    2025 : Launch
```

**Available themes:** `base`, `forest`, `dark`, `default`, `neutral`

## Use Cases

1. **Project Roadmaps** - Visualize quarterly or annual plans
2. **Sprint Planning** - Show sprint milestones and deliverables
3. **Release Schedules** - Track feature releases over time
4. **Migration Projects** - Display phased migration steps
5. **Team Onboarding** - Outline onboarding phases
6. **Technical Debt Reduction** - Plan incremental improvements
7. **API Versioning** - Show version lifecycle (active, deprecated, sunset)

## Tips for Effective Timelines

1. **Keep time periods consistent** - Use the same granularity (weeks, months, quarters)
2. **Group related events** - Use sections to organize complex timelines
3. **Limit events per period** - 2-4 events per time period for readability
4. **Use descriptive labels** - Clear, action-oriented event descriptions
5. **Include context** - Add section headers to explain phases
6. **Consider audience** - Adjust detail level based on stakeholders
