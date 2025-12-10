from datetime import timedelta
from collections import defaultdict
import os

import plotly.graph_objects as go
from plotly.colors import qualitative as plotly_colors
from django.conf import settings
from django.utils import timezone

from .models import AuthTypes, Device, Data, Graph


def _series_by_device(device_ids, date_from):
    """Return timeseries values for each device keyed by device name."""
    device_series = defaultdict(list)

    devices = Device.objects.filter(id__in=device_ids).values('id', 'name')

    for device in devices:
        label = device['name'] or f"Dispositivo {device['id']}"
        if label in device_series:
            label = f"{label} ({device['id']})"

        samples = list(
            Data.objects.filter(
                device=device['id'],
                collect_date__gte=date_from,
            )
            .order_by('collect_date')
            .values_list('collect_date', 'last_collection')
        )

        for collected_at, value in samples:
            if timezone.is_naive(collected_at):
                collected_at = timezone.make_aware(
                    collected_at, timezone.get_default_timezone()
                )
            localized = timezone.localtime(collected_at)
            device_series[label].append((localized, value))

        device_series.setdefault(label, [])

    return device_series


def _write_line_chart(series_by_device, collection_unit, media_path):
    """Create an interactive line chart without relying on pandas."""
    fig = go.Figure()
    palette = plotly_colors.Set2

    for index, (device_name, samples) in enumerate(sorted(series_by_device.items())):
        if not samples:
            continue

        times, values = zip(*samples)
        fig.add_trace(
            go.Scatter(
                x=list(times),
                y=list(values),
                mode="lines+markers",
                name=device_name,
                line=dict(color=palette[index % len(palette)], width=2),
                marker=dict(size=7, symbol="circle", line=dict(width=0)),
                hovertemplate=(
                    "%{x|%d/%m %H:%M}<br>%{y:.2f} "
                    f"{collection_unit}<extra>{device_name}</extra>"
                ),
            )
        )

    has_data = any(samples for samples in series_by_device.values())

    fig.update_layout(
        template="plotly_white",
        dragmode=False,
        margin=dict(l=24, r=24, t=48, b=24),
        legend=dict(
            title="Dispositivos",
            orientation="h",
            x=0.0,
            y=1.15,
            bgcolor="rgba(255,255,255,0.5)",
        ),
        hovermode="x unified",
        plot_bgcolor="rgba(248, 250, 252, 0.95)",
        paper_bgcolor="rgba(255, 255, 255, 1)",
        font=dict(family="Inter, Arial, sans-serif", size=12, color="#1f2933"),
        yaxis_title=collection_unit,
    )

    fig.update_xaxes(
        title="Horário",
        tickformat="%H:%M",
        showgrid=True,
        gridcolor="rgba(148, 163, 184, 0.35)",
        linecolor="rgba(71, 85, 105, 0.45)",
        zeroline=False,
    )

    fig.update_yaxes(
        showgrid=True,
        gridcolor="rgba(148, 163, 184, 0.35)",
        linecolor="rgba(71, 85, 105, 0.45)",
        zeroline=False,
    )

    if not has_data:
        fig.add_annotation(
            text="Nenhum registro coletado nas últimas 24h",
            showarrow=False,
            font=dict(size=14, color="#475569"),
            xref="paper",
            yref="paper",
            x=0.5,
            y=0.5,
        )
        fig.update_layout(hovermode=False)

    os.makedirs(os.path.dirname(media_path), exist_ok=True)
    fig.write_html(media_path, config={'displayModeBar': False})


def generateAllMotes24hRaw():
    media_root = settings.MEDIA_ROOT

    for device_type in range(1, 4):
        device_ids = list(
            Device.objects.filter(
                type=device_type,
                is_authorized=AuthTypes.Authorized,
            ).values_list('id', flat=True)
        )

        if device_type == 1:
            relative_path = 'graphs/allWMoteDevices24hRaw.html'
            collection_unit = 'Consumo(L)'
        elif device_type == 2:
            relative_path = 'graphs/allEMoteDevices24hRaw.html'
            collection_unit = 'Consumo(Watts)'
        else:
            relative_path = 'graphs/allGMoteDevices24hRaw.html'
            collection_unit = 'Consumo(m³)'

        absolute_path = os.path.join(media_root, relative_path)
        timeseries = _series_by_device(device_ids, timezone.now() - timedelta(days=1))
        _write_line_chart(timeseries, collection_unit, absolute_path)

        if not Graph.objects.filter(type=device_type).exists():
            Graph.objects.create(type=device_type, file_path=relative_path)
