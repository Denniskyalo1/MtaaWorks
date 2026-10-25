"""Synthetic M-Pesa-style statement (password protected PDF) for tests and timing. Needs reportlab.
Contains no real data. Layout: a summary table with a TOTAL row, then a 7-column grid table."""
import random, sys, string
from datetime import datetime, timedelta
from reportlab.lib.pagesizes import A4
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.units import mm

def make_rows(start, months, per_day=9, seed=1):
    """Newest-first transactions of one account, with a consistent running balance."""
    rnd = random.Random(seed)
    t = datetime.fromisoformat(start); end = t + timedelta(days=30.44*months)
    bal, tx = 1500.0, []
    kinds = [("Funds received from 2547****%03d JANE DOE", "in", .30), ("Customer Payment from 2547****%03d JOHN", "in", .15),
             ("Customer Transfer to - 2547****%03d PETER", "out", .25), ("Pay Bill Online to 888880 KPLC PREPAID Acc. 1234", "bill", .06),
             ("Customer Payment to Small Business to 5%05d SHOP", "out", .14), ("OverDraft of Credit Party", "fuliza", .02),
             ("OD Loan Repayment to 232323 - M-PESA Overdraw", "repay", .02), ("M-Shwari Deposit", "save", .03), ("Buy Goods charge", "fee", .03)]
    while t < end:
        for _ in range(rnd.randint(per_day-3, per_day+3)):
            t += timedelta(minutes=rnd.randint(20, 160))
            if t >= end: break
            r, acc = rnd.random(), 0
            for text, k, p in kinds:
                acc += p
                if r <= acc: break
            amt = round(rnd.uniform(20, 4000), 2) if k in ("in",) else round(rnd.uniform(10, 1500), 2)
            if k == "fee": amt = round(rnd.uniform(1, 30), 2)
            if k in ("fuliza",): amt = round(rnd.uniform(50, 500), 2)
            name = text % rnd.randint(0, 999) if "%" in text else text
            pin, pout = (amt, 0.0) if k in ("in", "fuliza") else (0.0, amt)
            if pout and pout > bal: pin, pout = pout, 0.0; name = "Funds received from 2547****111 TOPUP"
            bal = round(bal + pin - pout, 2)
            rc = "".join(rnd.choices(string.ascii_uppercase + string.digits, k=10))
            tx.append([rc, t.strftime("%Y-%m-%d %H:%M:%S"), name, "Completed", f"{pin:,.2f}" if pin else "0.00", f"-{pout:,.2f}" if pout else "0.00", f"{bal:,.2f}"])
    tx.reverse()
    return tx


def render(path, password, tx, wrap=False, valign="TOP", rules=True):
    rnd = random.Random(0)
    tin = sum(float(r[4].replace(",", "")) for r in tx); tout = sum(abs(float(r[5].replace(",", ""))) for r in tx)
    ss = getSampleStyleSheet()
    doc = SimpleDocTemplate(path, pagesize=A4, leftMargin=10*mm, rightMargin=10*mm, topMargin=10*mm, bottomMargin=10*mm, encrypt=password)
    summ = Table([["SUMMARY", "PAID IN", "PAID OUT"], ["TOTAL", f"{tin:,.2f}", f"{tout:,.2f}"]])
    summ.setStyle(TableStyle([("GRID", (0,0), (-1,-1), .5, colors.black)]))
    head = [["Receipt No.", "Completion Time", "Details", "Transaction Status", "Paid In", "Withdrawn", "Balance"]]
    widths = [24*mm, 30*mm, 62*mm, 20*mm, 18*mm, 18*mm, 18*mm]
    if wrap:   # long details and a narrow time column, so cells wrap onto 2 or 3 lines
        small = ParagraphStyle("c", fontSize=6.5, leading=8)
        extra = ["", " ADDITIONAL REFERENCE TEXT FOR THIS PAYMENT TO A LONG NAMED BUSINESS LIMITED",
                 " EXTRA TEXT THAT KEEPS GOING AND GOING UNTIL IT WRAPS ONTO THREE LINES OF THE CELL"]
        tx = [[r[0], Paragraph(r[1], small), Paragraph(r[2] + rnd.choice(extra), small), *r[3:]] for r in tx]
        widths = [24*mm, 17*mm, 62*mm, 20*mm, 18*mm, 18*mm, 18*mm]
    big = Table(head + tx, repeatRows=1, colWidths=widths)
    style = [("FONTSIZE", (0,0), (-1,-1), 6.5), ("VALIGN", (0,0), (-1,-1), valign)]
    style += [("GRID", (0,0), (-1,-1), .4, colors.black)] if rules else [("BOX", (0,0), (-1,-1), .4, colors.black), ("LINEAFTER", (0,0), (-2,-1), .4, colors.black)]
    big.setStyle(TableStyle(style))
    doc.build([Paragraph("MPESA FULL STATEMENT (synthetic)", ss["Title"]), Paragraph("All amounts are in KES. TOTAL (KES) figures are summarised below.", ss["Normal"]), summ, Spacer(1, 6*mm), big])
    return len(tx)


def build(path, password, start, months, per_day=9, seed=1, wrap=False, valign="TOP", rules=True):
    return render(path, password, make_rows(start, months, per_day, seed), wrap, valign, rules)


def build_pair(path_a, pw_a, path_b, pw_b, start, months, overlap_days=14, per_day=6, seed=1):
    """Two statements of the SAME account: A is the earlier period, B the later, overlapping by overlap_days."""
    tx = make_rows(start, months, per_day, seed)
    when = [datetime.strptime(r[1], "%Y-%m-%d %H:%M:%S") for r in tx]
    mid = min(when) + (max(when) - min(when)) / 2
    half = timedelta(days=overlap_days / 2)
    a = [r for r, w in zip(tx, when) if w < mid + half]
    b = [r for r, w in zip(tx, when) if w >= mid - half]
    render(path_a, pw_a, a)
    render(path_b, pw_b, b)
    return len(a), len(b)

if __name__ == "__main__":
    n = build(sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4]), seed=int(sys.argv[5]) if len(sys.argv) > 5 else 1)
    print("rows", n)
