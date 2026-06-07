# Gantt Charts

Gantt charts visualize project schedules, showing tasks, durations, dependencies, and milestones. Essential for project planning and tracking.

## Basic Syntax

```mermaid
gantt
    title Project Schedule
    dateFormat YYYY-MM-DD

    section Phase 1
    Task A :a1, 2024-01-01, 30d
    Task B :after a1, 20d
```

## Task Definition

### Basic Task Syntax

```
taskName : [tags], [startDate], [endDate or duration]
```

```mermaid
gantt
    title Development Timeline
    dateFormat YYYY-MM-DD

    section Setup
    Initialize project :2024-01-01, 5d
    Setup CI/CD       :2024-01-06, 10d
```

### Task with ID

```mermaid
gantt
    title Sprint Planning
    dateFormat YYYY-MM-DD

    section Backend
    API Design     :api, 2024-01-01, 7d
    Implementation :impl, after api, 14d
    Testing        :after impl, 7d
```

## Task States and Tags

### Active Tasks

```mermaid
gantt
    title Current Sprint
    dateFormat YYYY-MM-DD

    section In Progress
    Feature A :active, 2024-01-01, 10d
    Feature B :active, 2024-01-05, 12d
```

### Completed Tasks

```mermaid
gantt
    title Project Progress
    dateFormat YYYY-MM-DD

    section Completed
    Research    :done, 2024-01-01, 7d
    Design      :done, 2024-01-08, 10d

    section Current
    Development :active, 2024-01-18, 20d
```

### Critical Path

```mermaid
gantt
    title Critical Tasks
    dateFormat YYYY-MM-DD

    section Core Features
    User Auth    :crit, 2024-01-01, 14d
    Database     :crit, 2024-01-15, 10d

    section Nice-to-Have
    Dashboard    :2024-01-15, 15d
    Reporting    :2024-02-01, 10d
```

### Milestones

```mermaid
gantt
    title Release Milestones
    dateFormat YYYY-MM-DD

    section Development
    Alpha Release :milestone, 2024-02-01, 0d
    Beta Release  :milestone, 2024-03-01, 0d
    GA Release    :milestone, 2024-04-01, 0d
```

## Dependencies

### Sequential Tasks

```mermaid
gantt
    title Build Pipeline
    dateFormat YYYY-MM-DD

    section Build
    Compile       :a1, 2024-01-01, 2d
    Run Tests     :a2, after a1, 3d
    Package       :a3, after a2, 1d
    Deploy Staging:after a3, 2d
```

### Multiple Dependencies

```mermaid
gantt
    title Feature Development
    dateFormat YYYY-MM-DD

    section Backend
    API Schema  :api, 2024-01-01, 5d
    API Impl    :apiImpl, after api, 10d

    section Frontend
    UI Mockup   :ui, 2024-01-01, 7d
    Component   :comp, after ui, 8d

    section Integration
    Integration :after apiImpl, after comp, 5d
```

### Until Keyword

```mermaid
gantt
    title Overlapping Tasks
    dateFormat YYYY-MM-DD

    section Development
    Feature A :a1, 2024-01-01, 20d
    Feature B :a2, 2024-01-10, until a1
```

## Sections

```mermaid
gantt
    title Full-Stack Development
    dateFormat YYYY-MM-DD

    section Planning
    Requirements :2024-01-01, 7d
    Architecture :2024-01-08, 5d

    section Backend
    API Development  :2024-01-13, 20d
    Database Schema  :2024-01-13, 15d

    section Frontend
    Component Library:2024-02-01, 15d
    Pages            :2024-02-16, 20d

    section Testing
    Unit Tests    :2024-03-01, 10d
    Integration   :2024-03-11, 7d
    E2E Tests     :2024-03-18, 5d
```

## Date Formats

### Custom Date Format

```mermaid
gantt
    title Custom Format
    dateFormat DD-MM-YYYY

    section Tasks
    Task 1 :01-01-2024, 10d
    Task 2 :11-01-2024, 15d
```

### Axis Format

```mermaid
gantt
    title Axis Formatting
    dateFormat YYYY-MM-DD
    axisFormat %m/%d

    section Q1
    January   :2024-01-01, 31d
    February  :2024-02-01, 29d
    March     :2024-03-01, 31d
```

### Tick Intervals

```mermaid
gantt
    title Weekly View
    dateFormat YYYY-MM-DD
    tickInterval 1week

    section Sprint 1
    Task A :2024-01-01, 2w
    Task B :2024-01-15, 2w
```

## Excluding Days

### Weekends

```mermaid
gantt
    title Business Days Only
    dateFormat YYYY-MM-DD
    excludes weekends

    section Work
    Development :2024-01-01, 10d
    Testing     :2024-01-15, 5d
```

### Specific Dates

```mermaid
gantt
    title Holiday Schedule
    dateFormat YYYY-MM-DD
    excludes 2024-01-01, 2024-12-25, weekends

    section Q1
    Project Phase 1 :2024-01-02, 30d
    Project Phase 2 :2024-02-15, 30d
```

## Today Marker

