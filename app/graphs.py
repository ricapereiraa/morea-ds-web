from datetime import timedelta
from collections import defaultdict
import os

import plotly.graph_objects as go
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
    """Create an interactive line chart styled to mirror Grafana's dark dashboards."""
    fig = go.Figure()
    # Paleta de cores Grafana moderna
    grafana_palette = [
        "#73BF69",  # Verde
        "#F2704F",  # Laranja
        "#B877D9",  # Roxo
        "#5794F2",  # Azul
        "#F2C962",  # Amarelo
        "#00A0EB",  # Azul claro
        "#FF6B5B",  # Vermelho
        "#1F4788",  # Azul escuro
        "#8AB4B4",  # Teal
        "#E67C73",  # Rosa
        "#2C6E49",  # Verde escuro
        "#D63031",  # Vermelho intenso
    ]

    for index, (device_name, samples) in enumerate(sorted(series_by_device.items())):
        if not samples:
            continue

        times, values = zip(*samples)
        fig.add_trace(
            go.Scatter(
                x=list(times),
                y=list(values),
                mode="lines",
                name=device_name,
                line=dict(
                    color=grafana_palette[index % len(grafana_palette)],
                    width=2.5,
                    shape="linear",
                ),
                fill="tozeroy",
                fillcolor=grafana_palette[index % len(grafana_palette)],
                opacity=0.7,
                hovertemplate=(
                    "<b>%{fullData.name}</b><br>"
                    "Horário: %{x|%H:%M}<br>"
                    f"Consumo: %{{y:.2f}} {collection_unit}"
                    "<extra></extra>"
                ),
            )
        )

    has_data = any(samples for samples in series_by_device.values())

    fig.update_layout(
        template=None,
        dragmode="zoom",
        height=340,
        margin=dict(l=50, r=100, t=15, b=45),
        legend=dict(
            title="",
            orientation="v",
            x=1.02,
            y=1,
            bgcolor="rgba(31, 41, 55, 0.95)",
            bordercolor="rgba(75, 85, 99, 0.6)",
            borderwidth=1,
            font=dict(color="#E5E7EB", size=10),
            tracegroupgap=6,
        ),
        hovermode="x unified",
        hoverlabel=dict(
            bgcolor="#1f2937",
            bordercolor="#5794F2",
            font=dict(color="#E5E7EB", size=12),
            namelength=-1,
        ),
        plot_bgcolor="#111827",
        paper_bgcolor="#111827",
        font=dict(family="'Grafana', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif", size=12, color="#E5E7EB"),
    )

    fig.update_xaxes(
        title="",
        tickformat="%H:%M",
        showgrid=True,
        gridwidth=1,
        gridcolor="rgba(75, 85, 99, 0.2)",
        linecolor="rgba(75, 85, 99, 0.4)",
        zeroline=False,
        ticks="outside",
        ticklen=3,
        tickfont=dict(color="#A1A5B0", size=9),
        titlefont=dict(color="#A1A5B0", size=10),
        rangeselector=None,
        rangeslider_visible=False,
        showline=True,
        mirror="ticks",
    )

    fig.update_yaxes(
        showgrid=True,
        gridwidth=1,
        gridcolor="rgba(75, 85, 99, 0.2)",
        linecolor="rgba(75, 85, 99, 0.4)",
        zeroline=False,
        ticks="outside",
        ticklen=3,
        tickfont=dict(color="#A1A5B0", size=9),
        titlefont=dict(color="#A1A5B0", size=10),
        showline=True,
        mirror="ticks",
        side="left",
    )

    if not has_data:
        fig.add_annotation(
            text="Nenhum registro coletado nas últimas 24h",
            showarrow=False,
            font=dict(size=14, color="#CBD5E1"),
            xref="paper",
            yref="paper",
            x=0.5,
            y=0.5,
        )
        fig.update_layout(hovermode=False)

    os.makedirs(os.path.dirname(media_path), exist_ok=True)
    fig.write_html(
        media_path,
        config={'displayModeBar': False, 'responsive': True},
    )


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
