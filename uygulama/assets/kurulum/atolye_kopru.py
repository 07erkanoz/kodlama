#!/usr/bin/env python3
"""Atölye köprüsü.

Termux'ta (ya da herhangi bir Linux'ta) çalışır, telefondaki Atölye uygulaması
ona 127.0.0.1 üzerinden bağlanır. Köprü, kullanıcının kendi kurduğu ve kendi
hesabıyla giriş yaptığı Claude Code ve Codex CLI'larını sürer, olaylarını tek
bir ortak modele çevirir ve çalışma klasöründeki dosyaları uygulamaya sunar.

Protokoller (Saçmalık Odası'ndaki sürücülerden):
  claude -p --input-format stream-json --output-format stream-json
         --permission-prompt-tool stdio   → onaylar control_request olarak gelir
  codex app-server (JSON-RPC)             → onaylar sunucu isteği olarak gelir

Uygulama ↔ köprü: WebSocket, JSON. İlk mesaj {"op":"hello","token":…}.
Dosyalar (resim, PDF…) aynı porttan HTTP ile: GET /dosya?yol=…&t=<token>.
"""

from __future__ import annotations

import argparse
import asyncio
import base64
import csv
import io
import json
import mimetypes
import os
import re
import secrets
import shlex
import socket
import shutil
import signal
import sys
import time
import urllib.parse
import uuid
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

from websockets.asyncio.server import serve
from websockets.datastructures import Headers
from websockets.exceptions import ConnectionClosed
from websockets.http11 import Response

SURUM = "0.6.1"  # uygulama gerekenKopruSurumu ile karşılaştırır; köprü değişince artır
EV = Path(os.environ.get("ATOLYE_EV", Path.home() / ".atolye"))
KOK = Path(os.environ.get("ATOLYE_KOK", Path.home() / "projeler"))
ATLA = {".git", "node_modules", ".dart_tool", "build", ".gradle", "__pycache__", ".venv", "venv", ".atolye"}
METIN_SINIRI = 512 * 1024
TERMUX = "com.termux" in os.environ.get("PREFIX", "")
REHBER = Path(__file__).with_name("termux_rehberi.md")


def ajan_rehberi() -> str | None:
    """Termux'ta ajanlara verilen ortam bilgisi (paket kurma, Termux'a özgü sorunlar).
    Kullanıcının kendi CLAUDE.md / AGENTS.md dosyalarına dokunulmaz."""
    if not (TERMUX or os.environ.get("ATOLYE_REHBER")):
        return None
    try:
        return REHBER.read_text(encoding="utf-8")
    except OSError:
        return None
CIKTI_SINIRI = 4000
TARAMA_SINIRI = 20000

# Kullanıcının seçtiği çalışma biçimi → her CLI'ın kendi ayarı.
#   otomatik: ajan güvenli işleri kendisi onaylar (varsayılan)
#   sor     : her değişiklik ve komut için onay istenir
#   duzenle : dosya düzenlemeleri serbest, komutlar için onay
#   serbest : onay istenmez
#   otomatik: güvenli işleri ajan kendisi onaylar, yalnız riskli olanlar sorulur
CLAUDE_MOD = {"otomatik": "auto", "sor": "default", "duzenle": "acceptEdits",
              "serbest": "bypassPermissions", "plan": "plan"}
CODEX_MOD = {
    "otomatik": ("on-request", "workspace-write"),
    "sor": ("untrusted", "workspace-write"),
    "duzenle": ("on-request", "workspace-write"),
    "serbest": ("never", "danger-full-access"),
    "plan": ("untrusted", "read-only"),
}


def kisa(s, n=CIKTI_SINIRI):
    s = s if isinstance(s, str) else json.dumps(s, ensure_ascii=False)
    return s if len(s) <= n else s[: n - 1] + "…"


def simdi():
    return time.time()


# ---------------------------------------------------------------- yardımcılar


def guvenli_yol(yol: str | os.PathLike) -> Path:
    """Kök klasörün dışına çıkan yolları reddet."""
    p = Path(yol)
    if not p.is_absolute():
        p = KOK / p
    r = p.resolve()
    kok = KOK.resolve()
    if r != kok and kok not in r.parents:
        raise PermissionError(f"çalışma kökünün dışında: {yol}")
    return r


def goreli(yol: str, cwd: Path) -> str:
    try:
        return str(Path(yol).resolve().relative_to(cwd))
    except (ValueError, OSError):
        return yol


def tara(cwd: Path) -> dict[str, float]:
    """Çalışma klasörünün anlık görüntüsü: yol → değişme zamanı."""
    out: dict[str, float] = {}
    yigin = [cwd]
    while yigin and len(out) < TARAMA_SINIRI:
        d = yigin.pop()
        try:
            with os.scandir(d) as it:
                for e in it:
                    if e.name in ATLA:
                        continue
                    try:
                        if e.is_dir(follow_symlinks=False):
                            yigin.append(Path(e.path))
                        elif e.is_file(follow_symlinks=False):
                            out[e.path] = e.stat().st_mtime
                    except OSError:
                        pass
        except OSError:
            pass
    return out


def arac_ozeti(ad: str, girdi: dict, cwd: Path | None = None) -> str:
    g = girdi or {}
    for k in ("file_path", "notebook_path", "path", "command", "pattern", "url", "query", "description", "prompt"):
        if g.get(k):
            v = str(g[k])
            if cwd and k in ("file_path", "notebook_path", "path"):
                v = goreli(v, cwd)
            return kisa(v, 200)
    return ""


# ---------------------------------------------------------------- belgeler
#
# Ajanın ürettiği Office belgeleri telefonda okunabilsin diye köprü onları
# Markdown'a (Word, PowerPoint) ya da tabloya (Excel, CSV) çevirir. Yalnız
# Python'un kendi kütüphaneleri: Termux'a ek paket gerekmez.

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
S = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
A = "{http://schemas.openxmlformats.org/drawingml/2006/main}"
R = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
SATIR_SINIRI, SUTUN_SINIRI = 1000, 60


def _hucre(s: str) -> str:
    return s.replace("|", "\\|").replace("\n", " ").strip()


def _docx_paragraf(p) -> str:
    parcalar = []
    for r in p.iter(W + "r"):
        metin = "".join(t.text or "" for t in r.iter(W + "t"))
        if r.find(W + "tab") is not None:
            metin = "\t" + metin
        if not metin:
            continue
        rpr = r.find(W + "rPr")
        kalin = rpr is not None and rpr.find(W + "b") is not None
        egik = rpr is not None and rpr.find(W + "i") is not None
        if kalin and metin.strip():
            metin = f"**{metin.strip()}** "
        elif egik and metin.strip():
            metin = f"*{metin.strip()}* "
        parcalar.append(metin)
    metin = "".join(parcalar).strip()
    ppr = p.find(W + "pPr")
    if ppr is not None and metin:
        stil = ppr.find(W + "pStyle")
        ad = (stil.get(W + "val") if stil is not None else "") or ""
        seviye = ppr.find(W + "outlineLvl")
        m = re.search(r"(?:heading|ba[sş]l[iı]k)\s*(\d)", ad, re.I)
        if m or seviye is not None:
            n = int(m.group(1)) if m else int(seviye.get(W + "val", "0")) + 1
            return "#" * max(1, min(n, 6)) + " " + metin.replace("**", "")
        if ad.lower() in ("title", "konubaşlığı", "konubasligi"):
            return "# " + metin.replace("**", "")
        if ppr.find(W + "numPr") is not None:
            return "- " + metin
    return metin


def docx_md(yol: Path) -> str:
    with zipfile.ZipFile(yol) as z:
        kok = ET.fromstring(z.read("word/document.xml"))
    govde = kok.find(W + "body")
    bloklar = []  # her biri ayrı Markdown bloğu (paragraf, başlık, tablo)
    for e in list(govde) if govde is not None else []:
        if e.tag == W + "p":
            metin = _docx_paragraf(e)
            if metin:
                bloklar.append(metin)
            if e.find(".//" + W + "drawing") is not None:
                bloklar.append("*[resim]*")
        elif e.tag == W + "tbl":
            tablo = []
            for tr in e.iter(W + "tr"):
                tablo.append([_hucre(" ".join(_docx_paragraf(p) for p in tc.iter(W + "p"))) for tc in tr.iter(W + "tc")])
            if tablo:
                genislik = max(len(r) for r in tablo)
                tablo = [r + [""] * (genislik - len(r)) for r in tablo]
                satirlar = ["| " + " | ".join(tablo[0]) + " |", "|" + "---|" * genislik]
                satirlar += ["| " + " | ".join(r) + " |" for r in tablo[1:]]
                bloklar.append("\n".join(satirlar))
    # art arda liste maddeleri tek liste olsun
    out = []
    for b in bloklar:
        if out and b.startswith("- ") and out[-1].split("\n")[-1].startswith("- "):
            out[-1] += "\n" + b
        else:
            out.append(b)
    return "\n\n".join(out)


