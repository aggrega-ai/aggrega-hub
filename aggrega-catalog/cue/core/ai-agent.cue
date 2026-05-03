// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cognitio S.r.l.

package core

// Topological selectors govern cross-component edge routing
#ModelRef:     string @selector("component.aggrega.ai/type=ai-model")
#ToolRef:      string @selector("component.aggrega.ai/type=ai-tool")
#DatastoreRef: string @selector("component.aggrega.ai/type=ai-datastore")
#AgentRef:     string @selector("component.aggrega.ai/type=ai-agent")

// The Base Agent Parameter every agent inherits
#BaseAgentParameter: core.#BaseComponentParameter & {
	// Most agents require at least one model to act as their brain
	models?: [...#ModelRef]
	
	// Standard array for external functions
	tools_allowed?: [...#ToolRef]
	
	// Standard array for memory/state persistence
	datastores?: [...#DatastoreRef]
	
	// Delegation array
	agents_allowed?: [...#AgentRef]
}
