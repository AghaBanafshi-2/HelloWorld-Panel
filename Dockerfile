FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir \
    fastapi==0.104.1 \
    "uvicorn[standard]==0.24.0" \
    httpx==0.25.1 \
    websockets==12.0 \
    aiofiles>=23.2.1

RUN mkdir -p /data

# ══════════════════════════════════════════════════════════════════════════════
# sni.txt
# ══════════════════════════════════════════════════════════════════════════════
RUN cat <<'EOF' > /app/sni.txt
varzesh3.com
digikala.com
aparat.com
divar.ir
irna.ir
isna.ir
tasnimnews.ir
farsnews.ir
khabaronline.ir
entekhab.ir
tabnak.ir
yjc.ir
hamshahrionline.ir
mashreghnews.ir
akharinkhabar.ir
bartarinha.ir
donya-e-eqtesad.com
rubika.ir
cafebazaar.ir
myket.ir
snapp.ir
balad.ir
neshan.org
alibaba.ir
sheypoor.com
esam.ir
tapsell.ir
metrix.ir
yektanet.com
eitaa.ir
bale.ai
ble.ir
wisgoon.com
shaparak.ir
cbi.ir
tgju.org
arzdigital.com
tabdeal.org
emofid.com
easytrader.ir
bahesab.ir
bitpin.ir
tala.ir
mci.ir
irancell.ir
tamin.ir
post.ir
my.gov.ir
tax.gov.ir
medu.ir
iau.ir
ut.ac.ir
sharif.ir
khamenei.ir
leader.ir
presstv.ir
torob.com
emalls.ir
khanoumi.com
mrbilit.com
jobinja.com
jobvision.ir
e-estekhdam.com
paziresh24.com
mosbatesabz.com
bama.ir
ikco.ir
saipacorp.com
soft98.ir
zoomit.ir
abadis.ir
google.com
mail.google.com
dl.google.com
cdn.jsdelivr.net
www.microsoft.com
www.bing.com
EOF

# ══════════════════════════════════════════════════════════════════════════════
# speed_limit.py
# ══════════════════════════════════════════════════════════════════════════════
RUN cat <<'EOF' > /app/speed_limit.py
# speed_limit.py — per-config bandwidth throttling (token bucket)
import asyncio
import time
from main import LINKS

_buckets: dict = {}
MIN_RATE = 1024
MIN_BURST = 16 * 1024

class _Bucket:
    __slots__ = ("rate", "capacity", "tokens", "last")
    def __init__(self, rate_bytes_per_sec: float):
        self.rate = max(rate_bytes_per_sec, MIN_RATE)
        self.capacity = max(self.rate, MIN_BURST)
        self.tokens = self.capacity
        self.last = time.monotonic()
    def _refill(self):
        now = time.monotonic()
        elapsed = now - self.last
        if elapsed > 0:
            self.last = now
            self.tokens = min(self.capacity, self.tokens + elapsed * self.rate)
    async def consume(self, n: int):
        while True:
            self._refill()
            if self.tokens >= n:
                self.tokens -= n
                return
            deficit = n - self.tokens
            wait = deficit / self.rate
            await asyncio.sleep(min(max(wait, 0.004), 0.5))

def _get_bucket(uuid: str, rate: int) -> _Bucket:
    b = _buckets.get(uuid)
    if b is None or b.rate != max(rate, MIN_RATE):
        b = _Bucket(rate)
        _buckets[uuid] = b
    return b

async def throttle(uuid: str, nbytes: int):
    if nbytes <= 0:
        return
    link = LINKS.get(uuid)
    rate = int((link or {}).get("speed_limit_bytes", 0) or 0)
    if rate <= 0:
        return
    bucket = _get_bucket(uuid, rate)
    await bucket.consume(nbytes)

def reset_bucket(uuid: str):
    _buckets.pop(uuid, None)
EOF

# ══════════════════════════════════════════════════════════════════════════════
# relay_vless.py
# ══════════════════════════════════════════════════════════════════════════════
RUN cat <<'EOF' > /app/relay_vless.py
# relay_vless.py — WebSocket <-> TCP relay for VLESS/WS
import asyncio
import secrets
from datetime import datetime

