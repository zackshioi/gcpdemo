"""Gemini access via the google-genai SDK on Vertex AI.

One client, one call. F1 is single-turn (no memory) — F2 adds session history
and F3 adds long-term memory to the prompt assembled here.

Auth is Application Default Credentials (ADC): locally it picks up
`gcloud auth application-default login`; on Cloud Run it uses the service
account. No API keys, no JSON keys.
"""

import os
from functools import lru_cache

from google import genai

MODEL = "gemini-2.5-flash"


@lru_cache(maxsize=1)
def _client() -> genai.Client:
    # vertexai=True routes to Vertex AI (enterprise IAM/region), NOT the
    # AI Studio API-key path. project/location come from the environment.
    return genai.Client(
        vertexai=True,
        project=os.environ["GCP_PROJECT"],
        location=os.environ.get("GCP_LOCATION", "us-central1"),
    )


def generate(history: list[dict], memories: list[str] | None = None) -> str:
    """Multi-turn completion. `history` is [{role, text}, ...] oldest-first with
    the latest user message appended. Long-term `memories` (F3) are injected as a
    system instruction so the model "knows" the user across sessions."""
    contents = [{"role": m["role"], "parts": [{"text": m["text"]}]} for m in history]
    config = None
    if memories:
        facts = "\n".join(f"- {m}" for m in memories)
        config = {
            "system_instruction": (
                "You are a helpful assistant. Known facts about the user "
                f"(from earlier conversations):\n{facts}\n"
                "Use them naturally; don't list them unless asked."
            )
        }
    resp = _client().models.generate_content(model=MODEL, contents=contents, config=config)
    return resp.text
