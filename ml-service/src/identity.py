"""Reads the customer name and mobile number printed at the top of an M-Pesa statement and compares
them with the name and verified phone number on the borrower's MtaaWorks account.

Nothing here is stored or logged. The comparison result (matched, not matched, not checked) is all that
leaves the service, and a refusal message never repeats the name or the number."""
import os
import re

NAME_LABEL = r"customer\s*name"
PHONE_LABEL = r"mobile\s*(?:number|no\.?)|phone\s*(?:number|no\.?)|msisdn"
KNOWN_LABELS = ("customer name", "mobile number", "mobile no", "phone number", "phone no", "msisdn",
                "date of statement", "statement date", "statement period", "account number", "statement for")
_NEXT_LABEL = re.compile(r"\s+(?:mobile\s*(?:number|no)|phone\s*(?:number|no)|date\s*of\s*statement|statement\s*(?:period|date)|account\s*number)\b", re.I)


def identity_check_enabled() -> bool:
    """Set STATEMENT_IDENTITY_CHECK=off to skip the name and phone comparison (for example when testing
    with statements that belong to other people)."""
    return os.environ.get("STATEMENT_IDENTITY_CHECK", "on").strip().lower() != "off"


def _is_label(line: str) -> bool:
    low = line.lower().strip()
    return low.endswith(":") or any(low.startswith(k) for k in KNOWN_LABELS)


def _value_after(lines, label_pattern):
    """The value printed for a label, whether it sits on the same line, on the next line, or in a block
    of values that follows a block of labels."""
    for i, line in enumerate(lines):
        m = re.search(r"(?:" + label_pattern + r")\s*[:\-]?\s*(.*)$", line, re.I)
        if not m:
            continue
        inline = _NEXT_LABEL.split(m.group(1).strip())[0].strip()
        if inline and not _is_label(inline):
            return inline
        j = i
        while j > 0 and _is_label(lines[j - 1]):
            j -= 1
        k = i
        while k + 1 < len(lines) and _is_label(lines[k + 1]):
            k += 1
        idx = k + 1 + (i - j)
        if idx < len(lines) and not _is_label(lines[idx]):
            return lines[idx]
    return None


def parse_identity(text: str) -> dict:
    lines = [l.strip() for l in (text or "").splitlines() if l.strip()][:60]
    name = _value_after(lines, NAME_LABEL)
    raw_phone = _value_after(lines, PHONE_LABEL)
    phone = None
    if raw_phone:
        m = re.search(r"[+\d][\d\s*xX\-]{6,}", raw_phone)
        if m:
            phone = re.sub(r"[\s\-]", "", m.group(0)).replace("x", "*").replace("X", "*").lstrip("+")
    return {"name": name or None, "phone": phone}


def _tokens(s):
    return {t for t in re.sub(r"[^A-Za-z\s]", " ", s.upper()).split() if len(t) > 1}


def names_match(a, b):
    """True when the two names share at least two words (or every word, for one-word names). The order of the
    words and a missing middle name do not matter. None when either name is empty."""
    ta, tb = _tokens(a or ""), _tokens(b or "")
    if not ta or not tb:
        return None
    return len(ta & tb) >= min(2, len(ta), len(tb))


def _phone_core(p):
    p = re.sub(r"[^\d*]", "", p or "")
    if p.startswith("254"):
        p = p[3:]
    elif p.startswith("0"):
        p = p[1:]
    return p if len(p) == 9 else None


def phones_match(a, b):
    """Compares Kenyan mobile numbers written as 07..., +2547... or 2547.... A * in the statement stands for a
    hidden digit and matches any digit. None when either number is missing or cannot be read."""
    ca, cb = _phone_core(a), _phone_core(b)
    if ca is None or cb is None:
        return None
    return all(x == y or x == "*" or y == "*" for x, y in zip(ca, cb))


def check_identity(found: dict, expected_name: str, expected_phone: str) -> dict:
    name_ok = names_match(found.get("name"), expected_name) if expected_name else None
    phone_ok = phones_match(found.get("phone"), expected_phone) if expected_phone else None
    return {"checked": name_ok is not None or phone_ok is not None,
            "name_matched": name_ok, "phone_matched": phone_ok,
            "mismatch": name_ok is False or phone_ok is False}


def identities_agree(a: dict, b: dict):
    """Do two statements show the same customer? False when a printed name or number differs, None when
    nothing can be compared."""
    n = names_match(a.get("name"), b.get("name")) if a.get("name") and b.get("name") else None
    p = phones_match(a.get("phone"), b.get("phone")) if a.get("phone") and b.get("phone") else None
    if n is False or p is False:
        return False
    return None if n is None and p is None else True
