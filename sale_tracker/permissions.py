from rest_framework import permissions


class IsSaleOwner(permissions.BasePermission):
    """
    Only the seller who owns the sale can access it.
    """
    def has_object_permission(self, request, view, obj):
        # obj could be Sale, or a nested object with a .sale property
        sale = getattr(obj, 'sale', obj)
        if hasattr(sale, 'sale'):
            sale = sale.sale
        return sale.seller == request.user
