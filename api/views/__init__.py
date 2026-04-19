"""api.views package — split out of the original 3000-line api/views.py.

Every public name from the old module is re-exported here so
api/urls.py, fsbo_backend/urls.py, and tests that import from
``api.views`` continue to work unchanged.
"""
# pylint: disable=wildcard-import, unused-wildcard-import
import requests  # kept so tests can patch api.views.requests.get

from .base import *  # noqa: F401,F403
from .properties import *  # noqa: F401,F403
from .offers import *  # noqa: F401,F403
from .viewings import *  # noqa: F401,F403
from .chat import *  # noqa: F401,F403
from .saved import *  # noqa: F401,F403
from .services import *  # noqa: F401,F403
from .tools import *  # noqa: F401,F403
from .account import *  # noqa: F401,F403
from .two_factor import *  # noqa: F401,F403

# Underscore-prefixed names aren't picked up by star imports; re-export
# the ones tests and any external callers have historically relied on so
# ``from api.views import _generate_totp`` still works.
from .two_factor import (  # noqa: F401
    _generate_totp,
    _totp_matches,
    _create_2fa_challenge,
)
from .base import _calculate_stamp_duty  # noqa: F401
