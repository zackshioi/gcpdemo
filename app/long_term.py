"""Long-term memory: user-scoped facts in Vertex AI Memory Bank (Agent Engine).

google-genai 2.7.0 has no agent_engines API, so per ADR-006 we use the `vertexai`
SDK for Memory Bank (chat stays on google-genai). Memory Bank extracts durable
facts from a conversation using gemini-2.5-flash (asynchronously) and retrieves
them by `scope={"user_id": ...}` — so they persist across sessions and browsers.

The Agent Engine instance is created out-of-band (no Terraform resource exists);
its resource name is passed in via AGENT_ENGINE_ID. See docs/RUNBOOK.md.
"""

import os
from functools import lru_cache

import vertexai


@lru_cache(maxsize=1)
def _client() -> vertexai.Client:
    return vertexai.Client(
        project=os.environ["GCP_PROJECT"],
        location=os.environ.get("GCP_LOCATION", "us-central1"),
    )


def _engine() -> str:
    # Full resource name: projects/<n>/locations/<r>/reasoningEngines/<id>
    return os.environ["AGENT_ENGINE_ID"]


def enabled() -> bool:
    """Long-term memory degrades gracefully if the Agent Engine isn't configured
    (e.g. a deploy lands before infra sets AGENT_ENGINE_ID) — chat still works."""
    return bool(os.environ.get("AGENT_ENGINE_ID"))


def retrieve(user_id: str) -> list[str]:
    """Return the user's long-term facts. Simple retrieval = all of them (fine
    for a demo); at scale you'd pass similarity_search_params with the current
    message to fetch only the most relevant."""
    if not enabled():
        return []
    it = _client().agent_engines.memories.retrieve(
        name=_engine(),
        scope={"user_id": user_id},
        simple_retrieval_params={"page_size": 20},
    )
    facts = []
    for m in it:
        fact = getattr(getattr(m, "memory", None), "fact", None)
        if fact:
            facts.append(fact)
    return facts


def generate(user_id: str, turn: list[dict]) -> None:
    """Submit async memory extraction for a conversation turn. `turn` is
    [{role, text}, ...]; Memory Bank extracts/consolidates facts in the
    background (returns immediately after submitting the operation)."""
    if not enabled():
        return
    events = [
        {"content": {"role": m["role"], "parts": [{"text": m["text"]}]}}
        for m in turn
    ]
    _client().agent_engines.memories.generate(
        name=_engine(),
        direct_contents_source={"events": events},
        scope={"user_id": user_id},
    )
