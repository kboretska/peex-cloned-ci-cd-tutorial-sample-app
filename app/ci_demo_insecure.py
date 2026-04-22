"""DELETE after demo: intentional Bandit HIGH (B201 Flask debug) to fail CI SAST."""

from flask import Flask

_demo_app = Flask(__name__)


def _never_called_run_debug():
    """Triggers B201 if Bandit resolves debug=True (demo only)."""
    _demo_app.run(debug=True)
