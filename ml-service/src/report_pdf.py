"""Builds the one-page credit report PDF that a borrower can share with a lender.
The report carries a verification code, a QR code that opens the verification page, and a short
fingerprint, so a lender can check it against the record kept by MtaaWorks."""
import io

from reportlab.graphics import renderPDF
from reportlab.graphics.barcode.qr import QrCodeWidget
from reportlab.graphics.shapes import Drawing
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph, Table, TableStyle

PURPLE = colors.HexColor("#5B3CC4")
GREY = colors.HexColor("#555555")


def _paragraph(text, style):
    return Paragraph(str(text).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"), style)


def build_report_pdf(d: dict) -> bytes:
    """d needs: name, score, tier, high_risk, scored_at, model_version, code, hash, issued_at,
    valid_until, verify_url and, optionally, drivers [{label, helping}]."""
    buf = io.BytesIO()
    page_w, page_h = A4
    c = canvas.Canvas(buf, pagesize=A4)
    c.setTitle("MtaaWorks credit report " + d["code"])
    styles = getSampleStyleSheet()
    body = ParagraphStyle("body", parent=styles["Normal"], fontName="Helvetica", fontSize=10, leading=14, textColor=GREY)
    small = ParagraphStyle("small", parent=body, fontSize=8.5, leading=11.5)
    left = 20 * mm

    # header band
    c.setFillColor(PURPLE)
    c.rect(0, page_h - 28 * mm, page_w, 28 * mm, stroke=0, fill=1)
    c.setFillColor(colors.white)
    c.setFont("Helvetica-Bold", 20)
    c.drawString(left, page_h - 17 * mm, "MtaaWorks credit report")
    c.setFont("Helvetica", 10)
    c.drawString(left, page_h - 23 * mm, "Issued " + d["issued_at"] + "  |  valid until " + d["valid_until"])

    # borrower and score
    y = page_h - 45 * mm
    c.setFillColor(colors.black)
    c.setFont("Helvetica-Bold", 13)
    c.drawString(left, y, d["name"])
    c.setFillColor(GREY)
    c.setFont("Helvetica", 9.5)
    c.drawString(left, y - 6 * mm, "Score calculated on " + d["scored_at"] + " with model version " + d["model_version"])

    y -= 32 * mm
    c.setFillColor(PURPLE)
    c.setFont("Helvetica-Bold", 54)
    c.drawString(left, y, "%.1f" % float(d["score"]))
    c.setFillColor(GREY)
    c.setFont("Helvetica", 12)
    c.drawString(left + 62 * mm, y + 4 * mm, "out of 100")
    c.setFillColor(colors.black)
    c.setFont("Helvetica-Bold", 14)
    c.drawString(left, y - 9 * mm, d["tier"] + ("  |  flagged high risk" if d["high_risk"] else ""))

    # drivers (only when the borrower chose to include them)
    y -= 22 * mm
    drivers = d.get("drivers")
    if drivers:
        c.setFont("Helvetica-Bold", 11)
        c.drawString(left, y, "Main reasons behind the score")
        rows = [[_paragraph(x["label"], body), "helping" if x["helping"] else "holding back"] for x in drivers]
        t = Table(rows, colWidths=[110 * mm, 40 * mm])
        t.setStyle(TableStyle([
            ("LINEBELOW", (0, 0), (-1, -1), 0.3, colors.lightgrey),
            ("TEXTCOLOR", (1, 0), (1, -1), GREY), ("FONTSIZE", (1, 0), (1, -1), 9),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE")]))
        _, th = t.wrapOn(c, 150 * mm, 100 * mm)
        t.drawOn(c, left, y - 4 * mm - th)
        y -= th + 14 * mm
    else:
        c.setFont("Helvetica-Oblique", 9.5)
        c.setFillColor(GREY)
        c.drawString(left, y, "The borrower chose not to include the reasons behind the score in this report.")
        y -= 14 * mm

    # verification box
    box_h = 46 * mm
    box_y = y - box_h
    c.setStrokeColor(PURPLE)
    c.setLineWidth(1)
    c.roundRect(left, box_y, page_w - 2 * left, box_h, 4 * mm, stroke=1, fill=0)
    c.setFillColor(PURPLE)
    c.setFont("Helvetica-Bold", 11)
    c.drawString(left + 6 * mm, box_y + box_h - 9 * mm, "Verify this report")
    c.setFillColor(colors.black)
    c.setFont("Courier-Bold", 14)
    c.drawString(left + 6 * mm, box_y + box_h - 18 * mm, d["code"])
    c.setFillColor(GREY)
    c.setFont("Helvetica", 8.5)
    c.drawString(left + 6 * mm, box_y + box_h - 24 * mm, "Fingerprint " + d["hash"])
    p = _paragraph("Scan the code or enter the verification code in the MtaaWorks lender portal. The page shows the score "
                   "held on record. If it differs from this report, or the report has expired or been withdrawn, do not rely on it.", small)
    pw, ph = p.wrapOn(c, 110 * mm, 30 * mm)
    p.drawOn(c, left + 6 * mm, box_y + 5 * mm)
    qr = QrCodeWidget(d["verify_url"])
    x0, y0, x1, y1 = qr.getBounds()
    size = 34 * mm
    drawing = Drawing(size, size, transform=[size / (x1 - x0), 0, 0, size / (y1 - y0), 0, 0])
    drawing.add(qr)
    renderPDF.draw(drawing, c, page_w - left - size - 4 * mm, box_y + 6 * mm)

    # notice
    p = _paragraph("This report was produced from an M-Pesa statement that the borrower uploaded and agreed to have analysed. "
                   "The score is an estimate to help a lender decide. It is not a loan approval, and it does not describe how the "
                   "borrower will behave in future. The lender makes its own decision. MtaaWorks is not a lender or a credit reference bureau.", small)
    pw, ph = p.wrapOn(c, page_w - 2 * left, 40 * mm)
    p.drawOn(c, left, box_y - 8 * mm - ph)

    c.showPage()
    c.save()
    return buf.getvalue()
