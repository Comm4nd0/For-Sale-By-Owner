"""Custom DRF exception handler that ensures all API errors return JSON."""
import logging
from django.db import IntegrityError
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

    # Handle database integrity errors with a friendly message
    if isinstance(exc, IntegrityError):
        logger.warning(
            'IntegrityError in %s: %s',
            context.get('view', {}).get('__class__', {}).get('__name__', 'unknown')
            if isinstance(context.get('view'), dict)
            else getattr(getattr(context.get('view'), '__class__', None), '__name__', 'unknown'),
            str(exc),
            exc_info=True,
        )
        return Response(
            {'detail': 'This record already exists or conflicts with an existing entry. '
                        'Please check your input and try again.'},
            status=status.HTTP_409_CONFLICT,
        )

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
        {'detail': 'An unexpected error occurred. Please try again later.'},
        status=status.HTTP_500_INTERNAL_SERVER_ERROR,
    )
