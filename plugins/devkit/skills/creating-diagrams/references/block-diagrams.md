# Block Diagrams

Block diagrams allow precise control over layout and positioning of components. They are ideal for representing system architectures, network topologies, and infrastructure designs where spatial relationships matter.

## Basic Syntax

```mermaid
block-beta
    columns 3
    a["Frontend"] b["API"] c["Database"]
```

## Columns and Layout

Control the grid layout using `columns` directive:

```mermaid
block-beta
    columns 4
    a["Web"] b["API Gateway"] c["Service"] d["Database"]
    e["CDN"] f["Cache"]:2 g["Queue"]

    a --> b
    b --> c
    c --> d
```

**Spanning multiple columns:**
- `id["Label"]:N` - Block spans N columns

## Block Shapes

```mermaid
block-beta
    columns 3
    a["Square"]
    b("Round Edges")
    c(["Stadium"])
    d[["Subroutine"]]
    e[("Cylinder")]
    f(("Circle"))
    g{"Rhombus"}
    h{{"Hexagon"}}
    i[/"Parallelogram"/]
    j[\"Trapezoid"\]
    k((("Double Circle")))
```

**Shape syntax:**
- `["Label"]` - Square (default)
- `("Label")` - Round edges
- `(["Label"])` - Stadium
- `[["Label"]]` - Subroutine
- `[("Label")]` - Cylinder
- `(("Label"))` - Circle
- `{"Label"}` - Rhombus
- `{{"Label"}}` - Hexagon
- `[/"Label"/]` - Parallelogram
- `[\"Label"\]` - Trapezoid
- `((("Label")))` - Double circle

## Connections

```mermaid
block-beta
    columns 3
    Frontend --> API
    API --> Database
    API --- Cache
    Frontend -->|"HTTPS"| API
    API -->|"Query"| Database
```

**Connection types:**
- `-->` - Arrow
- `---` - Line (no arrow)
- `-->|"label"|` - Arrow with label

## Nested Blocks

Create hierarchical structures using indentation:

```mermaid
block-beta
    columns 2

    block:frontend["Frontend Layer"]
        columns 2
        web["Web App"]
        mobile["Mobile App"]
    end

    block:backend["Backend Layer"]
        columns 2
        api["API Gateway"]
        service["Services"]
    end

    web --> api
    mobile --> api
```

## Spaces

Use `space` to create empty cells for layout control:

```mermaid
block-beta
    columns 5
    a["Load Balancer"]
    space
    b["Server 1"]
    c["Server 2"]
    d["Server 3"]

    a --> b
    a --> c
    a --> d
```

**Space width:**
- `space` - 1 column
- `space:N` - N columns

## Styling

Apply custom styles to blocks:

```mermaid
block-beta
    columns 3
    a["Web Server"]
    b["Application"]
    c["Database"]

    style a fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    style b fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    style c fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
```

**Style properties:**
- `fill` - Background color
- `stroke` - Border color
- `stroke-width` - Border width

## Class-Based Styling

Define reusable styles:

```mermaid
block-beta
    columns 3

    classDef frontend fill:#e1f5ff,stroke:#01579b
    classDef backend fill:#f3e5f5,stroke:#4a148c
    classDef database fill:#e8f5e9,stroke:#1b5e20

    a["React App"]:::frontend
    b["Node.js API"]:::backend
    c["PostgreSQL"]:::database

    a --> b
    b --> c
```

## Comprehensive Example: Microservices Architecture

```mermaid
block-beta
    columns 5

    %% Client layer
    block:clients["Client Layer"]
        columns 2
        web["Web App"]
        mobile["Mobile App"]
    end

    space

    %% Gateway
    gateway["API Gateway"]:2

    space

    %% Service layer
    block:services["Service Layer"]
        columns 3
        auth["Auth Service"]
        user["User Service"]
        order["Order Service"]
    end

    %% Infrastructure
    cache["Redis Cache"]:2
    db1["User DB"]
    db2["Order DB"]

    queue["Message Queue"]
    monitor["Monitoring"]

    %% Connections
    web --> gateway
    mobile --> gateway

    gateway --> auth
    gateway --> user
    gateway --> order

    auth --> cache
    user --> cache
    user --> db1
    order --> db2
    order --> queue

    classDef clientStyle fill:#e1f5ff,stroke:#01579b
    classDef serviceStyle fill:#f3e5f5,stroke:#4a148c
    classDef dataStyle fill:#e8f5e9,stroke:#1b5e20
    classDef infraStyle fill:#fff3e0,stroke:#e65100

    class web,mobile clientStyle
    class auth,user,order serviceStyle
    class db1,db2 dataStyle
    class cache,queue,monitor infraStyle
```

## Network Topology Example

```mermaid
block-beta
    columns 5

    internet["Internet"]:5

    space
    firewall["Firewall"]
    space:3

    space
    router["Router"]
    space:3

    dmz["DMZ"]
    space
    internal["Internal Network"]
    space:2

    web["Web Server"]
    space
    app1["App Server 1"]
    app2["App Server 2"]
    db["Database"]

    internet --> firewall
    firewall --> router
    router --> web
    router --> app1
    router --> app2
    app1 --> db
    app2 --> db

    style internet fill:#ff8a80,stroke:#c62828
    style firewall fill:#ffd54f,stroke:#f57f17
    style dmz fill:#a5d6a7,stroke:#2e7d32
    style internal fill:#90caf9,stroke:#1565c0
```

## Cloud Infrastructure Example

```mermaid
block-beta
    columns 4

    block:cloud["AWS Cloud"]
        columns 4

        block:vpc["VPC"]
            columns 4

            lb["Load Balancer"]:4

            block:public["Public Subnet"]
                columns 2
                nat["NAT Gateway"]
                bastion["Bastion Host"]
            end

            space:2

            block:private["Private Subnet"]
                columns 2
                ec2_1["EC2 Instance 1"]
                ec2_2["EC2 Instance 2"]
            end

            rds["RDS Database"]
            s3["S3 Bucket"]
        end
    end

    lb --> ec2_1
    lb --> ec2_2
    ec2_1 --> rds
    ec2_2 --> rds
    ec2_1 --> s3
    ec2_2 --> s3

    classDef cloudStyle fill:#ff9800,stroke:#e65100
    classDef networkStyle fill:#03a9f4,stroke:#01579b
    classDef computeStyle fill:#4caf50,stroke:#1b5e20
    classDef storageStyle fill:#9c27b0,stroke:#4a148c

    class vpc cloudStyle
    class lb,nat networkStyle
    class ec2_1,ec2_2,bastion computeStyle
    class rds,s3 storageStyle
```

## Tips for Effective Block Diagrams

1. **Use columns strategically** - Plan your grid layout before adding blocks
2. **Leverage spaces** - Create visual separation between logical groups
3. **Nest for hierarchy** - Use nested blocks to show system layers or boundaries
4. **Choose appropriate shapes** - Cylinder for databases, rhombus for decision points
5. **Style by category** - Use classDef to distinguish component types
6. **Label connections** - Add context with edge labels for important flows
7. **Think spatially** - Block diagrams give you full control - use it to convey structure

## Common Use Cases

### System Architecture
- Show component relationships
- Illustrate data flow
- Document deployment topology

### Network Design
- Map network segments
- Show firewall rules
- Document routing

### Infrastructure as Code
- Visualize Terraform/CloudFormation resources
- Show resource dependencies
- Document security groups and subnets
