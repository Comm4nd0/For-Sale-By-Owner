from django.urls import path
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'sales', views.SaleViewSet, basename='sale')

urlpatterns = [
    # Nested sale endpoints — stages
    path(
        'sales/<int:sale_pk>/stages/',
        views.StageViewSet.as_view({'get': 'list'}),
        name='sale-stages-list',
    ),
    path(
        'sales/<int:sale_pk>/stages/<int:pk>/',
        views.StageViewSet.as_view({'get': 'retrieve'}),
        name='sale-stages-detail',
    ),

    # Tasks
    path(
        'sales/<int:sale_pk>/tasks/',
        views.TaskViewSet.as_view({'get': 'list', 'post': 'create'}),
        name='sale-tasks-list',
    ),
    path(
        'sales/<int:sale_pk>/tasks/<int:pk>/',
        views.TaskViewSet.as_view({
            'get': 'retrieve', 'patch': 'partial_update',
        }),
        name='sale-tasks-detail',
    ),
    path(
        'sales/<int:sale_pk>/tasks/<int:pk>/reassign/',
        views.TaskViewSet.as_view({'post': 'reassign'}),
        name='sale-tasks-reassign',
    ),
    path(
        'sales/<int:sale_pk>/tasks/<int:pk>/complete/',
        views.TaskViewSet.as_view({'post': 'complete'}),
        name='sale-tasks-complete',
    ),

    # Documents
    path(
        'sales/<int:sale_pk>/documents/',
        views.DocumentViewSet.as_view({'get': 'list', 'post': 'create'}),
        name='sale-documents-list',
    ),
    path(
        'sales/<int:sale_pk>/documents/<int:pk>/',
        views.DocumentViewSet.as_view({
            'get': 'retrieve', 'delete': 'destroy',
        }),
        name='sale-documents-detail',
    ),
    path(
        'sales/<int:sale_pk>/documents/checklist/',
        views.DocumentViewSet.as_view({'get': 'checklist'}),
        name='sale-documents-checklist',
    ),

    # Contact log
    path(
        'sales/<int:sale_pk>/contact-log/',
        views.ContactLogViewSet.as_view({'get': 'list', 'post': 'create'}),
        name='sale-contactlog-list',
    ),
    path(
        'sales/<int:sale_pk>/contact-log/<int:pk>/',
        views.ContactLogViewSet.as_view({
            'get': 'retrieve', 'patch': 'partial_update',
        }),
        name='sale-contactlog-detail',
    ),

    # Enquiries
    path(
        'sales/<int:sale_pk>/enquiries/',
        views.EnquiryViewSet.as_view({'get': 'list', 'post': 'create'}),
        name='sale-enquiries-list',
    ),
    path(
        'sales/<int:sale_pk>/enquiries/<int:pk>/',
        views.EnquiryViewSet.as_view({
            'get': 'retrieve', 'patch': 'partial_update',
        }),
        name='sale-enquiries-detail',
    ),
    path(
        'sales/<int:sale_pk>/enquiries/<int:pk>/reassign/',
        views.EnquiryViewSet.as_view({'post': 'reassign'}),
        name='sale-enquiries-reassign',
    ),

    # Prompt drafts
    path(
        'sales/<int:sale_pk>/prompts/',
        views.PromptDraftViewSet.as_view({'get': 'list'}),
        name='sale-prompts-list',
    ),
    path(
        'sales/<int:sale_pk>/prompts/<int:pk>/',
        views.PromptDraftViewSet.as_view({
            'get': 'retrieve', 'patch': 'partial_update',
        }),
        name='sale-prompts-detail',
    ),
    path(
        'sales/<int:sale_pk>/prompts/generate/',
        views.PromptDraftViewSet.as_view({'post': 'generate'}),
        name='sale-prompts-generate',
    ),

    # GDPR
    path('gdpr/export/', views.gdpr_export, name='sale-gdpr-export'),
    path('gdpr/delete/', views.gdpr_delete, name='sale-gdpr-delete'),
]

urlpatterns += router.urls
