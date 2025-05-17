```
📊 Compute Hierarchy

Azure Subscription
└── Azure Databricks Workspace
    └── Compute Resources
        ├── Clusters
        │   ├── All-Purpose Clusters (interactive)
        │   └── Job Clusters (automated)
        ├── Pools (pre-warmed VMs)
        └── SQL Warehouses (formerly SQL Endpoints)
```


```
🌐Networking Hierarchy

Azure Virtual Network (VNet)
└── Subnets
    ├── Container Subnet (private)
    │   └── Cluster Nodes
    └── Host Subnet (public)
        └── Cluster Nodes
            └── Network Interfaces (NICs)
                └── Public IP Addresses (via NAT Gateway)
```


```
📦Storage Hierarchy

Azure Subscription
└── Azure Databricks Workspace
    └── Managed Resource Group
        └── Storage Account (DBFS)
            ├── Containers
            │   ├── Notebooks
            │   ├── Libraries
            │   └── Logs
            └── Unity Catalog Volumes
                └── Tables and Views
```

```
Control Plane (Logical) Hierarchy

Azure Databricks Control Plane
└── Workspace
    ├── UI & API Access
    ├── Compute Management
    │   ├── Clusters
    │   ├── Pools
    │   ├── SQL Warehouses
    │   └── Cluster Policies (Governance Layer)
    ├── Unity Catalog
    ├── Apps (Partner / Custom Integrations)
    └── Job Scheduler
```