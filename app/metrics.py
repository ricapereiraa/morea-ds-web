"""
Prometheus metrics for Morea IoT application
Instrumentação de métricas customizadas para monitorar coleta de dados de IoT
"""

from prometheus_client import Counter, Histogram, Gauge
import time

# Contadores
data_points_received = Counter(
    'morea_data_points_received_total',
    'Total data points received from IoT devices',
    ['device_type', 'measure_type']
)

device_auth_attempts = Counter(
    'morea_device_auth_attempts_total',
    'Total device authentication attempts',
    ['result']  # 'success' ou 'failed'
)

# Histogramas (latência)
data_store_duration = Histogram(
    'morea_data_store_duration_seconds',
    'Time taken to store data in database',
    ['device_type'],
    buckets=(0.01, 0.05, 0.1, 0.5, 1.0, 2.5, 5.0)
)

auth_duration = Histogram(
    'morea_device_auth_duration_seconds',
    'Time taken to authenticate device',
    buckets=(0.01, 0.05, 0.1, 0.5, 1.0)
)

# Medidores (current state)
active_devices = Gauge(
    'morea_active_devices',
    'Number of active IoT devices',
    ['device_type', 'authorization_status']
)

total_data_volume = Gauge(
    'morea_total_data_volume_liters',
    'Total water/gas volume collected',
    ['device_type']
)

total_energy_consumed = Gauge(
    'morea_total_energy_consumed_kwh',
    'Total energy consumed (kWh)',
    ['device_type']
)

# Erros
data_store_errors = Counter(
    'morea_data_store_errors_total',
    'Total errors storing data',
    ['device_type', 'error_type']
)


def track_auth_attempt(result):
    """Record device authentication attempt"""
    device_auth_attempts.labels(result=result).inc()


def track_data_received(device_type, measure_type):
    """Record received data point"""
    data_points_received.labels(
        device_type=device_type,
        measure_type=measure_type
    ).inc()


def track_store_duration(device_type, duration):
    """Record data storage duration"""
    data_store_duration.labels(device_type=device_type).observe(duration)


def track_store_error(device_type, error_type):
    """Record storage error"""
    data_store_errors.labels(
        device_type=device_type,
        error_type=error_type
    ).inc()


def update_device_stats(device_type, auth_status, count):
    """Update active devices gauge"""
    active_devices.labels(
        device_type=device_type,
        authorization_status=auth_status
    ).set(count)


def update_volume_stats(device_type, volume):
    """Update total volume collected"""
    total_data_volume.labels(device_type=device_type).set(volume)


def update_energy_stats(device_type, energy):
    """Update total energy consumed"""
    total_energy_consumed.labels(device_type=device_type).set(energy)
