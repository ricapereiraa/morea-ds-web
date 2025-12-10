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
    grafana_palette = [
        "#7EB26D",
        "#EAB839",
        "#6ED0E0",
        "#EF843C",
        "#E24D42",
        "#1F78C1",
        "#BA43A9",
        "#705DA0",
        "#508642",
        "#CCA300",
        "#447EBC",
        "#C15C17",
        "#890F02",
        "#0A437C",
        "#6D1F62",
        "#584477",
    ]

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
                line=dict(
                    color=grafana_palette[index % len(grafana_palette)],
                    width=2.6,
                    shape="spline",
                ),
                marker=dict(
                    size=6,
                    symbol="circle",
                    color=grafana_palette[index % len(grafana_palette)],
                    line=dict(width=1, color="#0b1220"),
                ),
                hovertemplate=(
                    "%{x|%d/%m %H:%M}<br>%{y:.2f} "
                    f"{collection_unit}<extra>{device_name}</extra>"
                ),
            )
        )

    has_data = any(samples for samples in series_by_device.values())

    fig.update_layout(
        template=None,
        dragmode=False,
        height=520,
        margin=dict(l=28, r=160, t=64, b=40),
        legend=dict(
            title="Dispositivos",
            orientation="v",
            x=1.02,
            y=1,
            bgcolor="rgba(17, 24, 39, 0.9)",
            bordercolor="rgba(75, 85, 99, 0.6)",
            borderwidth=1,
            font=dict(color="#E5E7EB"),
        ),
        hovermode="x unified",
        hoverlabel=dict(
            bgcolor="#111827",
            bordercolor="#0EA5E9",
            font=dict(color="#E5E7EB"),
            namelength=-1,
        ),
        plot_bgcolor="#0F172A",
        paper_bgcolor="#0B1220",
        font=dict(family="Inter, 'Segoe UI', sans-serif", size=12, color="#E5E7EB"),
        yaxis_title=collection_unit,
    )

    fig.update_xaxes(
        title="Horário",
        tickformat="%H:%M",
        showgrid=True,
        gridcolor="rgba(75, 85, 99, 0.35)",
        linecolor="rgba(75, 85, 99, 0.7)",
        zeroline=False,
        ticks="outside",
        tickfont=dict(color="#CBD5E1"),
        titlefont=dict(color="#E5E7EB"),
        rangeselector=None,
        rangeslider_visible=False,
    )

    fig.update_yaxes(
        showgrid=True,
        gridcolor="rgba(75, 85, 99, 0.35)",
        linecolor="rgba(75, 85, 99, 0.7)",
        zeroline=False,
        ticks="outside",
        tickfont=dict(color="#CBD5E1"),
        titlefont=dict(color="#E5E7EB"),
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
