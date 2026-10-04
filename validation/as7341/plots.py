from __future__ import annotations

import html
import math
from pathlib import Path
from typing import Sequence

class SVGPlotGenerator:
    """Generates clean, publication-ready SVG charts without third-party dependencies."""

    @staticmethod
    def generate_spectral_barplot(
        channel_means: dict[str, float],
        title: str,
        output_svg_path: Path,
        width: int = 700,
        height: int = 400,
    ) -> Path:
        channels = list(channel_means.keys())
        values = [channel_means[ch] for ch in channels]
        max_val = max(values) if values and max(values) > 0 else 1.0

        margin_left = 70
        margin_right = 30
        margin_top = 50
        margin_bottom = 60

        plot_w = width - margin_left - margin_right
        plot_h = height - margin_top - margin_bottom

        bar_count = len(channels)
        slot_w = plot_w / bar_count
        bar_w = slot_w * 0.65

        svg = [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            'viewBox="0 0 {width} {height}" style="background-color: #FFFFFF; font-family: sans-serif;">',
            f'<text x="{width / 2}" y="30" text-anchor="middle" font-size="16" font-weight="bold" fill="#1E293B">{html.escape(title)}</text>',
            f'<line x1="{margin_left}" y1="{height - margin_bottom}" x2="{width - margin_right}" y2="{height - margin_bottom}" stroke="#94A3B8" stroke-width="1.5" />',
            f'<line x1="{margin_left}" y1="{margin_top}" x2="{margin_left}" y2="{height - margin_bottom}" stroke="#94A3B8" stroke-width="1.5" />',
        ]

        # Wavelength channel colors
        colors = {
            "415": "#8B5CF6",
            "445": "#6366F1",
            "480": "#3B82F6",
            "515": "#10B981",
            "555": "#84CC16",
            "590": "#EAB308",
            "630": "#F97316",
            "680": "#EF4444",
        }

        # Draw bars
        for idx, ch in enumerate(channels):
            val = channel_means[ch]
            bar_h = (val / max_val) * plot_h if max_val > 0 else 0
            x = margin_left + idx * slot_w + (slot_w - bar_w) / 2
            y = height - margin_bottom - bar_h
            col = colors.get(ch, "#007A78")

            svg.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_w:.1f}" height="{bar_h:.1f}" fill="{col}" rx="3" />')
            svg.append(f'<text x="{x + bar_w / 2:.1f}" y="{height - margin_bottom + 18}" text-anchor="middle" font-size="12" fill="#475569">{ch}nm</text>')
            svg.append(f'<text x="{x + bar_w / 2:.1f}" y="{y - 6:.1f}" text-anchor="middle" font-size="11" font-weight="600" fill="#1E293B">{int(val)}</text>')

        # Y-axis label
        svg.append(
            f'<text transform="rotate(-90)" x="-{height / 2}" y="25" text-anchor="middle" font-size="13" fill="#475569">ADC Counts (Mean)</text>'
        )
        svg.append('</svg>')

        output_svg_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_svg_path, "w", encoding="utf-8") as f:
            f.write("\n".join(svg))

        return output_svg_path

    @staticmethod
    def generate_timeline_plot(
        series_data: dict[str, list[int]],
        title: str,
        output_svg_path: Path,
        width: int = 750,
        height: int = 400,
    ) -> Path:
        sample_count = max(len(vals) for vals in series_data.values()) if series_data else 0
        if sample_count < 2:
            return output_svg_path

        max_val = max(max(vals) for vals in series_data.values()) if series_data else 1.0
        if max_val <= 0:
            max_val = 1.0

        margin_left = 70
        margin_right = 110
        margin_top = 50
        margin_bottom = 60

        plot_w = width - margin_left - margin_right
        plot_h = height - margin_top - margin_bottom

        svg = [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            'viewBox="0 0 {width} {height}" style="background-color: #FFFFFF; font-family: sans-serif;">',
            f'<text x="{width / 2}" y="30" text-anchor="middle" font-size="16" font-weight="bold" fill="#1E293B">{html.escape(title)}</text>',
            f'<line x1="{margin_left}" y1="{height - margin_bottom}" x2="{width - margin_right}" y2="{height - margin_bottom}" stroke="#94A3B8" stroke-width="1.5" />',
            f'<line x1="{margin_left}" y1="{margin_top}" x2="{margin_left}" y2="{height - margin_bottom}" stroke="#94A3B8" stroke-width="1.5" />',
        ]

        colors = {
            "415": "#8B5CF6",
            "445": "#6366F1",
            "480": "#3B82F6",
            "515": "#10B981",
            "555": "#84CC16",
            "590": "#EAB308",
            "630": "#F97316",
            "680": "#EF4444",
        }

        leg_y = margin_top + 10
        for ch, vals in series_data.items():
            col = colors.get(ch, "#007A78")
            pts = []
            for i, val in enumerate(vals):
                x = margin_left + (i / (sample_count - 1)) * plot_w
                y = height - margin_bottom - (val / max_val) * plot_h
                pts.append(f"{x:.1f},{y:.1f}")

            polyline = " ".join(pts)
            svg.append(f'<polyline fill="none" stroke="{col}" stroke-width="2" points="{polyline}" />')

            # Legend
            svg.append(f'<rect x="{width - margin_right + 15}" y="{leg_y}" width="12" height="12" fill="{col}" rx="2" />')
            svg.append(f'<text x="{width - margin_right + 32}" y="{leg_y + 10}" font-size="11" fill="#334155">{ch}nm</text>')
            leg_y += 18

        # Labels
        svg.append(f'<text x="{margin_left + plot_w / 2}" y="{height - 18}" text-anchor="middle" font-size="13" fill="#475569">Sample Index</text>')
        svg.append(f'<text transform="rotate(-90)" x="-{height / 2}" y="25" text-anchor="middle" font-size="13" fill="#475569">ADC Counts</text>')
        svg.append('</svg>')

        output_svg_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_svg_path, "w", encoding="utf-8") as f:
            f.write("\n".join(svg))

        return output_svg_path
