"""Make native scatter-series interpolation explicit in the authored draft.

The presentation exporter currently omits the series-level ``smooth=False``
setting. Native renderers can consequently draw curves between annual points.
This narrow export repair preserves editable charts and every numeric value.
It runs before package validation and PDF conversion.
"""

from pathlib import Path
import sys
from zipfile import ZipFile

from lxml import etree


def set_straight_segments(path: Path) -> None:
    namespace = "http://schemas.openxmlformats.org/drawingml/2006/chart"
    ns = {"c": namespace}
    replacement = path.with_suffix(".segments.pptx")
    count = 0
    with ZipFile(path) as source, ZipFile(replacement, "w") as output:
        for member in source.infolist():
            payload = source.read(member.filename)
            if "/charts/" in member.filename and member.filename.endswith(".xml"):
                root = etree.fromstring(payload)
                for chart in root.findall(".//c:scatterChart", ns):
                    style = chart.find("c:scatterStyle", ns)
                    if style is None or style.get("val") not in ("line", "lineMarker", "marker"):
                        raise ValueError("Unexpected scatter style; review interpolation intent")
                    for series in chart.findall("c:ser", ns):
                        smooth = series.find("c:smooth", ns)
                        if smooth is None:
                            smooth = etree.Element(f"{{{namespace}}}smooth")
                            extension = series.find("c:extLst", ns)
                            if extension is None:
                                series.append(smooth)
                            else:
                                series.insert(series.index(extension), smooth)
                        smooth.set("val", "0")
                        count += 1
                payload = etree.tostring(root, xml_declaration=True, encoding="UTF-8", standalone=True)
            output.writestr(member, payload)
    if not count:
        replacement.unlink()
        raise ValueError("No native scatter series found")
    replacement.replace(path)
    print(f"Explicit straight-line interpolation: {count} native chart series")


if __name__ == "__main__":
    set_straight_segments(Path(sys.argv[1]))