def pptx_md(yol: Path) -> str:
    with zipfile.ZipFile(yol) as z:
        slaytlar = sorted(
            (n for n in z.namelist() if re.match(r"ppt/slides/slide\d+\.xml$", n)),
            key=lambda n: int(re.search(r"(\d+)", n.rsplit("/", 1)[1]).group(1)),
        )
        out = []
        for i, n in enumerate(slaytlar, 1):
            kok = ET.fromstring(z.read(n))
            paragraflar = ["".join(t.text or "" for t in p.iter(A + "t")).strip() for p in kok.iter(A + "p")]
            paragraflar = [p for p in paragraflar if p]
            out.append(f"## Slayt {i}" + (f": {paragraflar[0]}" if paragraflar else ""))
            out += [f"- {p}" for p in paragraflar[1:]]
            out.append("")
    return "\n".join(out)


def _sutun_no(ref: str) -> int:
    n = 0
    for ch in re.match(r"[A-Z]+", ref).group(0):
        n = n * 26 + ord(ch) - 64
    return n - 1


def xlsx_tablo(yol: Path) -> list[dict]:
    with zipfile.ZipFile(yol) as z:
        ortak = []
        if "xl/sharedStrings.xml" in z.namelist():
            for si in ET.fromstring(z.read("xl/sharedStrings.xml")).iter(S + "si"):
                ortak.append("".join(t.text or "" for t in si.iter(S + "t")))
        iliskiler = {}
        rels = "xl/_rels/workbook.xml.rels"
        if rels in z.namelist():
            for r in ET.fromstring(z.read(rels)):
                hedef = r.get("Target", "")
                iliskiler[r.get("Id")] = hedef.lstrip("/") if hedef.startswith("/") else "xl/" + hedef
        sayfalar = []
        for sh in ET.fromstring(z.read("xl/workbook.xml")).iter(S + "sheet"):
            yol_ = iliskiler.get(sh.get(R + "id"))
            if not yol_ or yol_ not in z.namelist():
                continue
            satirlar: list[list[str]] = []
            for row in ET.fromstring(z.read(yol_)).iter(S + "row"):
                if len(satirlar) >= SATIR_SINIRI:
                    break
                satir: list[str] = []
                for c in row.iter(S + "c"):
                    no = _sutun_no(c.get("r", "A1")) if c.get("r") else len(satir)
                    if no >= SUTUN_SINIRI:
                        continue
                    tur, v = c.get("t"), c.find(S + "v")
                    if tur == "s" and v is not None:
                        deger = ortak[int(v.text)] if v.text and int(v.text) < len(ortak) else ""
                    elif tur == "inlineStr":
                        deger = "".join(t.text or "" for t in c.iter(S + "t"))
                    else:
                        deger = v.text if v is not None and v.text else ""
                        if re.fullmatch(r"-?\d+\.\d{6,}", deger):
                            deger = f"{float(deger):.6g}"
                    satir += [""] * (no - len(satir))
                    satir.append(deger)
                satirlar.append(satir)
            sayfalar.append({"ad": sh.get("name"), "satirlar": satirlar})
    return sayfalar


def csv_tablo(yol: Path) -> list[dict]:
    ham = yol.read_bytes()[: 4 * 1024 * 1024].decode("utf-8", errors="replace")
    try:
        lehce = csv.Sniffer().sniff(ham[:4096], delimiters=",;\t|")
    except csv.Error:
        lehce = csv.excel_tab if yol.suffix.lower() == ".tsv" else csv.excel
    satirlar = []
    for r in csv.reader(io.StringIO(ham), lehce):
        satirlar.append(r[:SUTUN_SINIRI])
        if len(satirlar) >= SATIR_SINIRI:
            break
    return [{"ad": yol.name, "satirlar": satirlar}]


def belge_oku(yol: Path) -> dict:
    u = yol.suffix.lower()
    if u == ".docx":
        return {"tur": "markdown", "metin": docx_md(yol)}
    if u == ".pptx":
        return {"tur": "markdown", "metin": pptx_md(yol)}
    if u in (".xlsx", ".xlsm"):
        return {"tur": "tablo", "sayfalar": xlsx_tablo(yol)}
    if u in (".csv", ".tsv"):
        return {"tur": "tablo", "sayfalar": csv_tablo(yol)}
    raise ValueError(f"bu belge türü çevrilemiyor: {u}")


# ---------------------------------------------------------------- komutlar
#
# Git, GitHub (gh) ve SSH işlemleri. Hepsi kullanıcının kendi araçlarıyla ve
# kendi kimliğiyle çalışır; köprü yalnız çağırır ve sonucu döndürür.

KOMUT_ORTAMI = {"GIT_TERMINAL_PROMPT": "0", "GH_PROMPT_DISABLED": "1", "NO_COLOR": "1", "GIT_PAGER": "cat"}


