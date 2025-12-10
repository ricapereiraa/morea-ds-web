"""morea_ds URL Configuration

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/4.1/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
import os

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('app.urls'))
]

# Servir arquivos estáticos e media
# Garantir que arquivos estáticos sejam sempre servidos, mesmo sem collectstatic
from django.contrib.staticfiles.urls import staticfiles_urlpatterns

# Adicionar padrões do Django que procuram em STATICFILES_DIRS
urlpatterns += staticfiles_urlpatterns()

# Servir diretamente de STATICFILES_DIRS (para desenvolvimento)
# Isso garante que funcione mesmo sem collectstatic
for static_dir in settings.STATICFILES_DIRS:
    if os.path.exists(static_dir):
        urlpatterns += static(settings.STATIC_URL, document_root=static_dir)
        break  # Usar apenas o primeiro diretório que existir

# Também servir de STATIC_ROOT se existir (após collectstatic)
if os.path.exists(settings.STATIC_ROOT):
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)

# Sempre servir arquivos de media
urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

handler403 = 'app.views.page_in_erro403'
handler404 = 'app.views.page_in_erro404'
handler500 = 'app.views.page_in_erro500'
handler503 = 'app.views.page_in_erro503'