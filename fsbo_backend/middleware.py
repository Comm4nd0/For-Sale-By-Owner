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
