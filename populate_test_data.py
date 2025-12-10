#!/usr/bin/env python
"""
Script para popular o banco de dados com dados fictícios para testes.
Execute com: python3 populate_test_data.py
"""
import os
import django
import random
from datetime import timedelta

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'morea_ds.settings')
django.setup()

from django.utils import timezone
from app.models import Device, Data, DeviceTypes, AuthTypes
from app.graphs import generateAllMotes24hRaw


def create_test_devices():
    """Cria dispositivos de teste se não existirem."""
    devices = []
    
    # Dispositivos de água (Water)
    for i in range(1, 4):
        device, created = Device.objects.get_or_create(
            name=f"WaterMote-{i}",
            type=DeviceTypes.water,
            defaults={'is_authorized': AuthTypes.Authorized}
        )
        devices.append(device)
        if created:
            print(f"[+] Criado dispositivo: {device.name}")
    
    # Dispositivos de energia (Energy)
    for i in range(1, 4):
        device, created = Device.objects.get_or_create(
            name=f"EnergyMote-{i}",
            type=DeviceTypes.energy,
            defaults={'is_authorized': AuthTypes.Authorized}
        )
        devices.append(device)
        if created:
            print(f"[+] Criado dispositivo: {device.name}")
    
    # Dispositivos de gás (Gas)
    for i in range(1, 4):
        device, created = Device.objects.get_or_create(
            name=f"GasMote-{i}",
            type=DeviceTypes.gas,
            defaults={'is_authorized': AuthTypes.Authorized}
        )
        devices.append(device)
        if created:
            print(f"✓ Criado dispositivo: {device.name}")
    
    return devices


def generate_realistic_data(device, num_hours=24):
    """Gera dados fictícios realistas para um dispositivo."""
    now = timezone.now()
    
    # Define valores base e variação conforme o tipo de dispositivo
    if device.type == DeviceTypes.water:
        base_value = 15.0  # Litros
        variation = 8.0
        spike_chance = 0.15  # 15% de chance de pico (banho, lavagem, etc)
    elif device.type == DeviceTypes.energy:
        base_value = 350.0  # Watts
        variation = 150.0
        spike_chance = 0.20  # 20% de chance de pico (ar condicionado, chuveiro elétrico)
    else:  # Gas
        base_value = 0.08  # m³
        variation = 0.04
        spike_chance = 0.10  # 10% de chance de pico (fogão, aquecedor)
    
    # Gera dados para cada 15 minutos nas últimas 24 horas
    data_points = []
    for i in range(num_hours * 4):  # 4 pontos por hora (a cada 15 min)
        time_offset = timedelta(hours=num_hours) - timedelta(minutes=i * 15)
        collect_time = now - time_offset
        
        # Simula padrões de consumo por horário
        hour = collect_time.hour
        
        # Horário de pico (manhã 6-9h, noite 18-22h)
        if (6 <= hour <= 9) or (18 <= hour <= 22):
            multiplier = random.uniform(1.2, 1.8)
        # Horário de baixo consumo (madrugada 0-5h)
        elif 0 <= hour <= 5:
            multiplier = random.uniform(0.2, 0.5)
        # Horário normal
        else:
            multiplier = random.uniform(0.6, 1.2)
        
        # Adiciona picos aleatórios
        if random.random() < spike_chance:
            multiplier *= random.uniform(2.0, 3.5)
        
        # Calcula o valor com variação natural
        value = base_value * multiplier + random.uniform(-variation/2, variation/2)
        value = max(0, value)  # Garante que não seja negativo
        
        data_points.append({
            'collect_date': collect_time,
            'last_collection': round(value, 2),
            'total': round(value * (i + 1), 2)  # Total acumulado
        })
    
    return data_points


def populate_data():
    """Popula dados fictícios no banco."""
    print("\n[*] Limpando dados antigos de teste...")
    # Remove dados antigos de dispositivos de teste
    test_device_names = [
        'WaterMote-1', 'WaterMote-2', 'WaterMote-3',
        'EnergyMote-1', 'EnergyMote-2', 'EnergyMote-3',
        'GasMote-1', 'GasMote-2', 'GasMote-3'
    ]
    Data.objects.filter(device__name__in=test_device_names).delete()
    
    print("[*] Criando dispositivos de teste...")
    devices = create_test_devices()
    
    print("\n[*] Gerando dados fictícios...")
    total_records = 0
    for device in devices:
        data_points = generate_realistic_data(device, num_hours=24)
        
        # Cria os registros em lote
        data_objects = [
            Data(
                device=device,
                type=device.type,
                last_collection=dp['last_collection'],
                total=dp['total'],
                collect_date=dp['collect_date']
            )
            for dp in data_points
        ]
        Data.objects.bulk_create(data_objects)
        
        total_records += len(data_objects)
        print(f"  [+] {device.name}: {len(data_objects)} registros")
    
    print(f"\n[*] Total de {total_records} registros criados!")
    
    print("\n[*] Gerando gráficos...")
    generateAllMotes24hRaw()
    print("[+] Gráficos gerados com sucesso!")
    
    print("\n[OK] Processo concluído! Acesse /dashboard para visualizar os gráficos.")


if __name__ == '__main__':
    print("=" * 60)
    print("[INICIAR] Populando banco de dados com dados fictícios")
    print("=" * 60)
    populate_data()
