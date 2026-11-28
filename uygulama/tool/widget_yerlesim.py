"""Atölye ana ekran widget yerleşimlerini üretir: python3 tool/widget_yerlesim.py android/app/src/main/res"""
import sys
from pathlib import Path

RES = Path(sys.argv[1])
NS = 'xmlns:android="http://schemas.android.com/apk/res/android"'


def arka():
    # Widget'larda yalnız izinli sınıflar: düz View yok, boşluk için FrameLayout.
    # Arka plan: rengi, saydamlığı ve köşesi koddan ayarlanır.
    return ('<ImageView android:id="@+id/arka" android:layout_width="match_parent" '
            'android:layout_height="match_parent" android:scaleType="fitXY" '
            'android:src="@drawable/widget_arka_20" android:tint="#14141C" android:importantForAccessibility="no"/>')


def baslik(alt=True):
    alt_metin = ('<TextView android:id="@+id/alt_baslik" android:layout_width="0dp" '
                 'android:layout_height="wrap_content" android:layout_weight="1" '
                 'android:layout_marginStart="6dp" android:text="· köprü bağlı" android:textSize="11sp" '
                 'android:textColor="#A9A8C4" android:maxLines="1" android:ellipsize="end"/>') if alt else \
        '<FrameLayout android:layout_width="0dp" android:layout_height="1dp" android:layout_weight="1"/>'
    return f'''
        <LinearLayout android:layout_width="match_parent" android:layout_height="22dp"
            android:orientation="horizontal" android:gravity="center_vertical">
            <ImageView android:id="@+id/simge" android:layout_width="16dp" android:layout_height="16dp"
                android:src="@drawable/ic_bildirim" android:tint="#8B8CF8" android:importantForAccessibility="no"/>
            <TextView android:id="@+id/ad" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:layout_marginStart="6dp" android:text="Atölye" android:textSize="14sp"
                android:textStyle="bold" android:textColor="#ECEBFF" android:maxLines="1"/>
            {alt_metin}
            <ImageView android:id="@+id/nokta" android:layout_width="8dp" android:layout_height="8dp"
                android:src="@drawable/widget_nokta" android:tint="#5DCAA5" android:importantForAccessibility="no"/>
            <ImageView android:id="@+id/yenile" android:layout_width="28dp" android:layout_height="22dp"
                android:paddingStart="8dp" android:paddingEnd="2dp" android:src="@drawable/wi_yenile" android:tint="#A9A8C4"
                android:contentDescription="Yenile"/>
        </LinearLayout>'''


def dugme(id_, ikon, metin, agirlik=True, bas=False):
    yazi = (f'<TextView android:id="@+id/{id_}_yazi" android:layout_width="wrap_content" '
            f'android:layout_height="wrap_content" android:layout_marginStart="4dp" android:text="{metin}" '
            f'android:textSize="12sp" android:textColor="#ECEBFF" android:maxLines="1"/>') if metin else ''
    gen = 'android:layout_width="0dp" android:layout_weight="1"' if agirlik else 'android:layout_width="44dp"'
    bosluk = '' if bas else 'android:layout_marginStart="6dp"'
    return f'''
            <LinearLayout android:id="@+id/{id_}" {gen} android:layout_height="34dp" {bosluk}
                android:orientation="horizontal" android:gravity="center"
                android:background="@drawable/widget_dugme_koyu" android:contentDescription="{metin or id_}">
                <ImageView android:id="@+id/{id_}_simge" android:layout_width="16dp" android:layout_height="16dp"
                    android:src="@drawable/{ikon}" android:importantForAccessibility="no"/>
                {yazi}
            </LinearLayout>'''


def kok(icerik, dolgu="14dp"):
    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- Üretildi: tool/widget_yerlesim.py, elle düzenlemeyin. Renkler ve görünürlük AtolyeWidget.kt'de ayarlanır. -->
<FrameLayout {NS}
    android:id="@+id/kok" android:layout_width="match_parent" android:layout_height="match_parent">
    {arka()}
    <LinearLayout android:layout_width="match_parent" android:layout_height="match_parent"
        android:orientation="vertical" android:padding="{dolgu}">
{icerik}
    </LinearLayout>
