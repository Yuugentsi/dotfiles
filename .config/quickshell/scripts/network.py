import json
import ipaddress
import os
import re
import shutil
import subprocess
import sys


DNS_PROVIDERS = {
    "adguard": {"ipv4": ["94.140.14.14", "94.140.15.15"], "ipv6": ["2a10:50c0::ad1:ff", "2a10:50c0::ad2:ff"]},
    "quad9": {"ipv4": ["9.9.9.9", "149.112.112.112"], "ipv6": ["2620:fe::fe", "2620:fe::9"]},
    "cloudflare": {"ipv4": ["1.1.1.1", "1.0.0.1"], "ipv6": ["2606:4700:4700::1111", "2606:4700:4700::1001"]},
    "google": {"ipv4": ["8.8.8.8", "8.8.4.4"], "ipv6": ["2001:4860:4860::8888", "2001:4860:4860::8844"]},
}


class NetworkError(Exception):
    pass


def fields(line):
    values = []
    current = []
    escaped = False
    for char in line:
        if escaped:
            current.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            values.append("".join(current))
            current = []
        else:
            current.append(char)
    if escaped:
        current.append("\\")
    values.append("".join(current))
    return values


def run(arguments, password=None, wait=12):
    command = ["nmcli", "--colors", "no", "--wait", str(wait)]
    if password is not None:
        command.append("--ask")
    command.extend(arguments)
    environment = dict(os.environ, LC_ALL="C")
    try:
        return subprocess.run(command, input=(password + "\n") if password is not None else "", capture_output=True, text=True, timeout=wait + 4, env=environment)
    except subprocess.TimeoutExpired:
        raise NetworkError("The network request timed out. Try again.") from None


def adapters():
    result = run(["-t", "-f", "DEVICE,TYPE,STATE", "device", "status"])
    if result.returncode:
        raise NetworkError("NetworkManager is unavailable.")
    rows = [fields(line) for line in result.stdout.splitlines()]
    return sorted([row for row in rows if len(row) == 3 and row[1] == "wifi"], key=lambda row: row[2] != "connected")


def device_for(name=""):
    devices = adapters()
    if name:
        for device in devices:
            if device[0] == name:
                return device
        raise NetworkError("The Wi-Fi adapter is no longer available.")
    return devices[0] if devices else None


def network_rows(text):
    grouped = {}
    for line in text.splitlines():
        row = fields(line)
        if len(row) not in (5, 6):
            continue
        active, ssid, strength, security, bssid = row[:5]
        frequency = re.search(r"\d+", row[5]) if len(row) == 6 else None
        mhz = int(frequency.group()) if frequency else 0
        band = "bg" if 2400 <= mhz < 2500 else "a" if 4900 <= mhz < 5925 else "6" if mhz >= 5925 else ""
        if not ssid or not re.fullmatch(r"(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}", bssid):
            continue
        try:
            signal = max(0, min(100, int(strength)))
        except ValueError:
            signal = 0
        secured = security not in ("", "--")
        entry = {"ssid": ssid, "bssid": bssid, "signal": signal, "security": security if secured else "Open", "secured": secured, "active": active == "*", "band": band, "bands": [band] if band else []}
        key = (ssid, security)
        previous = grouped.get(key)
        bands = sorted(set((previous["bands"] if previous else []) + entry["bands"]))
        if previous is None or (entry["active"], signal) > (previous["active"], previous["signal"]):
            grouped[key] = entry
        grouped[key]["bands"] = bands
    return sorted(grouped.values(), key=lambda item: (not item["active"], -item["signal"], item["ssid"].casefold()))


def recent_profile():
    result = run(["-t", "-f", "UUID,TYPE,TIMESTAMP", "connection", "show"])
    candidates = []
    if result.returncode == 0:
        for line in result.stdout.splitlines():
            row = fields(line)
            if len(row) == 3 and row[1] in ("wifi", "802-11-wireless") and row[2].isdigit() and int(row[2]) > 0:
                candidates.append((int(row[2]), row[0]))
    return max(candidates)[1] if candidates else ""


