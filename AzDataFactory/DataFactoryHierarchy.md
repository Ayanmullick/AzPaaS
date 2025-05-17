```
📊 Compute Hierarchy

Azure Subscription
└── Azure Data Factory
    └── Integration Runtimes
        ├── Azure IR (Serverless, Managed by ADF)
        ├── Self-hosted IR (On-premises / VM-hosted)
        └── Azure-SSIS IR (For running SSIS packages)
            └── Azure SQL DB / MI (SSISDB)
```

```
📦Storage Hierarchy

Azure Data Factory
└── Linked Services
    ├── Azure Blob Storage
    ├── Azure Data Lake Storage Gen2
    └── On-premises File Systems (via Self-hosted IR)
        └── Datasets (tables, files, folders)
```

```
🌐Networking Hierarchy

Virtual Network (Optional)
└── Subnets
    ├── Self-hosted IR VM (for on-prem/hybrid integration)
    ├── Azure-SSIS IR (joins subnet during creation)
    └── Private Endpoints (for Data Factory and data sources)
```


```
Control Plane (Logical) Hierarchy

Azure Data Factory
└── Pipelines
    ├── Activities
    │   ├── Data Movement (Copy Activity)
    │   ├── Data Transformation (Mapping Data Flows, Wrangling)
    │   ├── Control Flow (If, ForEach, Switch)
    │   └── External Execution (Databricks, Synapse, Functions)
    ├── Triggers
    │   ├── Schedule Trigger
    │   ├── Tumbling Window Trigger
    │   └── Event-Based Trigger
    ├── Parameters & Variables
    └── Monitoring & Alerts
```


```
Governance Layer

Azure Data Factory
└── Access Control (IAM + ADF RBAC)
    ├── Reader / Contributor / Data Factory Contributor
    ├── ARM-level Role Assignments
    └── Managed Identity
        └── Used for Linked Services, Key Vault access
```