from fastapi import WebSocket, WebSocketDisconnect

from main import (
    LINKS, LINKS_LOCK, stats, hourly_traffic, connections,
    error_logs, logger, is_link_allowed, is_ip_allowed,
    save_state, log_activity, now_ir,
)
from speed_limit import throttle

RELAY_BUF = 256 * 1024

def _ws_client_ip(ws: WebSocket) -> str:
    fwd = ws.headers.get("x-forwarded-for")
    if fwd:
        return fwd.split(",")[0].strip()
    real_ip = ws.headers.get("x-real-ip")
    if real_ip:
        return real_ip.strip()
    return ws.client.host if ws.client else "unknown"

async def parse_vless_header(chunk: bytes):
    if len(chunk) < 24:
        raise ValueError("chunk too small")
    pos = 1
    pos += 16
    addon_len = chunk[pos]; pos += 1 + addon_len
    command = chunk[pos]; pos += 1
    port = int.from_bytes(chunk[pos:pos+2], "big"); pos += 2
    addr_type = chunk[pos]; pos += 1
    if addr_type == 1:
        address = ".".join(str(b) for b in chunk[pos:pos+4]); pos += 4
    elif addr_type == 2:
        dlen = chunk[pos]; pos += 1
        address = chunk[pos:pos+dlen].decode("utf-8", errors="ignore"); pos += dlen
    elif addr_type == 3:
        ab = chunk[pos:pos+16]; pos += 16
        address = ":".join(f"{ab[i]:02x}{ab[i+1]:02x}" for i in range(0, 16, 2))
    else:
        raise ValueError(f"unknown addr type: {addr_type}")
    return command, address, port, chunk[pos:]

async def check_and_use(uid: str, n: int) -> bool:
    async with LINKS_LOCK:
        link = LINKS.get(uid)
        if link is None:
            return False
        if not is_link_allowed(link):
            return False
        link["used_bytes"] += n
        stats["total_bytes"] += n
        hourly_traffic[now_ir().strftime("%H:00")] += n
    return True

async def relay_ws_to_tcp(ws: WebSocket, writer: asyncio.StreamWriter, conn_id: str, uid: str):
    try:
        while True:
            msg = await ws.receive()
            if msg["type"] == "websocket.disconnect":
                break
            data = msg.get("bytes") or (msg.get("text") or "").encode()
            if not data:
                continue
            if not await check_and_use(uid, len(data)):
                await ws.close(code=1008, reason="quota/disabled/unknown")
                break
            await throttle(uid, len(data))
            stats["total_requests"] += 1
            connections[conn_id]["bytes"] += len(data)
            writer.write(data)
            if writer.transport.get_write_buffer_size() > RELAY_BUF:
                await writer.drain()
    except (WebSocketDisconnect, Exception):
        pass
    finally:
        try:
            writer.write_eof()
        except Exception:
            pass

async def relay_tcp_to_ws(ws: WebSocket, reader: asyncio.StreamReader, conn_id: str, uid: str):
    first = True
    try:
        while True:
            data = await reader.read(RELAY_BUF)
            if not data:
                break
            if not await check_and_use(uid, len(data)):
                await ws.close(code=1008, reason="quota/disabled/unknown")
                break
            await throttle(uid, len(data))
            connections[conn_id]["bytes"] += len(data)
            payload = (b"\x00\x00" + data) if first else data
            first = False
            await ws.send_bytes(payload)
    except Exception:
        pass

