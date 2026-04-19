from django.conf import settings
from django.http import HttpResponsePermanentRedirect


class WwwRedirectMiddleware:
    """Permanently redirect www.for-sale-by-owner.co.uk to for-sale-by-owner.co.uk."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        host = request.get_host().split(':')[0]
        if host.startswith('www.'):
            non_www = host[4:]
            scheme = request.scheme
            return HttpResponsePermanentRedirect(
                f'{scheme}://{non_www}{request.get_full_path()}'
            )
        return self.get_response(request)


# Starts in Report-Only mode so existing pages aren't broken by unexpected
# inline <script>/<style> or third-party domains. Flip CONTENT_SECURITY_POLICY_ENFORCE
# to True in settings once the report stream is clean.
_DEFAULT_CSP = (
    "default-src 'self'; "
    "script-src 'self' 'unsafe-inline' https://www.google-analytics.com https://www.googletagmanager.com https://js.stripe.com; "
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
    "font-src 'self' https://fonts.gstatic.com data:; "
    "img-src 'self' data: https:; "
    "connect-src 'self' https://api.stripe.com https://for-sale-by-owner.co.uk; "
    "frame-src https://js.stripe.com https://hooks.stripe.com; "
    "frame-ancestors 'self'; "
    "base-uri 'self'; "
    "form-action 'self'; "
    "object-src 'none'"
)


class ContentSecurityPolicyMiddleware:
    """Attach a CSP header to HTML responses.

    Controlled by these settings:
      CONTENT_SECURITY_POLICY          — header value (falls back to a safe default)
      CONTENT_SECURITY_POLICY_ENFORCE  — True emits Content-Security-Policy,
                                         False emits Content-Security-Policy-Report-Only
                                         (default: False, so rollout is safe)
    """

    def __init__(self, get_response):
        self.get_response = get_response
        self.policy = getattr(settings, 'CONTENT_SECURITY_POLICY', _DEFAULT_CSP)
        self.enforce = getattr(settings, 'CONTENT_SECURITY_POLICY_ENFORCE', False)

    def __call__(self, request):
        response = self.get_response(request)
        # Only attach to HTML responses to avoid noise on API JSON / media.
        content_type = response.get('Content-Type', '')
        if 'text/html' not in content_type:
            return response
        header = 'Content-Security-Policy' if self.enforce else 'Content-Security-Policy-Report-Only'
        # Don't overwrite a value a view set explicitly.
        response.setdefault(header, self.policy)
        return response