def snapshot(preferred_uuid="", rescan=False):
    radio = run(["-t", "-f", "WIFI-HW,WIFI", "general"])
    if radio.returncode:
        raise NetworkError("NetworkManager is unavailable.")
    flags = fields(radio.stdout.strip())
    blocked = len(flags) > 0 and flags[0] != "enabled"
    enabled = len(flags) > 1 and flags[1] == "enabled"
    device = device_for()
    state = {"available": device is not None, "enabled": enabled, "blocked": blocked, "device": device[0] if device else "", "connected": "", "networks": [], "bandMode": "", "actualBand": "", "availableBands": [], "dnsMode": "automatic", "profileUuid": ""}
    if device is None:
        return state
    uuid = active_uuid(device[0])
    if enabled and not blocked:
        result = run(["-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,BSSID,FREQ", "device", "wifi", "list", "ifname", device[0], "--rescan", "yes" if rescan else "no"])
        if result.returncode:
            raise NetworkError("Could not read available Wi-Fi networks.")
        state["networks"] = network_rows(result.stdout)
        active = next((item for item in state["networks"] if item["active"]), None)
        if active:
            state["connected"] = active["ssid"]
            state["actualBand"] = active["band"]
            state["availableBands"] = active["bands"]
    if not uuid:
        uuid = preferred_uuid if re.fullmatch(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", preferred_uuid) else recent_profile()
    if uuid:
        try:
            state["bandMode"] = profile_value(uuid, "802-11-wireless.band")
            state["dnsMode"] = dns_provider(dns_settings(uuid))
            state["profileUuid"] = uuid
        except NetworkError:
            pass
    return state


def active_uuid(device):
    result = run(["-g", "GENERAL.CON-UUID", "device", "show", device])
    value = result.stdout.strip()
    return value if result.returncode == 0 and re.fullmatch(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", value) else ""


def profile_value(uuid, setting):
    result = run(["-g", setting, "connection", "show", "uuid", uuid])
    if result.returncode:
        raise NetworkError("Could not read the current Wi-Fi profile.")
    value = fields(result.stdout.strip())[0]
    return "" if value == "--" else value


def dns_settings(uuid):
    properties = ["ipv4.dns", "ipv4.ignore-auto-dns", "ipv6.dns", "ipv6.ignore-auto-dns", "ipv4.method", "ipv6.method"]
    result = run(["-g", ",".join(properties), "connection", "show", "uuid", uuid])
    values = result.stdout.splitlines()
    if result.returncode or len(values) != len(properties):
        raise NetworkError("Could not read the connection DNS settings.")
    return {key: fields(value)[0] for key, value in zip(properties, values)}


def addresses(value):
    try:
        return {str(ipaddress.ip_address(token)) for token in re.split(r"[,;\s]+", value) if token and token != "--"}
    except ValueError:
        return set()


def dns_provider(settings):
    supported = [family for family in ("ipv4", "ipv6") if settings[family + ".method"] in ("auto", "manual", "dhcp")]
    if not supported:
        return "custom"
    if all(not addresses(settings[family + ".dns"]) and settings[family + ".ignore-auto-dns"] in ("no", "false", "0") for family in supported):
        return "automatic"
    for name, provider in DNS_PROVIDERS.items():
        if all(addresses(settings[family + ".dns"]) == set(provider[family]) and settings[family + ".ignore-auto-dns"] in ("yes", "true", "1") for family in supported):
            return name
    return "custom"


def set_dns(device, provider):
    if provider != "automatic" and provider not in DNS_PROVIDERS:
        raise NetworkError("Invalid DNS provider.")
    uuid = active_uuid(device)
    if not uuid:
        raise NetworkError("Connect to Wi-Fi before changing DNS.")
    previous = dns_settings(uuid)
    changes = {}
    for family in ("ipv4", "ipv6"):
        if previous[family + ".method"] not in ("auto", "manual", "dhcp"):
            continue
        changes[family + ".dns"] = "" if provider == "automatic" else ",".join(DNS_PROVIDERS[provider][family])
        changes[family + ".ignore-auto-dns"] = "no" if provider == "automatic" else "yes"
    if not changes:
        raise NetworkError("This connection does not have a supported IP configuration.")
    if dns_provider(previous) == provider:
        return {"ok": True}
    command = ["connection", "modify", "uuid", uuid]
    for key, value in changes.items():
        command.extend([key, value])
    result = run(command)
    if result.returncode:
        raise NetworkError("NetworkManager could not update the DNS settings.")
    try:
        if active_uuid(device) == uuid:
            result = run(["device", "reapply", device])
            if result.returncode == 0:
                return {"ok": True}
    except (NetworkError, OSError):
        pass
    restore = ["connection", "modify", "uuid", uuid]
    for key in changes:
        restore.extend([key, "" if previous[key] == "--" else previous[key]])
    try:
        restored = run(restore)
        if restored.returncode == 0:
            if active_uuid(device) == uuid:
                run(["device", "reapply", device])
            raise NetworkError("DNS could not be applied without reconnecting. The previous settings were restored.")
    except OSError:
        pass
    raise NetworkError("Could not apply DNS or restore the previous settings. Check the connection settings.")


def switch_band(device, mode):
    if mode not in ("", "bg", "a"):
        raise NetworkError("Invalid Wi-Fi band.")
    uuid = active_uuid(device)
    if not uuid:
        raise NetworkError("Connect to a Wi-Fi network before changing bands.")
    current = profile_value(uuid, "802-11-wireless.band")
    if current == mode:
        return {"ok": True}
    state = snapshot()
    if mode and mode not in state["availableBands"]:
        raise NetworkError("This band is not currently available for the connected network. Refresh and try again.")
    channel = profile_value(uuid, "802-11-wireless.channel")
    bssid = profile_value(uuid, "802-11-wireless.bssid")
    result = run(["connection", "modify", "uuid", uuid, "802-11-wireless.channel", "", "802-11-wireless.band", mode, "802-11-wireless.bssid", ""])
    if result.returncode:
        raise NetworkError("Could not change the Wi-Fi band preference.")
    try:
        result = run(["connection", "up", "uuid", uuid, "ifname", device], wait=30)
        if result.returncode == 0:
            return {"ok": True}
    except NetworkError:
        pass
    recovered = False
    try:
        restored = run(["connection", "modify", "uuid", uuid, "802-11-wireless.channel", "", "802-11-wireless.band", current, "802-11-wireless.channel", "" if channel == "0" else channel, "802-11-wireless.bssid", bssid])
        if restored.returncode == 0:
            restored = run(["connection", "up", "uuid", uuid, "ifname", device], wait=30)
            recovered = restored.returncode == 0
    except (NetworkError, OSError):
        pass
    if recovered:
        raise NetworkError("The band switch failed. The previous connection was restored.")
    raise NetworkError("The band switch failed. Reconnect to your network to restore access.")


def perform(request):
    action = request.get("action", "state")
    if action == "state":
        return {"ok": True, "state": snapshot(str(request.get("profileUuid", "")), request.get("rescan") is True)}
    if action == "power":
        result = run(["radio", "wifi", "on" if request.get("enabled") is True else "off"])
    else:
        device = device_for(str(request.get("device", "")))
        if device is None:
            raise NetworkError("No Wi-Fi adapter found.")
        if action == "dns":
            return set_dns(device[0], request.get("provider"))
        if action == "band":
            return switch_band(device[0], request.get("mode"))
        if action == "scan":
            result = run(["device", "wifi", "rescan", "ifname", device[0]])
        elif action == "disconnect":
            result = run(["device", "disconnect", device[0]])
        elif action == "connect":
            bssid = str(request.get("bssid", ""))
            if not re.fullmatch(r"(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}", bssid):
                raise NetworkError("This network is no longer available. Refresh the list.")
            password = request.get("password")
            if password is not None and (not isinstance(password, str) or "\n" in password or "\r" in password or len(password) > 256):
                raise NetworkError("Enter a valid network password.")
            result = run(["device", "wifi", "connect", bssid, "ifname", device[0]], password=password, wait=25)
            if result.returncode:
                detail = (result.stdout + result.stderr).lower()
                needs_password = any(token in detail for token in ("secrets", "password", "security", "802-11-wireless-security"))
                return {"ok": False, "requiresPassword": needs_password and password is None, "error": "A password is required to connect." if needs_password and password is None else "Could not connect. Check the password and try again."}
        else:
            raise NetworkError("Unknown Wi-Fi action.")
    if result.returncode:
        detail = (result.stdout + result.stderr).lower()
        if "not authorized" in detail or "permission" in detail:
            raise NetworkError("NetworkManager did not authorize this action.")
        if action == "scan":
            raise NetworkError("Scanning is temporarily unavailable. Try again shortly.")
        raise NetworkError("The Wi-Fi action failed. Try again.")
    return {"ok": True}


def main():
    try:
        if not shutil.which("nmcli"):
            raise NetworkError("NetworkManager tools are not installed.")
        raw = sys.stdin.readline(16385)
        if len(raw) > 16384:
            raise NetworkError("The network request is too large.")
        request = json.loads(raw) if raw.strip() else {"action": "state"}
        if not isinstance(request, dict):
            raise NetworkError("Invalid Wi-Fi request.")
        response = perform(request)
    except (NetworkError, OSError, ValueError):
        error = sys.exc_info()[1]
        response = {"ok": False, "error": str(error) if isinstance(error, NetworkError) else "Could not process the Wi-Fi request."}
    print(json.dumps(response, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