async def websocket_tunnel(ws: WebSocket, uuid: str):
    await ws.accept()
    async with LINKS_LOCK:
        link = LINKS.get(uuid)
    if not is_link_allowed(link):
        logger.warning(f"WS rejected uuid={uuid[:8]}…")
        await ws.close(code=1008, reason="not authorized")
        return
    ip = _ws_client_ip(ws)
    if not is_ip_allowed(link, uuid, ip):
        logger.warning(f"WS rejected uuid={uuid[:8]}… ip={ip}")
        log_activity("connection", f"{ip} -> {link.get('label','?')} (ip limit)", "warn")
        await ws.close(code=1008, reason="ip limit reached")
        return
    conn_id = secrets.token_urlsafe(6)
    connections[conn_id] = {
        "uuid": uuid, "ip": ip, "transport": "vless-ws",
        "connected_at": datetime.now().isoformat(), "bytes": 0,
    }
    logger.info(f"WS [{conn_id}] uuid={uuid[:8]}… ip={ip} total={len(connections)}")
    log_activity("connection", f"{ip} ({link.get('label','?')})", "info")
    writer = None
    try:
        first_msg = await asyncio.wait_for(ws.receive(), timeout=15.0)
        if first_msg["type"] == "websocket.disconnect":
            return
        first_chunk = first_msg.get("bytes") or (first_msg.get("text") or "").encode()
        if not first_chunk:
            return
        command, address, port, payload = await parse_vless_header(first_chunk)
        if not await check_and_use(uuid, len(first_chunk)):
            await ws.close(code=1008, reason="quota/disabled")
            return
        stats["total_requests"] += 1
        connections[conn_id]["bytes"] += len(first_chunk)
        logger.info(f"[{conn_id}] -> {address}:{port}")
        reader, writer = await asyncio.wait_for(
            asyncio.open_connection(address, port), timeout=10.0
        )
        sock = writer.transport.get_extra_info("socket")
        if sock:
            import socket
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        if payload:
            writer.write(payload)
            await writer.drain()
        done, pending = await asyncio.wait(
            {
                asyncio.create_task(relay_ws_to_tcp(ws, writer, conn_id, uuid)),
                asyncio.create_task(relay_tcp_to_ws(ws, reader, conn_id, uuid)),
            },
            return_when=asyncio.FIRST_COMPLETED,
        )
        for t in pending:
            t.cancel()
            try:
                await t
            except asyncio.CancelledError:
                pass
        asyncio.create_task(save_state())
    except WebSocketDisconnect:
        pass
    except asyncio.TimeoutError:
        stats["total_errors"] += 1
        error_logs.append({"error": "connection timeout", "time": datetime.now().isoformat()})
    except Exception as exc:
        stats["total_errors"] += 1
        error_logs.append({"error": str(exc), "time": datetime.now().isoformat()})
        logger.error(f"WS error [{conn_id}]: {exc}")
    finally:
        if writer:
            try:
                writer.close()
                await writer.wait_closed()
            except Exception:
                pass
        connections.pop(conn_id, None)
        logger.info(f"WS closed [{conn_id}] total={len(connections)}")
EOF

# ══════════════════════════════════════════════════════════════════════════════
# main.py
# ══════════════════════════════════════════════════════════════════════════════
RUN cat <<'PYEOF' > /app/main.py
import asyncio
import json
import os
import hashlib
import secrets
import time
import aiofiles
from datetime import datetime
from zoneinfo import ZoneInfo
from urllib.parse import quote
from collections import deque, defaultdict
from pathlib import Path

from fastapi import FastAPI, Request, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import Response, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import httpx
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("helloworld")

IRAN_TZ = ZoneInfo("Asia/Tehran")
app = FastAPI(title="helloworld", docs_url=None, redoc_url=None)

DATA_DIR = Path(os.environ.get("DATA_DIR", "/data"))
DATA_FILE = DATA_DIR / "hw_state.json"
SECRET_FILE = DATA_DIR / "hw_secret.key"
SNI_FILE = Path(__file__).parent / "sni.txt"
SAVE_LOCK = asyncio.Lock()

def _load_or_create_secret() -> str:
    env_secret = os.environ.get("SECRET_KEY")
    if env_secret:
        return env_secret
    try:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        if SECRET_FILE.exists():
            existing = SECRET_FILE.read_text(encoding="utf-8").strip()
            if existing:
                return existing
        new_secret = secrets.token_urlsafe(32)
        SECRET_FILE.write_text(new_secret, encoding="utf-8")
        return new_secret
    except Exception as e:
        logger.warning(f"Could not persist SECRET_KEY: {e}")
        return secrets.token_urlsafe(32)

