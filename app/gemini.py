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


def generate(history: list[dict]) -> str:
    """Multi-turn completion. `history` is [{role, text}, ...] oldest-first,
    with the latest user message already appended. Roles are "user"/"model",
    which map straight onto Vertex's content roles. F3 will prepend long-term
    memory as a system instruction here."""
    contents = [{"role": m["role"], "parts": [{"text": m["text"]}]} for m in history]
    resp = _client().models.generate_content(model=MODEL, contents=contents)
    return resp.text
