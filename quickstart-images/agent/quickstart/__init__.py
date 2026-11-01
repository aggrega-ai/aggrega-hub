# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Cognitio S.r.l.
"""The quickstart agent: a small LangGraph conversation agent.

It answers each turn through an OpenAI-compatible model endpoint and keeps
every conversation's state in a Valkey or Redis store, so a conversation
continues where it stopped after the agent restarts.
"""