def _load_sni_list() -> list[str]:
    try:
        if SNI_FILE.exists():
            lines = SNI_FILE.read_text(encoding="utf-8").splitlines()
            return [l.strip() for l in lines if l.strip() and not l.strip().startswith("#")]
    except Exception as e:
        logger.warning(f"Could not load sni.txt: {e}")
    return ["www.microsoft.com", "cdn.jsdelivr.net", "google.com"]

CONFIG = {
    "port": int(os.environ.get("PORT", 8000)),
    "secret": _load_or_create_secret(),
    "host": os.environ.get("RAILWAY_PUBLIC_DOMAIN", "localhost"),
    "fake_sni": os.environ.get("FAKE_SNI", "").strip(),
    "cipher_suites": os.environ.get(
        "CIPHER_SUITES",
        "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256:"
        "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256:"
        "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256:"
        "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256:"
        "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384:"
        "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384:"
        "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA:"
        "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA:"
        "TLS_RSA_WITH_AES_128_GCM_SHA256:"
        "TLS_RSA_WITH_AES_256_GCM_SHA384:"
        "TLS_RSA_WITH_AES_128_CBC_SHA:"
        "TLS_RSA_WITH_AES_256_CBC_SHA"
    ).strip(),
    "sni_list": _load_sni_list(),
}

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"], allow_headers=["*"],
)

async def load_state():
    global LINKS
    try:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        if DATA_FILE.exists():
            async with aiofiles.open(DATA_FILE, "r", encoding="utf-8") as f:
                raw = await f.read()
            data = json.loads(raw)
            LINKS.update(data.get("links", {}))
            logger.info(f"State loaded: {len(LINKS)} links")
    except Exception as e:
        logger.warning(f"Could not load state: {e}")

async def save_state():
    async with SAVE_LOCK:
        try:
            DATA_DIR.mkdir(parents=True, exist_ok=True)
            data = {"links": dict(LINKS), "saved_at": datetime.now().isoformat()}
            tmp = DATA_FILE.with_suffix(".tmp")
            async with aiofiles.open(tmp, "w", encoding="utf-8") as f:
                await f.write(json.dumps(data, ensure_ascii=False, indent=2))
            tmp.replace(DATA_FILE)
        except Exception as e:
            logger.warning(f"Could not save state: {e}")

connections: dict = {}
stats = {"total_bytes": 0, "total_requests": 0, "total_errors": 0, "start_time": time.time()}
error_logs: deque = deque(maxlen=50)
activity_logs: deque = deque(maxlen=200)
hourly_traffic: dict = defaultdict(int)
http_client: httpx.AsyncClient | None = None
LINKS: dict = {}
LINKS_LOCK = asyncio.Lock()
SUBS: dict = {}

DEFAULT_PROTOCOL = "vless-ws"
FINGERPRINTS = ("chrome", "firefox", "safari", "ios", "android", "edge", "360", "qq", "random", "randomized", "unsafe")
DEFAULT_FINGERPRINT = "chrome"
DEFAULT_ALPN_BY_PROTOCOL = {"vless-ws": "http/1.1"}
DEFAULT_PORT = 443
MIN_PORT, MAX_PORT = 1, 65535
DEFAULT_SPEED_LIMIT = 0

def log_activity(kind: str, message: str, level: str = "info"):
    activity_logs.append({"kind": kind, "level": level, "message": message, "time": datetime.now().isoformat()})

@app.on_event("startup")
async def startup():
    global http_client
    limits = httpx.Limits(max_connections=500, max_keepalive_connections=100)
    timeout = httpx.Timeout(30.0, connect=10.0)
    http_client = httpx.AsyncClient(limits=limits, timeout=timeout, follow_redirects=True)
    await load_state()
    await ensure_default_link()
    await log_startup_link()
    log_activity("system", "started", "ok")
    logger.info(f"helloworld started on port {CONFIG['port']}")
    logger.info(f"sni.txt loaded: {len(CONFIG['sni_list'])} domains")