</FrameLayout>
'''


# --- küçük (2×2)
kucuk = baslik(alt=False) + '''
        <TextView android:id="@+id/sayi" android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:layout_marginTop="4dp" android:text="2" android:textSize="24sp" android:textColor="#ECEBFF"
            android:includeFontPadding="false"/>
        <TextView android:id="@+id/sayi_yazi" android:layout_width="match_parent" android:layout_height="wrap_content"
            android:text="ajan çalışıyor" android:textSize="11sp" android:textColor="#A9A8C4" android:maxLines="1"/>
        <TextView android:id="@+id/hap" android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:layout_marginTop="4dp" android:background="@drawable/widget_hap" android:paddingStart="7dp"
            android:paddingEnd="7dp" android:paddingTop="2dp" android:paddingBottom="2dp"
            android:text="1 onay bekliyor" android:textSize="11sp" android:textColor="#FAC775" android:maxLines="1"/>
        <FrameLayout android:layout_width="1dp" android:layout_height="0dp" android:layout_weight="1"/>
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
            android:orientation="horizontal">''' + dugme("konus", "wi_mikrofon", "", bas=True) + \
    dugme("yeni", "wi_ekle", "") + '''
        </LinearLayout>'''

# --- şerit (geniş, tek satır)
serit = '''
        <LinearLayout android:layout_width="match_parent" android:layout_height="match_parent"
            android:orientation="horizontal" android:gravity="center_vertical">
            <ImageView android:id="@+id/simge" android:layout_width="16dp" android:layout_height="16dp"
                android:src="@drawable/ic_bildirim" android:tint="#8B8CF8" android:importantForAccessibility="no"/>
            <ImageView android:id="@+id/nokta" android:layout_width="8dp" android:layout_height="8dp"
                android:layout_marginStart="8dp" android:src="@drawable/widget_nokta" android:importantForAccessibility="no"/>
            <TextView android:id="@+id/ozet" android:layout_width="0dp" android:layout_height="wrap_content"
                android:layout_weight="1" android:layout_marginStart="8dp" android:text="2 çalışıyor · 1 onay"
                android:textSize="13sp" android:textColor="#ECEBFF" android:maxLines="1" android:ellipsize="end"/>''' + \
    dugme("konus", "wi_mikrofon", "", agirlik=False) + dugme("yeni", "wi_ekle", "", agirlik=False) + '''
        </LinearLayout>'''

# --- büyük
ORNEK = [("Claude · sbyazilim", "çalışıyor", "#5DCAA5", "#D97757"),
         ("Codex · Ofis", "4 dk önce", "#A9A8C4", "#8B8CF8"),
         ("Claude · atolye", "dün", "#A9A8C4", "#D97757")]
satirlar = ""
for i in range(8):
    ad, durum, renk, nokta = ORNEK[i] if i < len(ORNEK) else ("Claude · oturum", "", "#A9A8C4", "#D97757")
    gorunur = '' if i < len(ORNEK) else ' android:visibility="gone"'

    satirlar += f'''
        <LinearLayout android:id="@+id/satir{i}" android:layout_width="match_parent" android:layout_height="26dp"
            android:orientation="horizontal" android:gravity="center_vertical"{gorunur}>
            <ImageView android:id="@+id/satir{i}_nokta" android:layout_width="7dp" android:layout_height="7dp"
                android:src="@drawable/widget_nokta" android:tint="{nokta}" android:importantForAccessibility="no"/>
            <TextView android:id="@+id/satir{i}_ad" android:layout_width="0dp" android:layout_height="wrap_content"
                android:layout_weight="1" android:layout_marginStart="8dp" android:text="{ad}"
                android:textSize="13sp" android:textColor="#ECEBFF" android:maxLines="1" android:ellipsize="end"/>
            <TextView android:id="@+id/satir{i}_durum" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:layout_marginStart="8dp" android:text="{durum}" android:textSize="11sp"
                android:textColor="{renk}" android:maxLines="1"/>
        </LinearLayout>'''


def kota(a, ad):
    return f'''
            <LinearLayout android:id="@+id/kota_{a}" android:layout_width="match_parent" android:layout_height="18dp"
                android:orientation="horizontal" android:gravity="center_vertical">
                <TextView android:id="@+id/kota_{a}_ad" android:layout_width="52dp" android:layout_height="wrap_content"
                    android:text="{ad}" android:textSize="11sp" android:textColor="#A9A8C4" android:maxLines="1"/>
                <ProgressBar android:id="@+id/kota_{a}_cubuk" style="?android:attr/progressBarStyleHorizontal"
                    android:layout_width="0dp" android:layout_height="4dp" android:layout_weight="1"
                    android:max="100" android:progress="50" android:progressDrawable="@drawable/widget_kota_{a}"/>
                <TextView android:id="@+id/kota_{a}_yazi" android:layout_width="wrap_content" android:layout_height="wrap_content"
                    android:layout_marginStart="8dp" android:text="%50" android:textSize="11sp"
                    android:textColor="#A9A8C4" android:maxLines="1"/>
            </LinearLayout>'''


buyuk = baslik() + '''
        <LinearLayout android:id="@+id/onay" android:layout_width="match_parent" android:layout_height="wrap_content"
            android:layout_marginTop="10dp" android:orientation="vertical" android:padding="10dp"
            android:background="@drawable/widget_onay_kart">
            <TextView android:id="@+id/onay_baslik" android:layout_width="match_parent" android:layout_height="wrap_content"
                android:text="Codex · avukathesap" android:textSize="12sp" android:textColor="#FAC775"
                android:maxLines="1" android:ellipsize="end"/>
            <TextView android:id="@+id/onay_metin" android:layout_width="match_parent" android:layout_height="wrap_content"
                android:layout_marginTop="2dp" android:text="npm install çalıştırmak istiyor" android:textSize="13sp"
                android:textColor="#ECEBFF" android:maxLines="2" android:ellipsize="end"/>
            <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
                android:layout_marginTop="8dp" android:orientation="horizontal">''' + \
    dugme("izin", "wi_ekle", "İzin ver", bas=True).replace('android:src="@drawable/wi_ekle"', 'android:src="@drawable/wi_ekle" android:visibility="gone"') + \
    dugme("hep", "wi_ekle", "Bu oturumda hep").replace('android:src="@drawable/wi_ekle"', 'android:src="@drawable/wi_ekle" android:visibility="gone"') + \
    dugme("red", "wi_ekle", "Reddet").replace('android:src="@drawable/wi_ekle"', 'android:src="@drawable/wi_ekle" android:visibility="gone"') + '''
            </LinearLayout>
        </LinearLayout>
        <LinearLayout android:id="@+id/liste" android:layout_width="match_parent" android:layout_height="wrap_content"
            android:layout_marginTop="8dp" android:orientation="vertical">''' + satirlar + '''
        </LinearLayout>
        <TextView android:id="@+id/bos" android:layout_width="match_parent" android:layout_height="wrap_content"
            android:layout_marginTop="10dp" android:text="Henüz oturum yok" android:textSize="12sp"
            android:textColor="#A9A8C4" android:visibility="gone"/>
        <FrameLayout android:layout_width="1dp" android:layout_height="0dp" android:layout_weight="1"/>
        <LinearLayout android:id="@+id/kota" android:layout_width="match_parent" android:layout_height="wrap_content"
            android:layout_marginTop="6dp" android:orientation="vertical">''' + kota("claude", "Claude") + kota("codex", "Codex") + '''
        </LinearLayout>
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
            android:layout_marginTop="8dp" android:orientation="horizontal">''' + \
    dugme("konus", "wi_mikrofon", "Konuş", bas=True) + dugme("yeni", "wi_ekle", "Yeni") + dugme("ara", "wi_ara", "Ara") + '''
        </LinearLayout>'''

(RES / "layout/widget_kucuk.xml").write_text(kok(kucuk, dolgu="12dp"))
(RES / "layout/widget_serit.xml").write_text(kok(serit, dolgu="10dp"))
(RES / "layout/widget_buyuk.xml").write_text(kok(buyuk))
print("tamam")
