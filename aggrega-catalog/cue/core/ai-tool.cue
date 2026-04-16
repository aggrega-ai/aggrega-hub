// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cognitio S.r.l.

package core

// #BaseToolParameter defines the security and execution boundaries for all tools.
#BaseToolParameter: core.#BaseComponentParameter & {
	// Critical for Zero-Trust: Does this tool mutate external state?
	// SECURE BY DEFAULT: Assume all tools mutate state unless explicitly downgraded.
	side_effects: *"mutating" | "read_only" | "none"

	// Hard timeout to prevent agents from hanging indefinitely on bad API calls
	timeout_seconds: int | *30
	
	// Optional description override to pass to the LLM (overriding the tool's default prompt)
	llm_description_override?: string
}