@app.on_event("shutdown")
async def shutdown():
    await save_state()
    if http_client:
        await http_client.aclose()

def get_host(request: Request | None = None) -> str:
    if request is not None:
        h = request.headers.get("x-forwarded-host") or request.headers.get("host")
        if h:
            h = h.split(":")[0]
            CONFIG["host"] = h
            return h
    return os.environ.get("RAILWAY_PUBLIC_DOMAIN", CONFIG["host"])

def generate_uuid() -> str:
    h = secrets.token_hex(16)
    return f"{h[:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:32]}"

def now_ir() -> datetime:
    return datetime.now(IRAN_TZ)

def _build_params(uid, host, protocol, fp, alpn_val, sni_val, extra=None):
    params = {
        "encryption": "none", "security": "tls", "type": "ws",
        "host": host, "path": f"/ws/{uid}", "sni": sni_val, "fp": fp, "alpn": alpn_val,
    }
    if extra:
        params.update(extra)
    return params

def generate_vless_link(uuid, host, remark="hw", fingerprint=None, alpn=None, port=None, fake_sni=None):
    fp = (fingerprint or DEFAULT_FINGERPRINT).strip() or DEFAULT_FINGERPRINT
    if fp not in FINGERPRINTS:
        fp = DEFAULT_FINGERPRINT
    alpn_val = (alpn or "").strip() or DEFAULT_ALPN_BY_PROTOCOL.get("vless-ws", "http/1.1")
    port_val = port or DEFAULT_PORT
    if not (MIN_PORT <= port_val <= MAX_PORT):
        port_val = DEFAULT_PORT
    sni_val = fake_sni or CONFIG.get("fake_sni") or host
    params = _build_params(uuid, host, "vless-ws", fp, alpn_val, sni_val)
    query = "&".join(f"{k}={quote(str(v))}" for k, v in params.items())
    return f"vless://{uuid}@{host}:{port_val}?{query}#{quote(remark)}"

def generate_vless_link_patt(uuid, host, sni="", remark="hw-patt"):
    sni_val = sni or CONFIG.get("fake_sni") or host
    params = _build_params(uuid, host, "vless-ws", "unsafe", "http/1.1", sni_val,
                           extra={"fm": "tlshello", "cs": CONFIG.get("cipher_suites", "")})
    query = "&".join(f"{k}={quote(str(v))}" for k, v in params.items())
    return f"vless://{uuid}@{host}:443?{query}#{quote(remark)}"

def vless_link_for_link(link, uid, host):
    return generate_vless_link(
        uid, host, remark=f"hw-{link.get('label','')}",
        fingerprint=link.get("fingerprint"), alpn=link.get("alpn"), port=link.get("port"),
    )

def uptime() -> str:
    secs = int(time.time() - stats["start_time"])
    h, m, s = secs // 3600, (secs % 3600) // 60, secs % 60
    return f"{h:02d}:{m:02d}:{s:02d}"

def is_link_expired(link):
    exp = link.get("expires_at")
    if not exp:
        return False
    try:
        return datetime.now() > datetime.fromisoformat(exp)
    except Exception:
        return False

def is_link_allowed(link):
    if link is None:
        return False
    if not link.get("active", True):
        return False
    if is_link_expired(link):
        return False
    lb = link.get("limit_bytes", 0)
    if lb > 0 and link.get("used_bytes", 0) >= lb:
        return False
    return True

def unique_ips_for_uuid(uuid):
    return {c.get("ip") for c in connections.values() if c.get("uuid") == uuid and c.get("ip")}

def is_ip_allowed(link, uuid, ip):
    if link is None:
        return False
    limit = int(link.get("ip_limit", 0) or 0)
    if limit <= 0:
        return True
    ips = unique_ips_for_uuid(uuid)
    if ip in ips:
        return True
    return len(ips) < limit

_default_link_created = False

