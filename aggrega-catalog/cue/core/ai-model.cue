// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cognitio S.r.l.

package core

#BaseModelParameter: core.#BaseComponentParameter & {
    // The specific model string expected by the provider (e.g., "gpt-4o", "meta-llama/Llama-3-70b")
    model: string
    
    // Optional: The developer's intended context window limit (Ops can use this to size vLLM max_model_len)
    context_window?: int & >=0
}