async def calistir(args: list[str], cwd: Path | str | None = None, sure: float = 120,
                   girdi: bytes | None = None) -> tuple[int, str, str]:
    try:
        p = await asyncio.create_subprocess_exec(
            *args, cwd=str(cwd) if cwd else None, env={**os.environ, **KOMUT_ORTAMI},
            stdin=asyncio.subprocess.PIPE if girdi is not None else asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    except FileNotFoundError:
        return 127, "", f"{args[0]} kurulu değil"
    try:
        o, e = await asyncio.wait_for(p.communicate(girdi), sure)
    except asyncio.TimeoutError:
        p.kill()
        return 124, "", f"zaman aşımı ({int(sure)} sn)"
    return p.returncode, o.decode(errors="replace"), e.decode(errors="replace")


def _sonuc(kod, out, err, ok_mesaj=""):
    if kod != 0:
        raise RuntimeError((err or out).strip()[-2000:] or f"çıkış kodu {kod}")
    return {"cikti": (out + err).strip()[-4000:] or ok_mesaj}


async def git_durum(cwd: Path) -> dict:
    kod, _, _ = await calistir(["git", "rev-parse", "--is-inside-work-tree"], cwd, 15)
    if kod != 0:
        return {"repo": False}
    _, ham, _ = await calistir(["git", "status", "--porcelain=v1", "-b", "-z", "--untracked-files=all"], cwd, 30)
    girdiler = ham.split("\0")
    dal, ileri, geri, takip = "", 0, 0, None
    dosyalar = []
    i = 0
    while i < len(girdiler):
        g = girdiler[i]
        i += 1
        if not g:
            continue
        if g.startswith("## "):
            bas = g[3:]
            m = re.match(r"(?:No commits yet on |Initial commit on )?([^.\s]+)(?:\.\.\.(\S+))?(?: \[(.*)\])?", bas)
            if m:
                dal, takip = m.group(1), m.group(2)
                for parca in (m.group(3) or "").split(","):
                    parca = parca.strip()
                    if parca.startswith("ahead"):
                        ileri = int(parca.split()[1])
                    elif parca.startswith("behind"):
                        geri = int(parca.split()[1])
            continue
        x, y, yol = g[0], g[1], g[3:]
        if x in "RC":
            i += 1  # yeniden adlandırmada eski yol ayrı girdidir
        tur = "yeni" if x == "?" else "silindi" if "D" in (x, y) else "eklendi" if x == "A" else \
            "ad" if x == "R" else "degisti"
        dosyalar.append({"yol": yol, "tam": str(cwd / yol), "tur": tur, "hazir": x not in " ?"})
    _, uzak, _ = await calistir(["git", "remote", "get-url", "origin"], cwd, 10)
    _, gunluk, _ = await calistir(["git", "log", "-8", "--pretty=%h%x09%s%x09%cr%x09%an"], cwd, 15)
    commitler = []
    for satir in gunluk.splitlines():
        p = satir.split("\t")
        if len(p) == 4:
            commitler.append({"kisa": p[0], "mesaj": p[1], "zaman": p[2], "yazar": p[3]})
    return {"repo": True, "dal": dal, "takip": takip, "ileri": ileri, "geri": geri,
            "uzak": uzak.strip() or None, "dosyalar": dosyalar, "commitler": commitler}


async def git_fark(cwd: Path, yol: str) -> dict:
    kod, out, _ = await calistir(["git", "diff", "HEAD", "--", yol], cwd, 30)
    if kod != 0 or not out.strip():
        _, out, _ = await calistir(["git", "diff", "--cached", "--", yol], cwd, 30)
    if not out.strip():
        # izlenmeyen dosya: tamamı eklenmiş gibi
        _, out, _ = await calistir(["git", "diff", "--no-index", "--", "/dev/null", yol], cwd, 30)
    return {"fark": out[:400_000]}


async def gh_durum() -> dict:
    if not shutil.which("gh"):
        return {"kurulu": False}
    kod, out, _ = await calistir(["gh", "api", "user", "--jq", ".login"], sure=20)
    return {"kurulu": True, "giris": kod == 0, "kullanici": out.strip() if kod == 0 else None}


SSH_ANAHTAR = Path.home() / ".ssh" / "id_ed25519"


def ssh_hedef(s: dict) -> list[str]:
    return ["ssh", "-T", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=30",
            "-p", str(s.get("port") or 22), f"{s['kullanici']}@{s['host']}" if s.get("kullanici") else s["host"]]


def uzak_komut(s: dict, klasor: str, args: list[str]) -> list[str]:
    """Uzak makinede giriş kabuğuyla (PATH yüklensin) klasöre geçip komutu çalıştır."""
    if klasor == "~" or klasor.startswith("~/"):  # tırnak içinde ~ açılmaz
        hedef = '"$HOME"' + (shlex.quote(klasor[1:]) if len(klasor) > 1 else "")
    else:
        hedef = shlex.quote(klasor)
    ic = f"cd {hedef} && exec {shlex.join(args)}"
    return ssh_hedef(s) + ["--", shlex.join(["bash", "-lc", ic])]


# ---------------------------------------------------------------- oturum


class Oturum:
    """Bir sohbet: bir ajan, bir çalışma klasörü, CLI'ın kendi oturum kimliği."""

    def __init__(self, kopru: "Kopru", veri: dict):
        self.k = kopru
        self.id: str = veri["id"]
        self.ajan: str = veri["ajan"]
        self.cwd = Path(veri["cwd"])
        self.baslik: str = veri.get("baslik") or self.cwd.name
        self.sid: str | None = veri.get("sid")
        self.mod: str = veri.get("mod", "otomatik")
        self.model: str | None = veri.get("model")
        self.effort: str | None = veri.get("effort")
        self.sunucu: str | None = veri.get("sunucu")  # uzak sunucu adı (yoksa bu cihaz)
        self.uzak_klasor: str | None = veri.get("uzak_klasor")
        self.olusturma: float = veri.get("olusturma", simdi())
        self.guncelleme: float = veri.get("guncelleme", self.olusturma)
        self.durum = "bos"  # bos | calisiyor
        self.surec: asyncio.subprocess.Process | None = None
        self.onaylar: dict[str, dict] = {}  # bekleyen onaylar: rid → olay
        self.hep_izin: set[str] = set()
        self.goruntu: dict[str, float] | None = None
        self.bildirilen: set[str] = set()
        self._okuyucu: asyncio.Task | None = None

    def veri(self) -> dict:
        return {
            "id": self.id, "ajan": self.ajan, "cwd": str(self.cwd), "baslik": self.baslik,
            "sid": self.sid, "mod": self.mod, "model": self.model, "effort": self.effort,
            "olusturma": self.olusturma, "guncelleme": self.guncelleme,
            "sunucu": self.sunucu, "uzak_klasor": self.uzak_klasor,
        }

    def ozet(self) -> dict:
        d = self.veri()
        d["durum"] = self.durum
        d["goreli"] = f"{self.sunucu}:{self.uzak_klasor}" if self.sunucu else goreli(str(self.cwd), KOK.resolve())
        return d

    # --- olay yayını

    def yay(self, olay: dict, kaydet: bool = True):
        olay = {"oturum": self.id, "zaman": simdi(), **olay}
        if kaydet:
            self.k.kayda_yaz(self.id, olay)
        self.k.yayinla(olay)

    def durum_ver(self, durum: str):
        if self.durum != durum:
            self.durum = durum
            self.yay({"ev": "durum", "durum": durum}, kaydet=False)
            self.k.oturumlari_kaydet()

    # --- dosya değişikliği

    def tur_basi(self):
        if self.sunucu:  # uzak klasör buradan taranamaz
            self.goruntu = None
            return
        self.goruntu = tara(self.cwd)
        self.bildirilen = set()

    def dosya(self, yol: str | None, eylem: str = "degisti"):
        if not yol:
            return
        tam = yol if os.path.isabs(yol) else str(self.cwd / yol)
        tam = os.path.normpath(tam)
        if tam in self.bildirilen:
            return
        self.bildirilen.add(tam)
        self.yay({"ev": "dosya", "yol": tam, "goreli": goreli(tam, self.cwd), "eylem": eylem})

    def tur_sonu(self):
        """Bash ya da Python ile üretilen dosyalar araç olaylarında görünmez: farkı bul."""
        if self.goruntu is None:
            return
        once, sonra = self.goruntu, tara(self.cwd)
        self.goruntu = None
        for yol, mt in sonra.items():
            if yol not in once:
                self.dosya(yol, "yeni")
            elif once[yol] != mt:
                self.dosya(yol, "degisti")
        for yol in once.keys() - sonra.keys():
            self.dosya(yol, "silindi")

    # --- süreç

    def komut(self, ad: str) -> str:
        """Ajan CLI'ının yolu: bu cihazda tam yol, uzakta yalın ad."""
        return ad if self.sunucu else (shutil.which(ad) or ad)

    async def _baslat(self, args: list[str]):
        env = dict(os.environ)
        env.setdefault("TERM", "dumb")
        env["DEBIAN_FRONTEND"] = "noninteractive"  # ajanın apt/pkg kurulumları soru sormasın
        if self.sunucu:
            s = self.k.sunucular().get(self.sunucu)
            if not s:
                raise ValueError(f"sunucu bulunamadı: {self.sunucu}")
            args = uzak_komut(s, self.uzak_klasor or "~", args)
        self.surec = await asyncio.create_subprocess_exec(
            *args, cwd=str(self.cwd), env=env,
            stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
            limit=64 * 1024 * 1024,
        )
        self._okuyucu = asyncio.create_task(self._oku())
        asyncio.create_task(self._hata_oku(self.surec))

    async def _oku(self):
        surec = self.surec
        assert surec and surec.stdout
        while True:
            satir = await surec.stdout.readline()
            if not satir:
                break
            try:
                olay = json.loads(satir)
            except ValueError:
                continue
            try:
                await self.isle(olay)
            except Exception as e:  # bir olayın bozukluğu oturumu düşürmesin
                self.yay({"ev": "uyari", "metin": f"olay işlenemedi: {e}"}, kaydet=False)
        await surec.wait()
        if self.surec is surec:
            self.surec = None
            if self.durum == "calisiyor":
                self.tur_sonu()
                self.yay({"ev": "bitti", "hata": f"süreç kapandı (çıkış {surec.returncode})"})
                self.durum_ver("bos")
            for rid in list(self.onaylar):
                self.onay_kapandi(rid)

    async def _hata_oku(self, surec):
        son = []
        while surec.stderr:
            s = await surec.stderr.readline()
            if not s:
                break
            son = (son + [s.decode(errors="replace").rstrip()])[-20:]
        if surec.returncode not in (0, None) and son:
            self.yay({"ev": "uyari", "metin": "\n".join(son)[-1500:]})

    async def yaz(self, nesne: dict):
        if not self.surec or not self.surec.stdin:
            return
        self.surec.stdin.write((json.dumps(nesne, ensure_ascii=False) + "\n").encode())
        await self.surec.stdin.drain()

    async def kapat(self):
        s = self.surec
        self.surec = None
        if s and s.returncode is None:
            try:
                s.terminate()
                await asyncio.wait_for(s.wait(), 5)
            except (ProcessLookupError, asyncio.TimeoutError):
                try:
                    s.kill()
                except ProcessLookupError:
                    pass

    def onay_kapandi(self, rid: str):
        if self.onaylar.pop(rid, None) is not None:
            self.yay({"ev": "onay_kapandi", "rid": rid})

    # alt sınıflar
    async def gonder(self, metin: str, ekler: list[str]): ...
    async def durdur(self): ...
    async def onayla(self, rid: str, karar: str): ...
    async def isle(self, olay: dict): ...


# ---------------------------------------------------------------- Claude


class ClaudeOturum(Oturum):
    def __init__(self, *a):
        super().__init__(*a)
        self._akis: dict[int, str] = {}  # akış blok sırası → metin anahtarı
        self._mesaj = ""
        self._acik: list[str] = []  # akışta başlayıp henüz tamamlanmamış metin anahtarları
        self._yazacak: dict[str, str] = {}  # araç kimliği → yazacağı dosya (sonuç gelince bildirilir)

    def _args(self):
        a = [self.komut("claude"), "-p",
             "--input-format", "stream-json", "--output-format", "stream-json", "--verbose",
             "--include-partial-messages", "--permission-prompt-tool", "stdio",
             "--permission-mode", CLAUDE_MOD.get(self.mod, "default")]
        if self.model:
            a += ["--model", self.model]
        if self.effort:
            a += ["--effort", self.effort]
        rehber = None if self.sunucu else ajan_rehberi()
        if rehber:
            a += ["--append-system-prompt", rehber]
        if self.sid:
            a += ["--resume", self.sid]
        return a

    async def gonder(self, metin, ekler):
        if ekler:
            metin += "\n\nEkler (Read aracıyla bakabilirsin):\n" + "\n".join(f"- {e}" for e in ekler)
        if not self.surec:
            await self._baslat(self._args())
        if self.durum != "calisiyor":
            self.tur_basi()
        self.durum_ver("calisiyor")
        await self.yaz({"type": "user", "message": {"role": "user", "content": metin}})

    async def durdur(self):
        if self.surec:
            await self.yaz({"type": "control_request", "request_id": uuid.uuid4().hex,
                            "request": {"subtype": "interrupt"}})

    async def onayla(self, rid, karar):
        istek = self.onaylar.get(rid)
        if not istek:
            return
        if karar in ("izin", "hep"):
            if karar == "hep":
                self.hep_izin.add(istek["arac"])
            yanit = {"behavior": "allow", "updatedInput": istek.get("_girdi", {})}
        else:
            yanit = {"behavior": "deny", "message": "Kullanıcı reddetti."}
        await self.yaz({"type": "control_response", "response": {
            "subtype": "success", "request_id": rid, "response": yanit}})
        self.onay_kapandi(rid)

    async def isle(self, ev):
        t = ev.get("type")
        if t == "system" and ev.get("subtype") == "init":
            if ev.get("session_id") and ev["session_id"] != self.sid:
                self.sid = ev["session_id"]
                self.k.oturumlari_kaydet()
            self.yay({"ev": "bilgi", "model": ev.get("model"), "araclar": len(ev.get("tools") or [])}, kaydet=False)
        elif t == "stream_event":
            e = ev.get("event") or {}
            et = e.get("type")
            if et == "message_start":
                self._mesaj = (e.get("message") or {}).get("id") or uuid.uuid4().hex
                self._akis = {}
            elif et == "content_block_start" and (e.get("content_block") or {}).get("type") == "text":
                anahtar = f"{self._mesaj}#{e.get('index')}"
                self._akis[e.get("index")] = anahtar
                self._acik.append(anahtar)
            elif et == "content_block_delta" and (e.get("delta") or {}).get("type") == "text_delta":
                anahtar = self._akis.get(e.get("index"))
                if anahtar:
                    self.yay({"ev": "parca", "anahtar": anahtar, "metin": e["delta"].get("text", "")}, kaydet=False)
        elif t == "assistant":
            for c in (ev.get("message") or {}).get("content") or []:
                ct = c.get("type")
                if ct == "text" and c.get("text", "").strip():
                    anahtar = self._acik.pop(0) if self._acik else uuid.uuid4().hex
                    self.yay({"ev": "metin", "anahtar": anahtar, "metin": c["text"]})
                elif ct == "tool_use":
                    girdi = c.get("input") or {}
                    self.yay({"ev": "arac", "aid": c.get("id"), "ad": c.get("name"),
                              "ozet": arac_ozeti(c.get("name", ""), girdi, self.cwd), "girdi": kisa(girdi, 60000)})
                    if c.get("name") in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
                        yol = girdi.get("file_path") or girdi.get("notebook_path")
                        if yol:
                            self._yazacak[c.get("id")] = yol
        elif t == "user":
            icerik = (ev.get("message") or {}).get("content")
            if isinstance(icerik, list):
                for c in icerik:
                    if c.get("type") == "tool_result":
                        cikti = c.get("content")
                        if isinstance(cikti, list):
                            cikti = "\n".join(x.get("text", "") for x in cikti if isinstance(x, dict))
                        self.yay({"ev": "arac_sonuc", "aid": c.get("tool_use_id"),
                                  "hata": bool(c.get("is_error")), "cikti": kisa(cikti or "")})
                        yol = self._yazacak.pop(c.get("tool_use_id"), None)
                        if yol and not c.get("is_error"):
                            self.dosya(yol)
        elif t == "control_request":
            istek = ev.get("request") or {}
            if istek.get("subtype") != "can_use_tool":
                await self.yaz({"type": "control_response", "response": {
                    "subtype": "error", "request_id": ev.get("request_id"), "error": "desteklenmiyor"}})
                return
            rid, arac, girdi = ev.get("request_id"), istek.get("tool_name", "?"), istek.get("input") or {}
            self.onaylar[rid] = {"arac": arac, "_girdi": girdi}
            if arac in self.hep_izin:
                await self.onayla(rid, "izin")
                return
            self.yay({"ev": "onay", "rid": rid, "arac": arac, "ozet": arac_ozeti(arac, girdi, self.cwd),
                      "girdi": kisa(girdi, 60000), "neden": istek.get("decision_reason") or ""})
        elif t == "control_cancel_request":
            self.onay_kapandi(ev.get("request_id"))
        elif t == "rate_limit_event":
            bilgi = ev.get("rate_limit_info") or {}
            pencereler = []
            for k, ad in (("five_hour", "5 saat"), ("seven_day", "hafta")):
                w = (bilgi.get("unifiedWindows") or {}).get(k)
                if w and w.get("utilization") is not None:
                    dolu = w.get("status") == "rejected"
                    pencereler.append({"ad": ad, "kullanim": 100 if dolu else round(float(w["utilization"]) * 100),
                                       "sifirlanma": w.get("resetsAt")})
            if pencereler:
                self.k.kota_ver("claude", pencereler)
        elif t == "result":
            if ev.get("session_id") and ev["session_id"] != self.sid:
                self.sid = ev["session_id"]
            self._acik.clear()
            self.tur_sonu()
            hata = (ev.get("result") or ev.get("subtype") or "hata") if ev.get("is_error") else None
            self.yay({"ev": "bitti", "hata": hata, "maliyet": ev.get("total_cost_usd"),
                      "sure": ev.get("duration_ms"),
                      "reddedilen": [d.get("tool_name") for d in ev.get("permission_denials") or []]})
            self.guncelleme = simdi()
            self.durum_ver("bos")


# ---------------------------------------------------------------- Codex


class CodexOturum(Oturum):
    def __init__(self, *a):
        super().__init__(*a)
        self._rid = 0
        self._bekleyen: dict[int, asyncio.Future] = {}
        self._hazir: asyncio.Future | None = None
        self.tur: str | None = None
        self._ogeler: dict[str, dict] = {}

    async def _rpc(self, yontem, params=None, bildirim=False):
        m = {"jsonrpc": "2.0", "method": yontem}
        if params is not None:
            m["params"] = params
        if bildirim:
            await self.yaz(m)
            return None
        self._rid += 1
        m["id"] = self._rid
        f = asyncio.get_running_loop().create_future()
        self._bekleyen[self._rid] = f
        await self.yaz(m)
        return await f

    def _politika(self):
        onay, sandbox = CODEX_MOD.get(self.mod, CODEX_MOD["otomatik"])
        if TERMUX and not self.sunucu:
            # Android'de bubblewrap çalışmaz (namespace izni yok); Termux zaten
            # Android'in uygulama kumunda. Onaylar politikaya göre yine sorulur.
            sandbox = "danger-full-access"
        return onay, sandbox

    async def _hazirla(self):
        if self.surec:
            return
        await self._baslat([self.komut("codex"), "app-server"])
        await self._rpc("initialize", {"clientInfo": {"name": "atolye", "version": SURUM}})
        await self._rpc("initialized", bildirim=True)
        onay, sandbox = self._politika()
        prm = {"cwd": self.uzak_klasor if self.sunucu else str(self.cwd), "approvalPolicy": onay, "sandbox": sandbox}
        if self.model:
            prm["model"] = self.model
        sonuc = None
        if self.sid:
            try:
                sonuc = await self._rpc("thread/resume", dict(prm, threadId=self.sid))
            except RuntimeError as e:
                self.yay({"ev": "uyari", "metin": f"oturum sürdürülemedi, yeni başlıyor: {e}"})
        if sonuc is None:
            rehber = None if self.sunucu else ajan_rehberi()
            if rehber:
                prm["developerInstructions"] = rehber
            sonuc = await self._rpc("thread/start", prm)
        self.sid = sonuc["thread"]["id"]
        self.k.oturumlari_kaydet()

    async def gonder(self, metin, ekler):
        await self._hazirla()
        girdi = [{"type": "text", "text": metin}]
        for e in ekler:
            if Path(e).suffix.lower() in (".png", ".jpg", ".jpeg", ".gif", ".webp"):
                girdi.append({"type": "localImage", "path": e})
            else:
                girdi[0]["text"] += f"\n\nEk: {e}"
        if self.durum == "calisiyor" and self.tur:
            try:
                await self._rpc("turn/steer", {"threadId": self.sid, "expectedTurnId": self.tur, "input": girdi})
                return
            except RuntimeError:
                pass  # tur bu arada bitti: yeni tur aç
        self.tur_basi()
        self.durum_ver("calisiyor")
        onay, sandbox = self._politika()
        pol = {"type": {"read-only": "readOnly", "danger-full-access": "dangerFullAccess"}.get(sandbox, "workspaceWrite")}
        if pol["type"] == "workspaceWrite":
            pol["networkAccess"] = True
        prm = {"threadId": self.sid, "input": girdi, "cwd": self.uzak_klasor if self.sunucu else str(self.cwd),
               "approvalPolicy": onay, "sandboxPolicy": pol}
        if self.model:
            prm["model"] = self.model
        if self.effort:
            prm["effort"] = self.effort
        try:
            sonuc = await self._rpc("turn/start", prm)
            self.tur = sonuc["turn"]["id"]
        except RuntimeError as e:
            self.yay({"ev": "bitti", "hata": str(e)})
            self.durum_ver("bos")

    async def durdur(self):
        if self.surec and self.tur:
            try:
                await self._rpc("turn/interrupt", {"threadId": self.sid, "turnId": self.tur})
            except RuntimeError:
                pass

    async def onayla(self, rid, karar):
        istek = self.onaylar.get(rid)
        if not istek:
            return
        decision = {"izin": "accept", "hep": "acceptForSession"}.get(karar, "decline")
        await self.yaz({"jsonrpc": "2.0", "id": istek["_id"], "result": {"decision": decision}})
        self.onay_kapandi(rid)

    async def isle(self, j):
        rid, yontem = j.get("id"), j.get("method")
        if rid is not None and not yontem:  # bizim isteğimize yanıt
            f = self._bekleyen.pop(rid, None)
            if f and not f.done():
                if j.get("error"):
                    f.set_exception(RuntimeError(j["error"].get("message", str(j["error"]))))
                else:
                    f.set_result(j.get("result") or {})
            return
        prm = j.get("params") or {}
        if rid is not None:  # sunucudan istek
            if yontem in ("item/commandExecution/requestApproval", "item/fileChange/requestApproval"):
                anahtar = f"cx{rid}"
                if yontem.startswith("item/commandExecution"):
                    arac, ozet = "Komut", prm.get("command") or ""
                    girdi = {"command": prm.get("command"), "cwd": prm.get("cwd")}
                else:
                    oge = self._ogeler.get(prm.get("itemId"), {})
                    arac = "Dosya değişikliği"
                    yollar = [c.get("path") for c in oge.get("changes") or []]
                    ozet = ", ".join(goreli(y, self.cwd) for y in yollar if y)
                    girdi = {"changes": oge.get("changes")}
                self.onaylar[anahtar] = {"arac": arac, "_id": rid}
                self.yay({"ev": "onay", "rid": anahtar, "arac": arac, "ozet": kisa(ozet, 300),
                          "girdi": kisa(girdi, 60000), "neden": prm.get("reason") or ""})
            else:
                await self.yaz({"jsonrpc": "2.0", "id": rid, "error": {"code": -32601, "message": "desteklenmiyor"}})
            return

        oge = prm.get("item") or {}
        tur = oge.get("type")
        if yontem == "item/agentMessage/delta":
            self.yay({"ev": "parca", "anahtar": prm.get("itemId"), "metin": prm.get("delta", "")}, kaydet=False)
        elif yontem == "item/started":
            self._ogeler[oge.get("id")] = oge
            if tur == "commandExecution":
                komut = oge.get("command", "")
                m = re.match(r"^\S*?(?:ba|z)?sh -lc '(.*)'$", komut, re.S)
                self.yay({"ev": "arac", "aid": oge.get("id"), "ad": "Komut", "ozet": kisa(m.group(1) if m else komut, 200),
                          "girdi": kisa({"command": komut})})
            elif tur == "fileChange":
                yollar = [goreli(c.get("path", ""), self.cwd) for c in oge.get("changes") or []]
                self.yay({"ev": "arac", "aid": oge.get("id"), "ad": "Düzenle", "ozet": ", ".join(yollar),
                          "girdi": kisa({"changes": oge.get("changes")}, 60000)})
            elif tur in ("mcpToolCall", "webSearch", "dynamicToolCall"):
                self.yay({"ev": "arac", "aid": oge.get("id"), "ad": tur,
                          "ozet": kisa(oge.get("query") or oge.get("tool") or "", 200), "girdi": kisa(oge)})
        elif yontem == "item/completed":
            self._ogeler.pop(oge.get("id"), None)
            if tur == "agentMessage" and (oge.get("text") or "").strip():
                self.yay({"ev": "metin", "anahtar": oge.get("id"), "metin": oge["text"]})
            elif tur == "commandExecution":
                self.yay({"ev": "arac_sonuc", "aid": oge.get("id"),
                          "hata": oge.get("exitCode") not in (0, None) or oge.get("status") == "failed",
                          "cikti": kisa(oge.get("aggregatedOutput") or "")})
            elif tur == "fileChange":
                for c in oge.get("changes") or []:
                    self.dosya(c.get("path"))
                self.yay({"ev": "arac_sonuc", "aid": oge.get("id"), "hata": oge.get("status") == "failed", "cikti": ""})
            elif tur in ("mcpToolCall", "webSearch", "dynamicToolCall"):
                self.yay({"ev": "arac_sonuc", "aid": oge.get("id"), "hata": oge.get("status") == "failed",
                          "cikti": kisa(oge.get("result") or oge.get("error") or "")})
            elif tur == "imageGeneration" and oge.get("savedPath"):
                self.dosya(oge["savedPath"], "yeni")
        elif yontem == "serverRequest/resolved":
            r = prm.get("requestId")
            self.onay_kapandi(f"cx{r}")
        elif yontem == "account/rateLimits/updated":
            lim, pencereler = prm.get("rateLimits") or {}, []
            for k in ("primary", "secondary"):
                w = lim.get(k)
                if w and w.get("usedPercent") is not None:
                    dk = w.get("windowDurationMins") or 0
                    pencereler.append({"ad": {300: "5 saat", 10080: "hafta"}.get(dk, f"{dk // 60} saat"),
                                       "kullanim": round(w["usedPercent"]), "sifirlanma": w.get("resetsAt")})
            if pencereler:
                self.k.kota_ver("codex", pencereler)
        elif yontem == "error" and not prm.get("willRetry"):
            self.yay({"ev": "uyari", "metin": kisa((prm.get("error") or {}).get("message", ""), 1000)})
        elif yontem == "turn/completed":
            t = prm.get("turn") or {}
            hata = None
            if t.get("status") == "failed":
                hata = ((t.get("error") or {}).get("message")) or "tur başarısız"
            elif t.get("status") == "interrupted":
                hata = "durduruldu"
            self.tur = None
            self.tur_sonu()
            self.yay({"ev": "bitti", "hata": hata})
            self.guncelleme = simdi()
            self.durum_ver("bos")


SURUCULER = {"claude": ClaudeOturum, "codex": CodexOturum}

EFFORT_ADLARI = {"low": "Düşük", "medium": "Orta", "high": "Yüksek", "xhigh": "Çok yüksek",
                 "max": "En yüksek", "ultra": "Ultra", "minimal": "En az", "none": "Yok"}

CLAUDE_MODELLERI = [
    {"id": "opus", "ad": "Opus", "aciklama": "En güçlü, karmaşık işler"},
    {"id": "sonnet", "ad": "Sonnet", "aciklama": "Hızlı ve dengeli"},
    {"id": "fable", "ad": "Fable", "aciklama": "Uzun ve derin işler"},
    {"id": "haiku", "ad": "Haiku", "aciklama": "En hızlı, basit işler"},
]
CLAUDE_EFFORTLARI = ["low", "medium", "high", "xhigh", "max"]


# ---------------------------------------------------------------- köprü


class Kopru:
    def __init__(self, token: str):
        self.token = token
        self.istemciler: set = set()
        self.oturumlar: dict[str, Oturum] = {}
        self.kotalar: dict[str, list] = {}
        self._codex_modelleri: tuple[float, list] | None = None
        (EV / "kayit").mkdir(parents=True, exist_ok=True)
        KOK.mkdir(parents=True, exist_ok=True)
        self._yukle()

    # --- kalıcılık

    def _yukle(self):
        f = EV / "oturumlar.json"
        try:
            for v in json.loads(f.read_text()):
                if v.get("ajan") in SURUCULER:
                    self.oturumlar[v["id"]] = SURUCULER[v["ajan"]](self, v)
        except (OSError, ValueError):
            pass

    def oturumlari_kaydet(self):
        f = EV / "oturumlar.json"
        gecici = f.with_suffix(".tmp")
        gecici.write_text(json.dumps([o.veri() for o in self.oturumlar.values()], ensure_ascii=False, indent=1))
        gecici.replace(f)

    def kayda_yaz(self, oid: str, olay: dict):
        with open(EV / "kayit" / f"{oid}.jsonl", "a", encoding="utf-8") as f:
            f.write(json.dumps(olay, ensure_ascii=False) + "\n")

    def gecmis(self, oid: str, son: int = 2000) -> list[dict]:
        try:
            satirlar = (EV / "kayit" / f"{oid}.jsonl").read_text(encoding="utf-8").splitlines()[-son:]
        except OSError:
            return []
        out = []
        for s in satirlar:
            try:
                out.append(json.loads(s))
            except ValueError:
                pass
        return out

    # --- yayın

    def yayinla(self, olay: dict):
        veri = json.dumps(olay, ensure_ascii=False)
        for ws in list(self.istemciler):
            asyncio.create_task(self._gonder(ws, veri))

    async def _gonder(self, ws, veri):
        try:
            await ws.send(veri)
        except ConnectionClosed:
            self.istemciler.discard(ws)

    def kota_ver(self, ajan, pencereler):
        self.kotalar[ajan] = pencereler
        self.yayinla({"ev": "kota", "ajan": ajan, "pencereler": pencereler})

    # --- istekler

    async def modeller(self, ajan: str) -> list[dict]:
        """Seçilebilecek modeller ve her birinin effort düzeyleri."""
        if ajan == "claude":
            return [dict(m, effortlar=CLAUDE_EFFORTLARI, varsayilan_effort=None) for m in CLAUDE_MODELLERI]
        if ajan != "codex":
            return []
        if self._codex_modelleri and simdi() - self._codex_modelleri[0] < 600:
            return self._codex_modelleri[1]
        yol = shutil.which("codex")
        if not yol:
            return []
        p = await asyncio.create_subprocess_exec(yol, "app-server", stdin=asyncio.subprocess.PIPE,
                                                 stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)

        async def yaz(o):
            p.stdin.write((json.dumps(o) + "\n").encode())
            await p.stdin.drain()

        async def bekle(no):
            while True:
                satir = await p.stdout.readline()
                if not satir:
                    raise RuntimeError("codex yanıt vermedi")
                try:
                    j = json.loads(satir)
                except ValueError:
                    continue
                if j.get("id") == no:
                    return j

        try:
            await yaz({"jsonrpc": "2.0", "id": 1, "method": "initialize",
                       "params": {"clientInfo": {"name": "atolye", "version": SURUM}}})
            await asyncio.wait_for(bekle(1), 20)
            await yaz({"jsonrpc": "2.0", "method": "initialized"})
            await yaz({"jsonrpc": "2.0", "id": 2, "method": "model/list", "params": {}})
            yanit = await asyncio.wait_for(bekle(2), 30)
        finally:
            try:
                p.kill()
            except ProcessLookupError:
                pass
        out = []
        for m in (yanit.get("result") or {}).get("data") or []:
            if m.get("hidden"):
                continue
            effortlar = [e.get("reasoningEffort") if isinstance(e, dict) else e
                         for e in m.get("supportedReasoningEfforts") or []]
            out.append({"id": m.get("model") or m.get("id"), "ad": m.get("displayName") or m.get("id"),
                        "aciklama": m.get("description") or "", "varsayilan": bool(m.get("isDefault")),
                        "effortlar": [e for e in effortlar if e], "varsayilan_effort": m.get("defaultReasoningEffort")})
        self._codex_modelleri = (simdi(), out)
        return out

    ARACLAR = [
        ("node", "Node.js"), ("python", "Python"), ("git", "Git"), ("gh", "GitHub CLI"),
        ("clang", "Clang"), ("cmake", "CMake"), ("rustc", "Rust"), ("go", "Go"),
        ("java", "Java"), ("kotlinc", "Kotlin"), ("gradle", "Gradle"), ("dart", "Dart"),
        ("flutter", "Flutter"), ("php", "PHP"), ("ruby", "Ruby"), ("sqlite3", "SQLite"),
        ("ffmpeg", "FFmpeg"), ("proot-distro", "proot-distro"), ("ssh", "OpenSSH"),
    ]

    async def araclar(self) -> dict:
        """Kurulu geliştirme araçları ve sürümleri; Termux disk durumu."""
        async def surum(komut):
            yol = shutil.which(komut)
            if not yol:
                return None
            for bayrak in (["--version"], ["version"], ["-version"]):
                kod, out, err = await calistir([yol, *bayrak], sure=8)
                satir = (out or err).strip().splitlines()
                if kod == 0 and satir:
                    return satir[0][:80]
            return "kurulu"
        sonuclar = await asyncio.gather(*(surum(k) for k, _ in self.ARACLAR))
        disk = shutil.disk_usage(Path.home())
        return {
            "termux": TERMUX,
            "araclar": [{"komut": k, "ad": ad, "surum": s} for (k, ad), s in zip(self.ARACLAR, sonuclar)],
            "depolama": (Path.home() / "storage").exists(),
            "disk_bos": disk.free, "disk_toplam": disk.total,
        }

    async def ajanlar(self):
        out = []
        for ad in ("claude", "codex"):
            yol = shutil.which(ad)
            surum = None
            if yol:
                try:
                    p = await asyncio.create_subprocess_exec(yol, "--version", stdout=asyncio.subprocess.PIPE,
                                                             stderr=asyncio.subprocess.DEVNULL)
                    o, _ = await asyncio.wait_for(p.communicate(), 15)
                    surum = o.decode().strip().splitlines()[0] if o else None
                except (OSError, asyncio.TimeoutError, IndexError):
                    pass
            out.append({"ad": ad, "kurulu": bool(yol), "surum": surum})
        return out

    def sunucular(self) -> dict[str, dict]:
        try:
            return {s["ad"]: s for s in json.loads((EV / "sunucular.json").read_text())}
        except (OSError, ValueError):
            return {}

    def sunuculari_yaz(self, sunucular: dict[str, dict]):
        (EV / "sunucular.json").write_text(json.dumps(list(sunucular.values()), ensure_ascii=False, indent=1))

    def projeler(self):
        out = []
        try:
            for e in os.scandir(KOK):
                if e.is_dir() and not e.name.startswith("."):
                    out.append({"ad": e.name, "yol": e.path, "degisme": e.stat().st_mtime})
        except OSError:
            pass
        return sorted(out, key=lambda x: -x["degisme"])

    def listele(self, yol):
        p = guvenli_yol(yol)
        ogeler = []
        with os.scandir(p) as it:
            for e in it:
                try:
                    st = e.stat()
                    ogeler.append({"ad": e.name, "yol": e.path, "klasor": e.is_dir(),
                                   "boyut": st.st_size, "degisme": st.st_mtime})
                except OSError:
                    pass
        ogeler.sort(key=lambda x: (not x["klasor"], x["ad"].lower()))
        return {"yol": str(p), "ust": str(p.parent) if p != KOK.resolve() else None, "ogeler": ogeler}

    def oku(self, yol):
        p = guvenli_yol(yol)
        boyut = p.stat().st_size
        tur = mimetypes.guess_type(p.name)[0] or ""
        if boyut > METIN_SINIRI:
            return {"yol": str(p), "boyut": boyut, "tur": tur, "buyuk": True}
        ham = p.read_bytes()
        try:
            return {"yol": str(p), "boyut": boyut, "tur": tur, "metin": ham.decode("utf-8")}
        except UnicodeDecodeError:
            return {"yol": str(p), "boyut": boyut, "tur": tur, "ikili": True}

    async def istek(self, ws, m: dict):
        op = m.get("op")
        if op == "durum":
            return {"surum": SURUM, "kok": str(KOK.resolve()), "ajanlar": await self.ajanlar(),
                    "kotalar": self.kotalar, "termux": "com.termux" in os.environ.get("PREFIX", "")}
        if op == "projeler":
            return {"projeler": self.projeler()}
        if op == "proje_ac":
            ad = re.sub(r"[^\w.\- ]", "", m.get("ad", "")).strip()
            if not ad:
                raise ValueError("geçersiz ad")
            p = guvenli_yol(KOK / ad)
            p.mkdir(parents=True, exist_ok=True)
            return {"yol": str(p)}
        if op == "oturumlar":
            return {"oturumlar": sorted((o.ozet() for o in self.oturumlar.values()), key=lambda x: -x["guncelleme"])}
        if op == "oturum_ac":
            ajan = m.get("ajan")
            if ajan not in SURUCULER:
                raise ValueError("bilinmeyen ajan")
            sunucu = m.get("sunucu") or None
            if sunucu:
                if sunucu not in self.sunucular():
                    raise ValueError("sunucu bulunamadı")
                uzak = (m.get("uzak_klasor") or "~").strip()
                cwd = KOK.resolve()
                baslik = m.get("baslik") or f"{sunucu}:{uzak}"
            else:
                uzak = None
                cwd = guvenli_yol(m.get("cwd") or KOK)
                if not cwd.is_dir():
                    raise ValueError("klasör yok")
                baslik = m.get("baslik")
            o = SURUCULER[ajan](self, {"id": uuid.uuid4().hex[:12], "ajan": ajan, "cwd": str(cwd),
                                        "mod": m.get("mod", "otomatik"), "model": m.get("model") or None,
                                        "effort": m.get("effort") or None,
                                        "baslik": baslik, "sunucu": sunucu, "uzak_klasor": uzak})
            self.oturumlar[o.id] = o
            self.oturumlari_kaydet()
            return {"oturum": o.ozet()}
        if op == "oturum_sil":
            o = self.oturumlar.pop(m.get("oturum"), None)
            if o:
                await o.kapat()
                self.oturumlari_kaydet()
                try:
                    (EV / "kayit" / f"{o.id}.jsonl").unlink()
                except OSError:
                    pass
            return {}
        if op == "gecmis":
            o = self._oturum(m)
            olaylar = self.gecmis(o.id)
            return {"oturum": o.ozet(), "olaylar": olaylar,
                    "bekleyen": [r for r in o.onaylar if any(e.get("rid") == r for e in olaylar)]}
        if op == "gonder":
            o = self._oturum(m)
            metin = (m.get("metin") or "").strip()
            ekler = [str(guvenli_yol(e)) for e in m.get("ekler") or []]
            if not metin and not ekler:
                raise ValueError("boş mesaj")
            if o.baslik == o.cwd.name and metin and not self.gecmis(o.id, 1):
                o.baslik = kisa(metin.splitlines()[0], 60)
                self.oturumlari_kaydet()
                self.yayinla({"ev": "oturum", "oturum": o.id, "ozet": o.ozet()})
            o.yay({"ev": "kullanici", "metin": metin, "ekler": ekler})
            await o.gonder(metin, ekler)
            return {}
        if op == "durdur":
            await self._oturum(m).durdur()
            return {}
        if op == "onay":
            await self._oturum(m).onayla(m.get("rid"), m.get("karar", "red"))
            return {}
        if op in ("mod", "ayar"):
            o = self._oturum(m)
            if "mod" in m:
                o.mod = m["mod"] or "otomatik"
            if "model" in m:
                o.model = m["model"] or None
            if "effort" in m:
                o.effort = m["effort"] or None
            await o.kapat()  # yeni ayarla, aynı oturumu sürdürerek yeniden açılır
            self.oturumlari_kaydet()
            ozet = o.ozet()
            self.yayinla({"ev": "oturum", "oturum": o.id, "ozet": ozet})
            return {"oturum": ozet}
        if op == "araclar":
            return await self.araclar()
        if op == "modeller":
            return {"modeller": await self.modeller(m.get("ajan", "claude")), "effort_adlari": EFFORT_ADLARI}
        if op == "listele":
            return self.listele(m.get("yol") or KOK)
        if op == "oku":
            return self.oku(m["yol"])
        if op == "belge":
            return belge_oku(guvenli_yol(m["yol"]))

        # --- git
        if op.startswith("git_"):
            cwd = guvenli_yol(m.get("cwd") or KOK)
            if op == "git_durum":
                return await git_durum(cwd)
            if op == "git_fark":
                return await git_fark(cwd, m["yol"])
            if op == "git_init":
                return _sonuc(*await calistir(["git", "init", "-b", "main"], cwd))
            if op == "git_commit":
                mesaj = (m.get("mesaj") or "").strip()
                if not mesaj:
                    raise ValueError("commit mesajı boş")
                yollar = m.get("yollar")
                kod, out, err = await calistir(["git", "add", "-A", "--", *(yollar or ["."])], cwd)
                if kod != 0:
                    raise RuntimeError(err.strip())
                return _sonuc(*await calistir(["git", "commit", "-m", mesaj], cwd))
            if op == "git_push":
                kod, out, err = await calistir(["git", "push"], cwd, 300)
                if kod != 0 and "no upstream" in (err + out):
                    kod, out, err = await calistir(["git", "push", "-u", "origin", "HEAD"], cwd, 300)
                return _sonuc(kod, out, err, "gönderildi")
            if op == "git_pull":
                return _sonuc(*await calistir(["git", "pull", "--ff-only"], cwd, 300), "güncel")
            if op == "git_klonla":
                url = (m.get("url") or "").strip()
                if not re.match(r"^(https://|git@|ssh://)\S+$", url):
                    raise ValueError("geçersiz depo adresi")
                ad = re.sub(r"[^\w.\-]", "", m.get("ad") or url.rstrip("/").rsplit("/", 1)[-1].removesuffix(".git"))
                hedef = guvenli_yol(KOK / ad)
                if hedef.exists():
                    raise ValueError(f"{ad} klasörü zaten var")
                _sonuc(*await calistir(["git", "clone", url, str(hedef)], KOK, 900))
                return {"yol": str(hedef)}
            raise ValueError(f"bilinmeyen işlem: {op}")

        # --- GitHub
        if op == "gh_durum":
            return await gh_durum()
        if op == "gh_repolar":
            kod, out, err = await calistir(["gh", "repo", "list", "--limit", "100", "--json",
                                            "nameWithOwner,description,url,sshUrl,updatedAt,isPrivate"], sure=60)
            if kod != 0:
                raise RuntimeError(err.strip() or "GitHub depoları alınamadı")
            return {"repolar": json.loads(out or "[]")}
        if op == "gh_pr":
            cwd = guvenli_yol(m["cwd"])
            args = ["gh", "pr", "create", "--title", m.get("baslik") or "Atölye", "--body", m.get("govde") or ""]
            kod, out, err = await calistir(args, cwd, 120)
            if kod != 0:
                raise RuntimeError(err.strip() or out.strip())
            return {"url": out.strip().splitlines()[-1] if out.strip() else ""}
        if op == "gh_anahtar_ekle":
            if not SSH_ANAHTAR.with_suffix(".pub").exists():
                raise ValueError("önce SSH anahtarı oluştur")
            return _sonuc(*await calistir(["gh", "ssh-key", "add", str(SSH_ANAHTAR.with_suffix(".pub")),
                                            "--title", f"atolye-{socket.gethostname()}"], sure=60), "eklendi")

        # --- SSH
        if op == "ssh_durum":
            pub = SSH_ANAHTAR.with_suffix(".pub")
            return {"anahtar": pub.read_text().strip() if pub.exists() else None,
                    "ssh": bool(shutil.which("ssh")), "sunucular": list(self.sunucular().values())}
        if op == "ssh_anahtar_olustur":
            if SSH_ANAHTAR.exists():
                raise ValueError("anahtar zaten var")
            SSH_ANAHTAR.parent.mkdir(mode=0o700, exist_ok=True)
            _sonuc(*await calistir(["ssh-keygen", "-t", "ed25519", "-N", "", "-C",
                                    f"atolye@{socket.gethostname()}", "-f", str(SSH_ANAHTAR)], sure=30))
            return {"anahtar": SSH_ANAHTAR.with_suffix(".pub").read_text().strip()}
        if op == "sunucu_kaydet":
            ad = re.sub(r"[^\w.\-]", "", m.get("ad") or "")
            host = (m.get("host") or "").strip()
            if not ad or not re.match(r"^[\w.\-:\[\]]+$", host):
                raise ValueError("ad ve sunucu adresi gerekli")
            kullanici = (m.get("kullanici") or "").strip()
            if kullanici and not re.match(r"^[\w.\-]+$", kullanici):
                raise ValueError("geçersiz kullanıcı adı")
            hepsi = self.sunucular()
            hepsi[ad] = {"ad": ad, "host": host, "kullanici": kullanici or None,
                         "port": int(m.get("port") or 22), "klasor": (m.get("klasor") or "~").strip()}
            self.sunuculari_yaz(hepsi)
            return {"sunucu": hepsi[ad]}
        if op == "sunucu_sil":
            hepsi = self.sunucular()
            hepsi.pop(m.get("ad"), None)
            self.sunuculari_yaz(hepsi)
            return {}
        if op == "sunucu_dene":
            s = self.sunucular().get(m.get("ad"))
            if not s:
                raise ValueError("sunucu bulunamadı")
            kod, out, err = await calistir(ssh_hedef(s) + ["--", "bash -lc 'echo ATOLYE_OK; command -v claude codex git'"], sure=25)
            if kod != 0 or "ATOLYE_OK" not in out:
                raise RuntimeError(err.strip() or "bağlanılamadı")
            araclar = [Path(x).name for x in out.split() if x.startswith("/")]
            return {"tamam": True, "araclar": araclar}
        if op == "yukle":
            o = self._oturum(m)
            hedef_klasor = o.cwd / ".atolye" / "ekler"
            hedef_klasor.mkdir(parents=True, exist_ok=True)
            ad = re.sub(r"[^\w.\-]", "_", m.get("ad") or "ek")
            hedef = hedef_klasor / f"{int(simdi())}_{ad}"
            hedef.write_bytes(base64.b64decode(m["veri"]))
            return {"yol": str(hedef)}
        raise ValueError(f"bilinmeyen işlem: {op}")

    def _oturum(self, m) -> Oturum:
        o = self.oturumlar.get(m.get("oturum"))
        if not o:
            raise ValueError("oturum bulunamadı")
        return o

    # --- bağlantı

    async def baglanti(self, ws):
        try:
            ilk = json.loads(await asyncio.wait_for(ws.recv(), 10))
        except (asyncio.TimeoutError, ValueError, ConnectionClosed):
            return
        if ilk.get("op") != "hello" or not secrets.compare_digest(str(ilk.get("token", "")), self.token):
            await ws.send(json.dumps({"no": ilk.get("no"), "hata": "yetkisiz"}))
            await ws.close(4401, "yetkisiz")
            return
        await ws.send(json.dumps({"no": ilk.get("no"), "sonuc": {"surum": SURUM}}))
        self.istemciler.add(ws)
        try:
            async for ham in ws:
                try:
                    m = json.loads(ham)
                except ValueError:
                    continue
                asyncio.create_task(self._yanitla(ws, m))
        except ConnectionClosed:
            pass
        finally:
            self.istemciler.discard(ws)

    async def _yanitla(self, ws, m):
        try:
            sonuc = await self.istek(ws, m)
            yanit = {"no": m.get("no"), "sonuc": sonuc}
        except Exception as e:
            yanit = {"no": m.get("no"), "hata": str(e) or type(e).__name__}
        try:
            await ws.send(json.dumps(yanit, ensure_ascii=False))
        except ConnectionClosed:
            pass

    def http(self, baglanti, istek):
        """WebSocket olmayan istekler: dosya sunumu."""
        if istek.headers.get("Upgrade", "").lower() == "websocket":
            return None
        u = urllib.parse.urlsplit(istek.path)
        q = urllib.parse.parse_qs(u.query)
        basliklar = Headers([("Access-Control-Allow-Origin", "*"), ("Cache-Control", "no-store")])
        if u.path == "/saglik":
            basliklar["Content-Type"] = "text/plain"
            return Response(200, "OK", basliklar, b"atolye " + SURUM.encode())
        if u.path != "/dosya" or not secrets.compare_digest(q.get("t", [""])[0], self.token):
            return Response(403, "Forbidden", basliklar, b"yetkisiz")
        try:
            p = guvenli_yol(q.get("yol", [""])[0])
            govde = p.read_bytes()
        except (OSError, PermissionError) as e:
            return Response(404, "Not Found", basliklar, str(e).encode())
        basliklar["Content-Type"] = mimetypes.guess_type(p.name)[0] or "application/octet-stream"
        return Response(200, "OK", basliklar, govde)


def token_al(yeni: str | None) -> str:
    f = EV / "token"
    EV.mkdir(parents=True, exist_ok=True)
    if yeni:
        f.write_text(yeni)
    elif not f.exists():
        f.write_text(secrets.token_urlsafe(24))
    os.chmod(f, 0o600)
    return f.read_text().strip()


async def ana(port: int, token: str):
    k = Kopru(token)
    dur = asyncio.get_running_loop().create_future()
    for s in (signal.SIGINT, signal.SIGTERM):
        try:
            asyncio.get_running_loop().add_signal_handler(s, lambda: dur.done() or dur.set_result(None))
        except NotImplementedError:
            pass
    async with serve(k.baglanti, "127.0.0.1", port, process_request=k.http, max_size=64 * 1024 * 1024,
                     ping_interval=20, ping_timeout=60):
        print(f"atolye köprüsü {SURUM} — ws://127.0.0.1:{port}  kök: {KOK}", flush=True)
        await dur
    for o in k.oturumlar.values():
        await o.kapat()


def main():
    ap = argparse.ArgumentParser(description="Atölye köprüsü")
    ap.add_argument("--port", type=int, default=int(os.environ.get("ATOLYE_PORT", 8765)))
    ap.add_argument("--token", help="uygulamanın verdiği erişim anahtarını kaydet")
    ap.add_argument("--token-goster", action="store_true")
    a = ap.parse_args()
    token = token_al(a.token)
    if a.token_goster:
        print(token)
        return
    try:
        asyncio.run(ana(a.port, token))
    except OSError as e:
        print(f"başlatılamadı: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
