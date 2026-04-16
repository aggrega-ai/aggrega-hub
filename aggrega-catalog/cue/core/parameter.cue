// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cognitio S.r.l.

package core

// #BaseComponentParameter is shared optional documentation for all component definitions.
#BaseComponentParameter: {
    displayName?: string
    description?: string
}

// #BaseFeatureParameter is shared optional documentation for all feature definitions.
#BaseFeatureParameter: {
    displayName?: string
    description?: string
    severity?:    *"info" | "warning" | "critical"
    
    // The Universal Injection Contract (Strictly for Features, never Components)
    as?: {
        env?:  string
        file?: string
        arg?:  string
    }
}