async def ensure_default_link():
    global _default_link_created
    if _default_link_created:
        return
    async with LINKS_LOCK:
        if not any(l.get("is_default") for l in LINKS.values()):
            uid = hashlib.sha256(f"default{CONFIG['secret']}".encode()).hexdigest()
            uid = f"{uid[:8]}-{uid[8:12]}-{uid[12:16]}-{uid[16:20]}-{uid[20:32]}"
            if uid not in LINKS:
                LINKS[uid] = {
                    "label": "default", "limit_bytes": 0, "used_bytes": 0,
                    "created_at": datetime.now().isoformat(), "active": True,
                    "expires_at": None, "note": "", "is_default": True,
                    "protocol": DEFAULT_PROTOCOL, "fingerprint": DEFAULT_FINGERPRINT,
                    "alpn": "", "port": DEFAULT_PORT, "ip_limit": 0,
                    "speed_limit_bytes": DEFAULT_SPEED_LIMIT,
                }
                asyncio.create_task(save_state())
                logger.info(f"default link created: {uid}")
        _default_link_created = True

async def log_startup_link():
    host = os.environ.get("RAILWAY_PUBLIC_DOMAIN", "").strip() or CONFIG["host"]
    async with LINKS_LOCK:
        target_uid = None
        target_link = None
        for uid, link in LINKS.items():
            if is_link_allowed(link):
                target_uid = uid
                target_link = link
                break
    if not target_uid:
        logger.warning("no active link found for logging")
        return
    vless_simple = vless_link_for_link(target_link, target_uid, host)
    vless_patt = generate_vless_link_patt(target_uid, host, sni=CONFIG.get("fake_sni", ""))
    logger.info("=" * 78)
    logger.info("Standard link (v2rayNG / v2rayN):")
    logger.info(vless_simple)
    logger.info("-" * 78)
    logger.info("PattNG link (fp=unsafe + finalMask + cipher suites):")
    logger.info(vless_patt)
    logger.info("-" * 78)
    logger.info(f"FAKE_SNI: {CONFIG['fake_sni'] or '(not set)'}")
    logger.info(f"SNI list: {len(CONFIG['sni_list'])} domains")
    logger.info("=" * 78)

@app.get("/")
async def root():
    return {"status": "ok"}

@app.get("/health")
async def health():
    return {"status": "ok", "connections": len(connections), "uptime": uptime()}

@app.get("/sub/{uuid}")
async def subscription_single(uuid: str, request: Request):
    import base64
    async with LINKS_LOCK:
        link = LINKS.get(uuid)
    if not link or not is_link_allowed(link):
        raise HTTPException(status_code=404, detail="not found")
    host = get_host(request)
    vless = vless_link_for_link(link, uuid, host)
    content = base64.b64encode(vless.encode()).decode()
    return Response(content=content, media_type="text/plain")

@app.get("/get/config")
async def get_config(request: Request, sni: str = ""):
    sni = (sni or "").strip()
    if not sni:
        raise HTTPException(status_code=400, detail="sni is required")
    if len(sni) > 253 or not all(c.isalnum() or c in ".-_" for c in sni):
        raise HTTPException(status_code=400, detail="invalid sni")
    host = get_host(request)
    async with LINKS_LOCK:
        target_uid = None
        target_link = None
        for uid, link in LINKS.items():
            if is_link_allowed(link):
                target_uid = uid
                target_link = link
                break
    if not target_uid:
        raise HTTPException(status_code=404, detail="no active config")
    standard = generate_vless_link(
        target_uid, host, remark=f"hw-{sni}",
        fingerprint=target_link.get("fingerprint"), alpn=target_link.get("alpn"),
        port=target_link.get("port"), fake_sni=sni,
    )
    patt = generate_vless_link_patt(target_uid, host, sni=sni, remark=f"hw-patt-{sni}")
    return {"standard": standard, "patt": patt, "sni": sni, "uuid": target_uid, "host": host}

from relay_vless import websocket_tunnel
app.add_api_websocket_route("/ws/{uuid}", websocket_tunnel)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=CONFIG["port"], log_level="info", workers=1)
PYEOF

ENV PORT=8000
EXPOSE 8000

CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000} --workers 1"]
