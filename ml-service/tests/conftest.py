import os

# Must be set before any request reaches the app.
os.environ["SCORING_SERVICE_KEY"] = "test-key"

from fastapi.testclient import TestClient

# Make every TestClient created in the tests send the service key by default.
_original_init = TestClient.__init__


def _init_with_key(self, *args, **kwargs):
    kwargs["headers"] = {"X-Service-Key": "test-key", **(kwargs.get("headers") or {})}
    _original_init(self, *args, **kwargs)


TestClient.__init__ = _init_with_key