```mermaid
gantt
    title Current Progress
    dateFormat YYYY-MM-DD

    section Completed
    Phase 1 :done, 2024-01-01, 15d

    section Current
    Phase 2 :active, 2024-01-16, 20d

    section Upcoming
    Phase 3 :2024-02-15, 15d
```

### Hiding Today Marker

```mermaid
gantt
    title Static Schedule
    dateFormat YYYY-MM-DD
    todayMarker off

    section Tasks
    Task 1 :2024-01-01, 10d
    Task 2 :2024-01-11, 10d
```

## Display Modes

### Compact Mode

```mermaid
gantt
    title Compact View
    dateFormat YYYY-MM-DD
    displayMode compact

    section Backend
    Task 1 :2024-01-01, 10d
    Task 2 :2024-01-11, 10d
    Task 3 :2024-01-21, 10d

    section Frontend
    Task 4 :2024-01-01, 15d
    Task 5 :2024-01-16, 15d
```

## Interactive Features

### Click Events

```mermaid
gantt
    title Interactive Gantt
    dateFormat YYYY-MM-DD

    section Tasks
    Task A :task1, 2024-01-01, 10d
    Task B :task2, 2024-01-11, 10d

    click task1 href "https://example.com/task1"
    click task2 call handleTaskClick()
```

## Use Cases

### Sprint Planning

```mermaid
gantt
    title Sprint 42 - Two Week Sprint
    dateFormat YYYY-MM-DD
    excludes weekends

    section Planning
    Sprint Planning :milestone, 2024-01-15, 0d

    section Backend Stories
    User Authentication :crit, auth, 2024-01-15, 5d
    API Rate Limiting   :after auth, 3d

    section Frontend Stories
    Login UI         :crit, ui, 2024-01-15, 4d
    Dashboard Layout :after ui, 4d

    section Testing
    Unit Tests       :2024-01-22, 2d
    Integration Tests:2024-01-24, 2d

    section Review
    Sprint Review    :milestone, 2024-01-26, 0d
```

### Product Launch Roadmap

```mermaid
gantt
    title Product Launch Roadmap
    dateFormat YYYY-MM-DD

    section Alpha
    MVP Development  :crit, 2024-01-01, 60d
    Internal Testing :2024-03-01, 20d
    Alpha Release    :milestone, 2024-03-20, 0d

    section Beta
    Feature Complete  :crit, 2024-03-20, 40d
    Beta Testing      :2024-04-29, 30d
    Bug Fixes         :crit, 2024-05-29, 15d
    Beta Release      :milestone, 2024-05-29, 0d

    section GA
    Performance Tuning:2024-06-13, 15d
    Documentation     :2024-06-13, 20d
    Marketing Prep    :2024-06-28, 10d
    GA Release        :milestone, crit, 2024-07-08, 0d
```

### Migration Project

```mermaid
gantt
    title Database Migration
    dateFormat YYYY-MM-DD
    excludes weekends

    section Planning
    Impact Analysis    :done, 2024-01-01, 10d
    Migration Strategy :done, 2024-01-15, 7d

    section Preparation
    Schema Design      :crit, schema, 2024-01-22, 14d
    Test Environment   :after schema, 5d
    Migration Scripts  :crit, after schema, 10d

    section Testing
    Test Run 1         :2024-02-19, 3d
    Fix Issues         :2024-02-22, 5d
    Test Run 2         :2024-02-27, 3d
    Go/No-Go           :milestone, 2024-03-01, 0d

    section Execution
    Backup Production  :crit, 2024-03-02, 1d
    Run Migration      :crit, 2024-03-03, 1d
    Verify Data        :crit, 2024-03-04, 2d
    Rollback Plan      :2024-03-02, 4d

    section Post-Migration
    Monitoring         :2024-03-06, 7d
    Cleanup            :2024-03-13, 3d
```

### Dependency Resolution Example

```mermaid
gantt
    title Microservices Deployment
    dateFormat YYYY-MM-DD

    section Infrastructure
    Provision Cluster :infra, 2024-01-01, 5d
    Setup Monitoring  :mon, after infra, 3d

    section Core Services
    Auth Service      :crit, auth, after infra, 7d
    User Service      :user, after auth, 7d

    section Feature Services
    Payment Service   :pay, after user, 10d
    Notification Svc  :notif, after user, 8d

    section Integration
    API Gateway       :after auth, after mon, 5d
    E2E Tests         :after pay, after notif, 5d

    section Deployment
    Staging Deploy    :milestone, after pay, after notif, 0d
    Production Deploy :milestone, crit, 2024-02-15, 0d
```

## Tips for Effective Gantt Charts

1. **Use sections** - Group related tasks logically
2. **Mark critical path** - Highlight must-complete tasks with `crit`
3. **Show milestones** - Mark important dates with `milestone`
4. **Exclude non-working days** - Use `excludes weekends` for realism
5. **Task dependencies** - Use `after` to show relationships
6. **Appropriate granularity** - Don't over-detail; focus on key activities
7. **Progress tracking** - Use `done` and `active` tags to show status
