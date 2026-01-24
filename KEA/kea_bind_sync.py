#!/usr/bin/env python3
import csv
import ipaddress
import re
import subprocess
from pathlib import Path
from datetime import datetime

# Paths
LEASES_FILE = Path("<path/to/lease/file>")
FWD_ZONE_FILE = Path("<path/to/fwd/zone/file>")
REV_ZONE_FILE = Path("<path/to/rev/zone/file>")

# Network
NETWORK = ipaddress.ip_network("<subnet>")
DOMAIN = "<domain name>"

# Regex to find/replace SOA serial (the first number in the SOA line)
SOA_SERIAL_RE = re.compile(r"(^\s*@\s+IN\s+SOA\s+.+?\(\s*)(\d+)(\s*; Serial)", re.MULTILINE)

def load_file(path: Path) -> str:
    return path.read_text()

def save_file(path: Path, content: str):
    path.write_text(content)

def bump_serial(zone_text: str) -> str:
    """
    Bump the SOA serial. If it looks like an integer, +1.
    (You can swap this for YYYYMMDDnn logic if you prefer.)
    """
    def repl(match):
        prefix, serial, suffix = match.groups()
        new_serial = str(int(serial) + 1)
        return f"{prefix}{new_serial}{suffix}"

    new_text, count = SOA_SERIAL_RE.subn(repl, zone_text, count=1)
    if count == 0:
        raise RuntimeError("SOA serial not found in zone file")
    return new_text

def parse_existing_records(zone_text: str):
    """
    For forward zone: return set of (hostname, ip)
    For reverse zone: return set of (last_octet, fqdn)
    """
    fwd_records = set()
    rev_records = set()

    for line in zone_text.splitlines():
        line = line.strip()
        if not line or line.startswith(";"):
            continue

        # Forward: host IN A IP
        m_a = re.match(r"^(\S+)\s+IN\s+A\s+(\d+\.\d+\.\d+\.\d+)$", line)
        if m_a:
            host, ip = m_a.groups()
            # ensure FQDN
            if not host.endswith("."):
                fqdn = f"{host}.{DOMAIN.rstrip('.')}"
            else:
                fqdn = host
            fwd_records.add((fqdn.lower(), ip))
            continue

        # Reverse: last_octet IN PTR fqdn.
        m_ptr = re.match(r"^(\d+)\s+IN\s+PTR\s+(\S+)\.$", line)
        if m_ptr:
            last_octet, fqdn = m_ptr.groups()
            rev_records.add((last_octet, fqdn.lower()))
            continue

    return fwd_records, rev_records

def ip_to_last_octet(ip: str) -> str:
    return ip.split(".")[-1]

def main():
    # Load zone files
    fwd_zone = load_file(FWD_ZONE_FILE)
    rev_zone = load_file(REV_ZONE_FILE)

    existing_fwd, existing_rev = parse_existing_records(fwd_zone + "\n" + rev_zone)  # combined for simplicity

    new_fwd_lines = []
    new_rev_lines = []

    with LEASES_FILE.open(newline="") as csvfile:
        reader = csv.reader(csvfile)
        for row in reader:
            if not row or row[0].startswith("#"):
                continue

            try:
                address, hwaddr, client_id, valid_lifetime, expire, subnet_id, fqdn_fwd, fqdn_rev, hostname, state, user_context = row
            except ValueError:
                # malformed line
                continue

            hostname = hostname.strip()
            if not hostname:
                continue

            try:
                ip = ipaddress.ip_address(address)
            except ValueError:
                continue

            if ip not in NETWORK:
                continue

            fqdn = f"{hostname}.{DOMAIN.rstrip('.')}".lower()
            last_octet = ip_to_last_octet(address)

            # Check if A record already exists
            if (fqdn, str(ip)) not in existing_fwd:
                new_fwd_lines.append(f"{hostname:<10} IN      A       {address}")
                existing_fwd.add((fqdn, str(ip)))

            # Check if PTR record already exists
            if (last_octet, fqdn) not in existing_rev:
                new_rev_lines.append(f"{last_octet:<7} IN      PTR     {fqdn}.")
                existing_rev.add((last_octet, fqdn))

    # If nothing to add, exit quietly
    if not new_fwd_lines and not new_rev_lines:
        return

    # Append new A records near the end of the forward zone file
    if new_fwd_lines:
        fwd_zone = fwd_zone.rstrip() + "\n" + "\n".join(new_fwd_lines) + "\n"
        fwd_zone = bump_serial(fwd_zone)
        save_file(FWD_ZONE_FILE, fwd_zone)

    # Append new PTR records near the end of the reverse zone file
    if new_rev_lines:
        rev_zone = rev_zone.rstrip() + "\n" + "\n".join(new_rev_lines) + "\n"
        rev_zone = bump_serial(rev_zone)
        save_file(REV_ZONE_FILE, rev_zone)

    # Reload BIND
    subprocess.run(["rndc", "reload"], check=False)

if __name__ == "__main__":
    main()
