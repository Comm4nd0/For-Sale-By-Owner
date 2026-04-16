"""Shared file-upload validators used by the property and sale-tracker apps.

The goal is to prevent users uploading content that can be rendered as HTML
or executed (e.g. .html, .svg with scripts, .exe) to the media root, which
is served from the same origin as the rest of the site.
"""
import os

from django.core.exceptions import ValidationError

# PDFs plus raster image formats only. SVG is explicitly excluded because
# it can contain <script> and run in the same origin.
ALLOWED_DOCUMENT_EXTENSIONS = {'.pdf', '.png', '.jpg', '.jpeg', '.webp'}
MAX_DOCUMENT_SIZE = 10 * 1024 * 1024  # 10 MB, matches DATA_UPLOAD_MAX_MEMORY_SIZE


def validate_document_file(file_obj):
    """Validate that an uploaded file is a permitted document type and size.

    Raises ``django.core.exceptions.ValidationError`` on rejection so both
    DRF serializers and model-level ``full_clean`` can surface the message.
    """
    if file_obj is None:
        return

    name = getattr(file_obj, 'name', '') or ''
    ext = os.path.splitext(name)[1].lower()
    if ext not in ALLOWED_DOCUMENT_EXTENSIONS:
        allowed = ', '.join(sorted(ALLOWED_DOCUMENT_EXTENSIONS))
        raise ValidationError(
            f'Unsupported file type "{ext or "?"}". Allowed: {allowed}.'
        )

    size = getattr(file_obj, 'size', None)
    if size is not None and size > MAX_DOCUMENT_SIZE:
        raise ValidationError(
            f'File is too large ({size // (1024 * 1024)} MB). '
            f'Maximum size is {MAX_DOCUMENT_SIZE // (1024 * 1024)} MB.'
        )
