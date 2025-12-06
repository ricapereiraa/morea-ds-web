"""
Exemplo de integração de métricas Prometheus no Django
Adicione isso ao app/views.py existente
"""

# ============ IMPORTS (adicionar ao topo de views.py) ============
from app.metrics import (
    track_auth_attempt, track_data_received, track_store_duration,
    track_store_error, update_device_stats, update_volume_stats, update_energy_stats
)
from prometheus_client import generate_latest, CollectorRegistry, CONTENT_TYPE_LATEST
from django.http import Response
import time


# ============ NOVO ENDPOINT PROMETHEUS ============
def prometheus_metrics(request):
    """Expor métricas Prometheus em /metrics"""
    metrics = generate_latest()
    return Response(metrics, content_type=CONTENT_TYPE_LATEST)


# ============ MODIFICAR authenticateDevice ============
# Adicionar rastreamento de autenticação

@api_view(['POST'])
def authenticateDevice(request):
    """Device authentication with metrics tracking"""
    if request.method == 'POST':
        start_time = time.time()
        
        try:
            data = json.loads(request.body)
            macAddress = data['macAddress']
            deviceIp = data['deviceIp']

            if Device.objects.all().filter(mac_address=macAddress, is_authorized=2).exists():
                apiToken = uuid.uuid4()
                device = Device.objects.get(mac_address=macAddress)
                device.api_token = str(apiToken)
                device.ip_address = str(deviceIp)
                
                deviceLog = DeviceLog(
                    device=device,
                    is_authorized=device.is_authorized,
                    mac_address=device.mac_address,
                    ip_address=device.ip_address,
                    api_token=device.api_token
                )
                
                device.save()
                deviceLog.save()
                
                # Rastrear sucesso
                track_auth_attempt('success')
                track_store_duration(
                    device.get_type_display() if hasattr(device, 'get_type_display') else 'unknown',
                    time.time() - start_time
                )
                
                return Response(
                    {'api_token': apiToken, 'deviceName': device.name},
                    status=status.HTTP_200_OK
                )
            
            # Caso contrário: não autorizado
            track_auth_attempt('not_authorized')
            return Response(
                {'message': 'device not authorized.'},
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        except Exception as e:
            track_auth_attempt('error')
            track_store_error('unknown', str(type(e).__name__))
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )


# ============ MODIFICAR storeData ============
# Adicionar rastreamento de dados recebidos

@api_view(['POST'])
def storeData(request):
    """Store IoT data with metrics tracking"""
    if request.method == "POST":
        try:
            data = json.loads(request.body)
            apiToken = data["apiToken"]
            macAddress = data['macAddress']
            measure = data["measure"]
        except Exception as e:
            track_store_error('unknown', 'parse_error')
            return Response(
                {'message': 'Invalid request format'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Verificar autorização
        if not Device.objects.all().filter(api_token=apiToken).exists():
            track_auth_attempt('invalid_token')
            return Response(
                {'message': 'invalid api token.'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        device = Device.objects.get(api_token=apiToken)

        if not device.is_authorized == 2:
            track_auth_attempt('not_authorized')
            return Response(
                {'message': 'device not authorized.'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        if apiToken and measure is not None:
            start_time = time.time()
            device_type = device.get_type_display() if hasattr(device, 'get_type_display') else 'unknown'
            
            try:
                for i in measure:
                    # Rastrear ponto de dados recebido
                    measure_type = DATA_TYPE_LABELS.get(i.get("type"), "unknown")
                    track_data_received(device_type, measure_type)
                    
                    # Guardar no DB
                    total = Data.objects.all().filter(
                        device=device,
                        type=i["type"]
                    ).order_by('id').reverse()
                    
                    if total:
                        storeData_obj = Data(
                            device=device,
                            type=i["type"],
                            last_collection=float(i["value"]),
                            total=(float(total[0].total) + float(i["value"]))
                        )
                        storeData_obj.save()
                    else:
                        storeData_obj = Data(
                            device=device,
                            type=i["type"],
                            last_collection=float(i["value"]),
                            total=float(i["value"])
                        )
                        storeData_obj.save()

                # Rastrear duração e atualizar métricas
                duration = time.time() - start_time
                track_store_duration(device_type, duration)
                
                # Atualizar gauges de volume/energia
                if device_type == 'Water' or device_type == 'Gas':
                    total_volume = Data.objects.filter(
                        device=device,
                        type__in=[1]  # Volume
                    ).aggregate(Sum('total'))['total__sum'] or 0
                    update_volume_stats(device_type, float(total_volume))
                
                if device_type == 'Energy':
                    total_energy = Data.objects.filter(
                        device=device,
                        type=2  # kWh
                    ).aggregate(Sum('total'))['total__sum'] or 0
                    update_energy_stats(device_type, float(total_energy))
                
                return Response(
                    {'message': 'data stored.'},
                    status=status.HTTP_200_OK
                )

            except Exception as e:
                track_store_error(device_type, str(type(e).__name__))
                return Response(
                    {'message': f'Error: {str(e)}'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        else:
            track_store_error('unknown', 'invalid_data')
            return Response(
                {'message': 'data not received.'},
                status=status.HTTP_400_BAD_REQUEST
            )


# ============ ADICIONAR URLS ============
# Em app/urls.py, adicionar:
# from . import views
# path('metrics', views.prometheus_metrics, name='prometheus_metrics'),


# ============ REFERÊNCIA DE TIPOS DE DADO ============
# Para usar em rastreamento:
DATA_TYPE_LABELS = {
    1: 'Volume',    # L ou m³
    2: 'kWh',       # Energia
    3: 'Watt',      # Potência instantânea
    4: 'Ampere',    # Corrente
}

DEVICE_TYPE_LABELS = {
    1: 'Water',
    2: 'Energy',
    3: 'Gas',
}
