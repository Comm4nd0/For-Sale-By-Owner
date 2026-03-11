"""Celery configuration for fsbo_backend project."""
import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'fsbo_backend.settings')

app = Celery('fsbo_backend')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()
