# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Cognitio S.r.l.
"""A LangGraph checkpoint saver keeping its checkpoints in Valkey or Redis.

It uses plain hashes, sets and sorted sets only, so it runs against a stock
Valkey or Redis server with no module loaded. The layout follows the
in-memory saver LangGraph ships: a checkpoint is stored without its channel
values, each channel value is stored once per version it was written at, and
the writes recorded against a checkpoint are kept beside it. Every key starts
with the prefix the saver is built with.
"""

from __future__ import annotations

import base64
import json
from collections.abc import AsyncIterator, Iterator, Sequence
from typing import Any

import redis
from langchain_core.runnables import RunnableConfig
from langgraph.checkpoint.base import (
    WRITES_IDX_MAP,
    BaseCheckpointSaver,
    ChannelVersions,
    Checkpoint,
    CheckpointMetadata,
    CheckpointTuple,
    get_checkpoint_id,
    get_checkpoint_metadata,
    writes_sort_key,
)


def _key(prefix: str, kind: str, *parts: Any) -> str:
    # The parts are written as one JSON array, so a thread ID or a namespace
    # holding the separator can never make two keys collide.
    return f"{prefix}{kind}:{json.dumps([str(p) for p in parts], separators=(',', ':'))}"


class ValkeySaver(BaseCheckpointSaver[int]):
    """Stores LangGraph checkpoints in a Valkey or Redis server."""

    def __init__(self, client: redis.Redis, *, prefix: str = "quickstart-agent:") -> None:
        super().__init__()
        self.client = client
        self.prefix = prefix

    # Keys.
    def _checkpoint_key(self, thread_id: str, ns: str, checkpoint_id: str) -> str:
        return _key(self.prefix, "checkpoint", thread_id, ns, checkpoint_id)

    def _index_key(self, thread_id: str, ns: str) -> str:
        return _key(self.prefix, "checkpoints", thread_id, ns)

    def _namespaces_key(self, thread_id: str) -> str:
        return _key(self.prefix, "namespaces", thread_id)

    def _threads_key(self) -> str:
        return f"{self.prefix}threads"

    def _blob_key(self, thread_id: str, ns: str, channel: str, version: Any) -> str:
        return _key(self.prefix, "blob", thread_id, ns, channel, version)

    def _blob_index_key(self, thread_id: str) -> str:
        return _key(self.prefix, "blobs", thread_id)

    def _writes_key(self, thread_id: str, ns: str, checkpoint_id: str) -> str:
        return _key(self.prefix, "writes", thread_id, ns, checkpoint_id)

    # Reading.
    def _load_blobs(self, thread_id: str, ns: str, versions: ChannelVersions) -> dict[str, Any]:
        values: dict[str, Any] = {}
        for channel, version in versions.items():
            stored = self.client.hgetall(self._blob_key(thread_id, ns, channel, version))
            if not stored or stored[b"type"] == b"empty":
                continue
            values[channel] = self.serde.loads_typed((stored[b"type"].decode(), stored[b"data"]))
        return values

    def _ordered_writes(self, thread_id: str, ns: str, checkpoint_id: str) -> list[tuple[str, str, Any]]:
        rows = []
        for field, raw in self.client.hgetall(self._writes_key(thread_id, ns, checkpoint_id)).items():
            task_id, channel, kind, data, task_path = json.loads(raw)
            idx = int(field.decode().rsplit("\x00", 1)[1])
            rows.append((writes_sort_key(task_path, task_id, idx), task_id, channel, kind, data))
        rows.sort(key=lambda row: row[0])
        return [
            (task_id, channel, self.serde.loads_typed((kind, base64.b64decode(data))))
            for _, task_id, channel, kind, data in rows
        ]

    def _tuple(self, thread_id: str, ns: str, checkpoint_id: str) -> CheckpointTuple | None:
        stored = self.client.hgetall(self._checkpoint_key(thread_id, ns, checkpoint_id))
        if not stored:
            return None
        checkpoint: Checkpoint = self.serde.loads_typed(
            (stored[b"checkpoint_type"].decode(), stored[b"checkpoint"])
        )
        metadata = self.serde.loads_typed((stored[b"metadata_type"].decode(), stored[b"metadata"]))
        parent = stored.get(b"parent", b"").decode()
        return CheckpointTuple(
            config={"configurable": {"thread_id": thread_id, "checkpoint_ns": ns, "checkpoint_id": checkpoint_id}},
            checkpoint={
                **checkpoint,
                "channel_values": self._load_blobs(thread_id, ns, checkpoint["channel_versions"]),
            },
            metadata=metadata,
            parent_config=(
                {"configurable": {"thread_id": thread_id, "checkpoint_ns": ns, "checkpoint_id": parent}}
                if parent
                else None
            ),
            pending_writes=self._ordered_writes(thread_id, ns, checkpoint_id),
        )

    def _ids_newest_first(self, thread_id: str, ns: str) -> list[str]:
        # Checkpoint IDs grow monotonically as strings, so the index keeps them
        # at one score and the lexicographic order is the order they were taken.
        return [i.decode() for i in self.client.zrevrangebylex(self._index_key(thread_id, ns), "+", "-")]

    def get_tuple(self, config: RunnableConfig) -> CheckpointTuple | None:
        thread_id = str(config["configurable"]["thread_id"])
        ns = config["configurable"].get("checkpoint_ns", "")
        checkpoint_id = get_checkpoint_id(config)
        if not checkpoint_id:
            newest = self._ids_newest_first(thread_id, ns)
            if not newest:
                return None
            checkpoint_id = newest[0]
        return self._tuple(thread_id, ns, checkpoint_id)

    def list(
        self,
        config: RunnableConfig | None,
        *,
        filter: dict[str, Any] | None = None,
        before: RunnableConfig | None = None,
        limit: int | None = None,
    ) -> Iterator[CheckpointTuple]:
        if config:
            thread_ids = [str(config["configurable"]["thread_id"])]
        else:
            thread_ids = sorted(t.decode() for t in self.client.smembers(self._threads_key()))
        wanted_ns = config["configurable"].get("checkpoint_ns") if config else None
        wanted_id = get_checkpoint_id(config) if config else None
        before_id = get_checkpoint_id(before) if before else None
        for thread_id in thread_ids:
            namespaces = sorted(n.decode() for n in self.client.smembers(self._namespaces_key(thread_id)))
            for ns in namespaces:
                if wanted_ns is not None and ns != wanted_ns:
                    continue
                for checkpoint_id in self._ids_newest_first(thread_id, ns):
                    if wanted_id and checkpoint_id != wanted_id:
                        continue
                    if before_id and checkpoint_id >= before_id:
                        continue
                    found = self._tuple(thread_id, ns, checkpoint_id)
                    if found is None:
                        continue
                    if filter and not all(found.metadata.get(k) == v for k, v in filter.items()):
                        continue
                    if limit is not None:
                        if limit <= 0:
                            return
                        limit -= 1
                    yield found

    # Writing.
    def put(
        self,
        config: RunnableConfig,
        checkpoint: Checkpoint,
        metadata: CheckpointMetadata,
        new_versions: ChannelVersions,
    ) -> RunnableConfig:
        thread_id = str(config["configurable"]["thread_id"])
        ns = config["configurable"]["checkpoint_ns"]
        stored = checkpoint.copy()
        values: dict[str, Any] = stored.pop("channel_values")  # type: ignore[misc]
        checkpoint_type, checkpoint_data = self.serde.dumps_typed(stored)
        metadata_type, metadata_data = self.serde.dumps_typed(get_checkpoint_metadata(config, metadata))
        pipe = self.client.pipeline(transaction=True)
        for channel, version in new_versions.items():
            kind, data = self.serde.dumps_typed(values[channel]) if channel in values else ("empty", b"")
            blob = self._blob_key(thread_id, ns, channel, version)
            pipe.hset(blob, mapping={"type": kind, "data": data})
            pipe.sadd(self._blob_index_key(thread_id), blob)
        pipe.hset(
            self._checkpoint_key(thread_id, ns, checkpoint["id"]),
            mapping={
                "checkpoint_type": checkpoint_type,
                "checkpoint": checkpoint_data,
                "metadata_type": metadata_type,
                "metadata": metadata_data,
                "parent": config["configurable"].get("checkpoint_id") or "",
            },
        )
        pipe.zadd(self._index_key(thread_id, ns), {checkpoint["id"]: 0})
        pipe.sadd(self._namespaces_key(thread_id), ns)
        pipe.sadd(self._threads_key(), thread_id)
        pipe.execute()
        return {"configurable": {"thread_id": thread_id, "checkpoint_ns": ns, "checkpoint_id": checkpoint["id"]}}

    def put_writes(
        self,
        config: RunnableConfig,
        writes: Sequence[tuple[str, Any]],
        task_id: str,
        task_path: str = "",
    ) -> None:
        thread_id = str(config["configurable"]["thread_id"])
        ns = config["configurable"].get("checkpoint_ns", "")
        key = self._writes_key(thread_id, ns, config["configurable"]["checkpoint_id"])
        pipe = self.client.pipeline(transaction=True)
        for idx, (channel, value) in enumerate(writes):
            slot = WRITES_IDX_MAP.get(channel, idx)
            kind, data = self.serde.dumps_typed(value)
            row = json.dumps([task_id, channel, kind, base64.b64encode(data).decode(), task_path])
            field = f"{task_id}\x00{slot}"
            # A regular write is recorded once per task and slot, as the
            # in-memory saver records it; a special write replaces the last one.
            if slot >= 0:
                pipe.hsetnx(key, field, row)
            else:
                pipe.hset(key, field, row)
        pipe.execute()

    def delete_thread(self, thread_id: str) -> None:
        thread_id = str(thread_id)
        doomed = [self._namespaces_key(thread_id), self._blob_index_key(thread_id)]
        for ns_raw in self.client.smembers(self._namespaces_key(thread_id)):
            ns = ns_raw.decode()
            for checkpoint_id in self._ids_newest_first(thread_id, ns):
                doomed += [self._checkpoint_key(thread_id, ns, checkpoint_id), self._writes_key(thread_id, ns, checkpoint_id)]
            doomed.append(self._index_key(thread_id, ns))
        doomed += [b.decode() for b in self.client.smembers(self._blob_index_key(thread_id))]
        pipe = self.client.pipeline(transaction=True)
        pipe.delete(*doomed)
        pipe.srem(self._threads_key(), thread_id)
        pipe.execute()

    # The asynchronous forms run the same calls; the agent serves one turn per
    # request thread, so nothing waits on an event loop here.
    async def aget_tuple(self, config: RunnableConfig) -> CheckpointTuple | None:
        return self.get_tuple(config)

    async def alist(
        self,
        config: RunnableConfig | None,
        *,
        filter: dict[str, Any] | None = None,
        before: RunnableConfig | None = None,
        limit: int | None = None,
    ) -> AsyncIterator[CheckpointTuple]:
        for found in self.list(config, filter=filter, before=before, limit=limit):
            yield found

    async def aput(
        self,
        config: RunnableConfig,
        checkpoint: Checkpoint,
        metadata: CheckpointMetadata,
        new_versions: ChannelVersions,
    ) -> RunnableConfig:
        return self.put(config, checkpoint, metadata, new_versions)

    async def aput_writes(
        self,
        config: RunnableConfig,
        writes: Sequence[tuple[str, Any]],
        task_id: str,
        task_path: str = "",
    ) -> None:
        self.put_writes(config, writes, task_id, task_path)

    async def adelete_thread(self, thread_id: str) -> None:
        self.delete_thread(thread_id)
