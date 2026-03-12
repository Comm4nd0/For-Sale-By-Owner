"""Custom DRF exception handler that ensures all API errors return JSON."""
import logging
from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework import status

logger = logging.getLogger(__name__)


def custom_exception_handler(exc, context):
    """
    Extends DRF's default handler to catch unhandled exceptions
    and return a JSON response instead of Django's HTML 500 page.
    """
    response = exception_handler(exc, context)

    if response is not None:
        return response

    # Unhandled exception — DRF's default handler returned None.
    # Log the full traceback and return a JSON 500 response.
    view = context.get('view')
    logger.error(
        'Unhandled exception in %s: %s',
        view.__class__.__name__ if view else 'unknown',
        str(exc),
        exc_info=True,
    )

    return Response(
        {'detail': str(exc)},
        status=status.HTTP_500_INTERNAL_SERVER_ERROR,
    )
