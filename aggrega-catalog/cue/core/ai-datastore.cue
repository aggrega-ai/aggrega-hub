// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cognitio S.r.l.

package core

// 1. The pure base that applies to EVERY ai-datastore
#BaseDatastoreParameter: core.#BaseComponentParameter & {
    engine: string
    storage_tier: *"nvme" | "ssd" | "hdd"
    
    // Optional scaling parameters
    replicas?: int & >=1
}

// 2. The extended schema for Vector Databases (Qdrant, Milvus, Pinecone)
#VectorDatastoreParameter: #BaseDatastoreParameter & {
    vector_config: {
        dimensions:      int & >0
        distance_metric: *"cosine" | "euclidean" | "dot"
    }
}

// 3. The extended schema for Graph Databases (Neo4j, Memgraph)
#GraphDatastoreParameter: #BaseDatastoreParameter & {
    graph_config?: {
        strict_schema: bool | *false
    }
}