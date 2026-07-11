# -*- coding: utf-8 -*-
"""CareLink — Premium Graduation Presentation v2
   Visual reference: Modern healthcare startup pitch deck
   Matches: reference image layouts, spacing, typography, color palette
"""
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.oxml.ns import qn
from lxml import etree

W = Inches(13.33)
H = Inches(7.5)

# ── Brand palette ──────────────────────────────────────────────────────────
NAVY    = RGBColor(0x0F, 0x23, 0x36)
TEAL    = RGBColor(0x0D, 0x94, 0x88)
TEAL_L  = RGBColor(0x14, 0xB8, 0xA6)
TEAL_LL = RGBColor(0x5E, 0xEA, 0xD4)
MINT_BG = RGBColor(0xF0, 0xFD, 0xFA)
WHITE   = RGBColor(0xFF, 0xFF, 0xFF)
GRAY_50 = RGBColor(0xF8, 0xFA, 0xFC)
GRAY_100= RGBColor(0xF1, 0xF5, 0xF9)
GRAY_200= RGBColor(0xE2, 0xE8, 0xF0)
GRAY_300= RGBColor(0xCB, 0xD5, 0xE1)
GRAY_400= RGBColor(0x94, 0xA3, 0xB8)
GRAY_500= RGBColor(0x64, 0x74, 0x8B)
GRAY_700= RGBColor(0x33, 0x41, 0x55)
GRAY_900= RGBColor(0x0F, 0x17, 0x2A)
AMBER   = RGBColor(0xF5, 0x9E, 0x0B)
AMBER_L = RGBColor(0xFE, 0xF3, 0xC7)
GREEN   = RGBColor(0x10, 0xB9, 0x81)
GREEN_L = RGBColor(0xD1, 0xFA, 0xE5)
VIOLET  = RGBColor(0x81, 0x8C, 0xF8)
VIOLET_L= RGBColor(0xED, 0xE9, 0xFE)
ROSE    = RGBColor(0xFB, 0x71, 0x85)
ROSE_L  = RGBColor(0xFF, 0xE4, 0xE6)
BLUE    = RGBColor(0x38, 0xBD, 0xF8)
BLUE_L  = RGBColor(0xE0, 0xF2, 0xFE)
SKY     = RGBColor(0x06, 0xB6, 0xD4)
FONT = "Calibri"

prs = Presentation()
prs.slide_width  = W
prs.slide_height = H
BLANK = prs.slide_layouts[6]

# ── Low-level helpers ──────────────────────────────────────────────────────
def _rgb(c): return f"{c[0]:02X}{c[1]:02X}{c[2]:02X}"
def _cl(v): return max(0, min(255, int(v)))
def lighten(c, f=0.7):
    return RGBColor(_cl(c[0]+(255-c[0])*f), _cl(c[1]+(255-c[1])*f), _cl(c[2]+(255-c[2])*f))

def _spPr(s): return s._element.find(qn('p:spPr'))

def _round(s, adj=30000):
    spPr = _spPr(s)
    for o in spPr.findall(qn('a:prstGeom')): spPr.remove(o)
    spPr.insert(0, etree.fromstring(
        f'<a:prstGeom xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"'
        f' prst="roundRect"><a:avLst><a:gd name="adj" fmla="val {adj}"/></a:avLst></a:prstGeom>'))

def _grad(s, c1, c2, ang=90):
    ns = "http://schemas.openxmlformats.org/drawingml/2006/main"
    spPr = _spPr(s)
    for t in ['solidFill','gradFill','noFill','blipFill','pattFill']:
        for e in spPr.findall(f'{{{ns}}}{t}'): spPr.remove(e)
    spPr.insert(0, etree.fromstring(
        f'<a:gradFill xmlns:a="{ns}"><a:gsLst>'
        f'<a:gs pos="0"><a:srgbClr val="{_rgb(c1)}"/></a:gs>'
        f'<a:gs pos="100000"><a:srgbClr val="{_rgb(c2)}"/></a:gs>'
        f'</a:gsLst><a:lin ang="{int(ang*60000)}" scaled="0"/></a:gradFill>'))

def R(sl, l, t, w, h, fill=WHITE, lc=None, lw=Pt(1)):
    s = sl.shapes.add_shape(1, l, t, w, h)
    s.fill.solid(); s.fill.fore_color.rgb = fill
    s.line.fill.background()
    if lc: s.line.color.rgb = lc; s.line.width = lw
    return s

def RR(sl, l, t, w, h, fill=WHITE, lc=None, lw=Pt(1), adj=28000):
    s = R(sl, l, t, w, h, fill, lc, lw); _round(s, adj); return s

def GR(sl, l, t, w, h, c1, c2, ang=90, rnd=False, adj=28000):
    s = sl.shapes.add_shape(1, l, t, w, h)
    s.line.fill.background()
    if rnd: _round(s, adj)
    _grad(s, c1, c2, ang); return s

def OV(sl, cx, cy, r, fill=TEAL, lc=None, lw=Pt(1)):
    s = sl.shapes.add_shape(9, cx-r, cy-r, r*2, r*2)
    s.fill.solid(); s.fill.fore_color.rgb = fill
    s.line.fill.background()
    if lc: s.line.color.rgb = lc; s.line.width = lw
    return s

def OVR(sl, cx, cy, r, lc=TEAL, lw=Pt(2)):
    s = sl.shapes.add_shape(9, cx-r, cy-r, r*2, r*2)
    s.fill.background(); s.line.color.rgb = lc; s.line.width = lw; return s

def CN(sl, x1, y1, x2, y2, c=GRAY_300, lw=Pt(1.5)):
    s = sl.shapes.add_connector(1, x1, y1, x2, y2)
    s.line.color.rgb = c; s.line.width = lw; return s

def T(sl, text, l, t, w, h, sz=12, bold=False, color=GRAY_700,
      align=PP_ALIGN.LEFT, italic=False):
    b = sl.shapes.add_textbox(l, t, w, h)
    tf = b.text_frame; tf.word_wrap = True
    p = tf.paragraphs[0]; p.alignment = align
    r2 = p.add_run()
    r2.text = text; r2.font.name = FONT
    r2.font.size = Pt(sz); r2.font.bold = bold
    r2.font.color.rgb = color; r2.font.italic = italic
    return b

def Tmulti(sl, lines, l, t, w, h, default_sz=12, default_color=GRAY_700,
           default_align=PP_ALIGN.LEFT, line_sp=Pt(4)):
    b = sl.shapes.add_textbox(l, t, w, h)
    tf = b.text_frame; tf.word_wrap = True
    for i, ln in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = ln.get('align', default_align)
        p.space_after = line_sp
        r2 = p.add_run()
        r2.text = ln.get('text', '')
        r2.font.name = FONT
        r2.font.size = Pt(ln.get('sz', default_sz))
        r2.font.bold = ln.get('bold', False)
        r2.font.color.rgb = ln.get('color', default_color)
    return b

def fade_trans(sl):
    try:
        sl._element.append(etree.fromstring(
            '<p:transition xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"'
            ' spd="med" advClick="1"><p:fade/></p:transition>'))
    except: pass

# ── Design components ──────────────────────────────────────────────────────
def slide_bg(sl, color=WHITE):
    R(sl, 0, 0, W, H, fill=color)

def tag(sl, text, l=Inches(0.78), t=Inches(0.36)):
    T(sl, text.upper(), l, t, Inches(5), Inches(0.28), sz=8.5, bold=True, color=TEAL)

def h1(sl, text, l=Inches(0.78), t=Inches(0.68), w=Inches(11.8), color=NAVY):
    return T(sl, text, l, t, w, Inches(1.0), sz=36, bold=True, color=color)

def h1_teal(sl, text, l=Inches(0.78), t=Inches(0.68), w=Inches(11.8)):
    """Title where last word is teal — simulate by splitting"""
    return T(sl, text, l, t, w, Inches(1.0), sz=36, bold=True, color=NAVY)

def sub(sl, text, l=Inches(0.78), t=Inches(1.55), w=Inches(10.5), color=GRAY_500):
    return T(sl, text, l, t, w, Inches(0.42), sz=13.5, color=color)

def rule(sl, t=Inches(1.5)):
    GR(sl, Inches(0.78), t, Inches(0.75), Inches(0.038), TEAL_L, TEAL)

def shadow_card(sl, l, t, w, h, fill=WHITE, lc=GRAY_200, lw=Pt(1.0), adj=25000):
    RR(sl, l+Inches(0.04), t+Inches(0.05), w, h, fill=GRAY_200, adj=adj)
    return RR(sl, l, t, w, h, fill=fill, lc=lc, lw=lw, adj=adj)

def kpi_bar(sl, items):
    t0 = H - Inches(0.82)
    R(sl, 0, t0, W, Inches(0.82), fill=MINT_BG)
    CN(sl, 0, t0, W, t0, c=GRAY_200, lw=Pt(0.8))
    cw = W / len(items)
    for i, (v, lbl) in enumerate(items):
        x = cw * i
        T(sl, v, x, t0+Inches(0.04), cw, Inches(0.38), sz=21, bold=True,
          color=TEAL, align=PP_ALIGN.CENTER)
        T(sl, lbl, x, t0+Inches(0.45), cw, Inches(0.28), sz=8.5,
          color=GRAY_500, align=PP_ALIGN.CENTER)

def slide_num(sl, n):
    T(sl, str(n), W-Inches(0.5), H-Inches(0.35), Inches(0.38), Inches(0.3),
      sz=9, color=GRAY_400, align=PP_ALIGN.CENTER)

# ── Phone mockup ──────────────────────────────────────────────────────────
def phone(sl, cx, cy, scale=1.0, screen_lines=None):
    """Build a realistic phone shape centered at cx, cy"""
    pw = Inches(1.85*scale); ph = Inches(3.65*scale)
    pl = cx - pw/2; pt = cy - ph/2
    # Outer body shadow
    RR(sl, pl+Inches(0.1*scale), pt+Inches(0.12*scale), pw, ph,
       fill=RGBColor(0x0A,0x18,0x26), adj=22000)
    # Outer body
    body = RR(sl, pl, pt, pw, ph, fill=NAVY, adj=22000)
    body.line.color.rgb = RGBColor(0x1E,0x40,0x58); body.line.width = Pt(1.5)
    # Screen area
    sw = pw - Inches(0.22*scale); sh = ph - Inches(0.55*scale)
    sl_off = pl + Inches(0.11*scale); st_off = pt + Inches(0.28*scale)
    # Screen gradient (teal app feel)
    GR(sl, sl_off, st_off, sw, sh, MINT_BG, WHITE, 180, rnd=True, adj=14000)
    # Notch
    OV(sl, cx, pt+Inches(0.14*scale), Inches(0.07*scale), fill=NAVY)
    # Home bar
    RR(sl, cx-Inches(0.3*scale), pt+ph-Inches(0.16*scale),
       Inches(0.6*scale), Inches(0.055*scale),
       fill=RGBColor(0x38,0x52,0x65), adj=50000)
    # App content (simplified)
    # Status bar teal strip
    GR(sl, sl_off, st_off, sw, Inches(0.28*scale), TEAL, TEAL_L, 0,
       rnd=True, adj=12000)
    # White header bar
    T(sl, "CareLink", sl_off, st_off+Inches(0.05*scale), sw, Inches(0.22*scale),
      sz=max(6, int(8*scale)), bold=True, color=WHITE, align=PP_ALIGN.CENTER)
    # App list items
    item_colors = [TEAL_LL, GRAY_100, GRAY_100, GRAY_100]
    for i in range(4):
        iy = st_off + Inches(0.32*scale) + Inches(0.52*scale)*i
        if iy + Inches(0.44*scale) < pt + ph - Inches(0.2*scale):
            RR(sl, sl_off+Inches(0.05*scale), iy,
               sw-Inches(0.1*scale), Inches(0.44*scale),
               fill=item_colors[i], adj=12000)
            OV(sl, sl_off+Inches(0.22*scale), iy+Inches(0.22*scale),
               Inches(0.14*scale), fill=TEAL)
    return body

# ── Person avatar ──────────────────────────────────────────────────────────
def avatar(sl, cx, cy, role="P", color=TEAL, size=1.0):
    """Simple person illustration"""
    skin = RGBColor(0xFD,0xD8,0xC4)
    hair = RGBColor(0x3D,0x2B,0x1F)
    # Body/torso
    bw = Inches(0.7*size); bh = Inches(0.7*size)
    RR(sl, cx-bw/2, cy+Inches(0.25*size), bw, bh, fill=lighten(color, 0.4), adj=20000)
    # Head
    OV(sl, cx, cy, Inches(0.28*size), fill=skin)
    # Hair
    OV(sl, cx, cy-Inches(0.14*size), Inches(0.2*size), fill=hair)
    # Role badge
    OV(sl, cx+Inches(0.28*size), cy-Inches(0.28*size), Inches(0.14*size), fill=color)
    T(sl, role, cx+Inches(0.14*size), cy-Inches(0.42*size),
      Inches(0.28*size), Inches(0.28*size), sz=6, bold=True, color=WHITE,
      align=PP_ALIGN.CENTER)

# ── Icon builders ──────────────────────────────────────────────────────────
def icon_box(sl, cx, cy, r, color, symbol, sz=16, light_bg=True):
    """Rounded square icon with symbol"""
    ir = r * 0.9
    fill = lighten(color, 0.82) if light_bg else color
    tc = color if light_bg else WHITE
    RR(sl, cx-ir, cy-ir, ir*2, ir*2, fill=fill, adj=22000)
    T(sl, symbol, cx-ir, cy-ir*0.75, ir*2, ir*1.5, sz=sz, bold=True,
      color=tc, align=PP_ALIGN.CENTER)

def tech_logo(sl, l, t, w, h, name, abbr, color, bg_color):
    """Technology logo card"""
    shadow_card(sl, l, t, w, h, fill=WHITE, adj=22000)
    # Icon area
    iw = Inches(0.62); ih = Inches(0.62)
    ix = l + (w - iw)/2; iy = t + Inches(0.22)
    RR(sl, ix, iy, iw, ih, fill=lighten(color, 0.8), adj=18000)
    T(sl, abbr, ix, iy+Inches(0.08), iw, ih-Inches(0.08),
      sz=14, bold=True, color=color, align=PP_ALIGN.CENTER)
    T(sl, name, l, t+Inches(0.96), w, Inches(0.32),
      sz=10.5, bold=True, color=NAVY, align=PP_ALIGN.CENTER)
    T(sl, bg_color, l, t+Inches(1.28), w, Inches(0.28),
      sz=8.5, color=GRAY_500, align=PP_ALIGN.CENTER)


# ══════════════════════════════════════════════════════════════════════════
# SLIDE 1 — COVER
# ══════════════════════════════════════════════════════════════════════════
def s01():
    sl = prs.slides.add_slide(BLANK); fade_trans(sl)
    slide_bg(sl, WHITE)

    # ── Left panel ──────────────────────────────────────
    # Soft teal wash behind left content
    GR(sl, 0, 0, Inches(7.6), H, MINT_BG, WHITE, 0)
    # Accent left stripe
    GR(sl, 0, 0, Inches(0.07), H, TEAL, TEAL_L, 90)

    # CareLink heart logo + wordmark
    # Heart: two circles + diamond
    hx = Inches(1.0); hy = Inches(1.1); hr = Inches(0.18)
    OV(sl, hx,       hy, hr, fill=TEAL)
    OV(sl, hx+Inches(0.22), hy, hr, fill=TEAL)
    # Lower triangle of heart (diamond shape)
    s_h = sl.shapes.add_shape(4, hx-Inches(0.04), hy+Inches(0.06),
                               Inches(0.44), Inches(0.3))
    s_h.fill.solid(); s_h.fill.fore_color.rgb = TEAL
    s_h.line.fill.background()

    T(sl, "CareLink", Inches(1.55), Inches(0.9), Inches(4), Inches(0.55),
      sz=28, bold=True, color=NAVY)

    # Main title
    T(sl, "AI-Powered\nHome Healthcare,", Inches(0.8), Inches(1.6),
      Inches(6.5), Inches(1.5), sz=40, bold=True, color=NAVY)
    T(sl, "Redefined", Inches(0.8), Inches(3.08), Inches(6.5), Inches(0.85),
      sz=40, bold=True, color=TEAL_L)

    # Tagline
    T(sl, "Intelligent care. Trusted providers. Better lives.",
      Inches(0.8), Inches(4.0), Inches(6.5), Inches(0.45),
      sz=13, color=GRAY_500, italic=True)

    # Role chips
    roles = [("Patient",TEAL),("Doctor",SKY),("Nurse",GREEN),("Admin",AMBER)]
    for i,(lbl,col) in enumerate(roles):
        px = Inches(0.8) + Inches(1.55)*i
        s = RR(sl, px, Inches(4.65), Inches(1.38), Inches(0.44),
               fill=lighten(col,0.82), adj=50000)
        s.line.color.rgb = lighten(col,0.5); s.line.width = Pt(0.8)
        OV(sl, px+Inches(0.22), Inches(4.87), Inches(0.12), fill=col)
        T(sl, lbl, px+Inches(0.38), Inches(4.7), Inches(0.95), Inches(0.38),
          sz=11, bold=True, color=col)

    # Bottom info strip
    R(sl, 0, H-Inches(0.9), Inches(7.6), Inches(0.9),
      fill=RGBColor(0xE6,0xF8,0xF5))
    CN(sl, 0, H-Inches(0.9), W, H-Inches(0.9), c=GRAY_200)
    info = [
        "Graduation Project  ·  Faculty of Engineering  ·  Computer Science Department",
        "Academic Year 2025 – 2026"
    ]
    for i,txt in enumerate(info):
        T(sl, txt, Inches(0.8), H-Inches(0.82)+Inches(0.32)*i,
          Inches(6.5), Inches(0.3), sz=9.5, color=GRAY_500)

    # ── Right panel — phone + decoration ────────────────
    # Teal gradient background right panel
    GR(sl, Inches(7.5), 0, Inches(5.83), H,
       RGBColor(0x0D,0x78,0x70), RGBColor(0x14,0xB8,0xA6), 135)

    # Decorative rings
    OVR(sl, Inches(10.5), Inches(3.7), Inches(2.8),
        lc=RGBColor(0xFF,0xFF,0xFF), lw=Pt(0.5))
    OVR(sl, Inches(10.5), Inches(3.7), Inches(2.2),
        lc=RGBColor(0xFF,0xFF,0xFF), lw=Pt(0.8))
    OVR(sl, Inches(10.5), Inches(3.7), Inches(1.6),
        lc=RGBColor(0xFF,0xFF,0xFF), lw=Pt(0.5))

    # Plus/cross decorators
    for (px2,py2,sz2) in [(Inches(8.1),Inches(1.0),0.18),(Inches(12.7),Inches(2.0),0.14),
                          (Inches(8.5),Inches(6.3),0.12)]:
        R(sl, px2-Inches(0.04), py2-Inches(sz2/2),
          Inches(0.08), Inches(sz2), fill=WHITE)
        R(sl, px2-Inches(sz2/2), py2-Inches(0.04),
          Inches(sz2), Inches(0.08), fill=WHITE)

    # Phone mockup
    phone(sl, Inches(10.5), Inches(3.7), scale=1.05)

    # "AI Recommendation" floating card
    fc = RR(sl, Inches(7.55), Inches(5.3), Inches(2.45), Inches(0.9),
            fill=WHITE, adj=18000)
    fc.line.color.rgb = GRAY_200; fc.line.width = Pt(0.8)
    OV(sl, Inches(7.95), Inches(5.75), Inches(0.22), fill=TEAL)
    T(sl, "AI Recommendation", Inches(8.22), Inches(5.36),
      Inches(1.7), Inches(0.3), sz=9, bold=True, color=NAVY)
    T(sl, "Best match for you", Inches(8.22), Inches(5.66),
      Inches(1.7), Inches(0.25), sz=8, color=GRAY_500)

    slide_num(sl, 1)
    return sl

# ══════════════════════════════════════════════════════════════════════════
# SLIDE 2 — INTRODUCTION
# ══════════════════════════════════════════════════════════════════════════
def s02():
    sl = prs.slides.add_slide(BLANK); fade_trans(sl)
    slide_bg(sl)
    tag(sl, "Introduction")
    # Title with "CareLink?" in teal
    T(sl, "What is ", Inches(0.78), Inches(0.66), Inches(3.5), Inches(0.78),
      sz=36, bold=True, color=NAVY)
    T(sl, "CareLink?", Inches(2.72), Inches(0.66), Inches(4.5), Inches(0.78),
      sz=36, bold=True, color=TEAL_L)
    rule(sl)

    # Left: description
    T(sl, "A full-stack mobile platform built for\nhome healthcare delivery",
      Inches(0.78), Inches(1.65), Inches(4.5), Inches(0.78),
      sz=14.5, bold=True, color=NAVY)
    T(sl,
      "CareLink connects patients with verified doctors and nurses through an "
      "intelligent, bilingual (Arabic / English) mobile application — featuring "
      "AI-driven provider matching, real-time scheduling, structured medical "
      "records, in-app chat, and a governed payment system.",
      Inches(0.78), Inches(2.55), Inches(4.5), Inches(1.5),
      sz=12, color=GRAY_500)

    # ── 3 role columns (right area) ────────────────────
    roles = [
        ("Patient", TEAL,   "P",
         ["Easy booking","AI recommendations","Medical records","Real-time chat"]),
        ("Doctor",  SKY,    "D",
         ["Manage requests","Availability & schedule","Clinical reports","Rate approval"]),
        ("Nurse",   GREEN,  "N",
         ["Home visits","Visit tracking","Reports & notes","Earnings"]),
    ]
    cw2 = Inches(2.52); gap2 = Inches(0.18)
    x0 = Inches(5.55)
    for i,(role,col,ic,items) in enumerate(roles):
        lx = x0 + (cw2+gap2)*i
        ty = Inches(1.58)
        # Card
        shadow_card(sl, lx, ty, cw2, Inches(5.35), fill=WHITE, adj=22000)
        # Top teal header
        GR(sl, lx, ty, cw2, Inches(1.1), col, lighten(col,0.3), 135, rnd=True, adj=22000)
        # Avatar
        avatar(sl, lx+cw2/2, ty+Inches(0.55), ic, col, size=0.85)
        # Role label
        T(sl, role, lx, ty+Inches(1.18), cw2, Inches(0.38),
          sz=14.5, bold=True, color=col, align=PP_ALIGN.CENTER)
        # Items
        for j,it in enumerate(items):
            iy = ty + Inches(1.68) + Inches(0.82)*j
            OV(sl, lx+Inches(0.3), iy+Inches(0.18), Inches(0.1), fill=col)
            T(sl, it, lx+Inches(0.5), iy, cw2-Inches(0.6), Inches(0.36),
              sz=11, color=GRAY_700)

    kpi_bar(sl, [("4","User Roles"),("12","API Route Groups"),
                 ("AR / EN","Bilingual Interface"),("AI","Smart Matching")])
    slide_num(sl, 2)
    return sl

# ══════════════════════════════════════════════════════════════════════════
# SLIDE 3 — PROBLEM STATEMENT
# ══════════════════════════════════════════════════════════════════════════
def s03():
    sl = prs.slides.add_slide(BLANK); fade_trans(sl)
    slide_bg(sl, GRAY_50)
    tag(sl, "The Challenge")
    h1(sl, "Three Gaps in Home Healthcare")
    rule(sl)

    probs = [
        ("01", "No Unified Platform",
         "Patients lacked a single trusted source to discover, verify, "
         "and book qualified home-care doctors and nurses — forcing "
         "reliance on informal referrals and unverified contacts.",
         ROSE,   ROSE_L,   "X"),
        ("02", "Fragmented Scheduling",
         "No real-time availability checking, no conflict detection, "
         "no reschedule workflow. Appointments were lost to "
         "double-bookings, no-shows, and no audit trail.",
         AMBER,  AMBER_L,  "~"),
        ("03", "Opaque Payments\n& No Governance",
         "No cancellation policy, no provider rate approval gate, "
         "no escrow mechanism. Neither patients nor providers had "
         "financial or contractual protection.",
         VIOLET, VIOLET_L, "$"),
    ]
    cw3 = Inches(3.88); gap3 = Inches(0.19); ty3 = Inches(1.82)
    for i,(num,title,desc,col,bg,sym) in enumerate(probs):
        lx = Inches(0.6) + (cw3+gap3)*i
        shadow_card(sl, lx, ty3, cw3, Inches(5.25), fill=WHITE, adj=24000)
        # Accent top band
        GR(sl, lx, ty3, cw3, Inches(0.06), col, lighten(col,0.2), 0)
        # Number badge top-right
        OV(sl, lx+cw3-Inches(0.42), ty3+Inches(0.28), Inches(0.28), fill=lighten(col,0.5))
        T(sl, num, lx+cw3-Inches(0.7), ty3+Inches(0.06),
          Inches(0.56), Inches(0.44), sz=11, bold=True, color=col, align=PP_ALIGN.CENTER)
        # Icon circle
        OV(sl, lx+Inches(0.55), ty3+Inches(0.76), Inches(0.42), fill=lighten(col,0.75))
        T(sl, sym, lx+Inches(0.13), ty3+Inches(0.34),
          Inches(0.84), Inches(0.84), sz=22, bold=True, color=col, align=PP_ALIGN.CENTER)
        # Title
        T(sl, title, lx+Inches(0.22), ty3+Inches(1.38),
          cw3-Inches(0.44), Inches(0.75), sz=16, bold=True, color=NAVY)
        # Desc
        T(sl, desc, lx+Inches(0.22), ty3+Inches(2.25),
          cw3-Inches(0.44), Inches(2.8), sz=12, color=GRAY_500)

    slide_num(sl, 3)
    return sl

# ══════════════════════════════════════════════════════════════════════════
# SLIDE 4 — OUR SOLUTION
# ══════════════════════════════════════════════════════════════════════════
def s04():
    sl = prs.slides.add_slide(BLANK); fade_trans(sl)
    slide_bg(sl)
    tag(sl, "Our Solution")
    h1(sl, "CareLink — End-to-End Home Care")
    rule(sl)

    # ── Booking flow diagram ───────────────────────────
    steps = [
        ("S","Find\nProviders",   TEAL),
        ("C","Choose\nDate & Time",SKY),
        ("P","Set\nLocation",     GREEN),
        ("$","Secure\nPayment",   AMBER),
        ("✓","Care\nDelivered",   VIOLET),
    ]
    flow_y = Inches(2.38); node_r = Inches(0.42)
    total_w = Inches(12.0); step_w = total_w / len(steps)
    flow_x0 = Inches(0.65)

    for i,(sym,label,col) in enumerate(steps):
        cx = flow_x0 + step_w*i + step_w/2
        # Connection line to next
        if i < len(steps)-1:
            nx = flow_x0 + step_w*(i+1) + step_w/2
            CN(sl, cx+node_r, flow_y, nx-node_r, flow_y, c=GRAY_300, lw=Pt(1.8))
            # Arrow tip
            CN(sl, nx-node_r-Inches(0.1), flow_y-Inches(0.07), nx-node_r, flow_y,
               c=GRAY_300, lw=Pt(1.8))
            CN(sl, nx-node_r-Inches(0.1), flow_y+Inches(0.07), nx-node_r, flow_y,
               c=GRAY_300, lw=Pt(1.8))
        # Step number
        T(sl, str(i+1), cx-node_r, flow_y-Inches(0.88),
          node_r*2, Inches(0.28), sz=9, color=GRAY_400, align=PP_ALIGN.CENTER)
        # Circle
        OV(sl, cx, flow_y, node_r, fill=lighten(col,0.78))
        OVR(sl, cx, flow_y, node_r, lc=col, lw=Pt(2.2))
        T(sl, sym, cx-node_r, flow_y-node_r*0.65,
          node_r*2, node_r*1.3, sz=18, bold=True, color=col, align=PP_ALIGN.CENTER)
        # Label
        T(sl, label, cx-step_w/2+Inches(0.1), flow_y+node_r+Inches(0.1),
          step_w-Inches(0.2), Inches(0.65), sz=11, bold=True, color=NAVY,
          align=PP_ALIGN.CENTER)

    # ── 4 feature highlights ───────────────────────────
    feats = [
        ("AI","AI Recommendation\nSmart provider matching",          TEAL),
        ("$", "Secure Payments\nSimulated escrow & refund policy",    SKY),
        ("M", "Medical Records\nStructured & continuous care",        GREEN),
        ("C", "Real-time Chat\nAR/EN · Voice · Read receipts",        VIOLET),
    ]
    fw = Inches(2.95); fh = Inches(1.42); fy = Inches(5.4)
    for i,(sym,txt,col) in enumerate(feats):
        lx = Inches(0.6) + (fw+Inches(0.18))*i
        shadow_card(sl, lx, fy, fw, fh, fill=WHITE, adj=22000)
        OV(sl, lx+Inches(0.4), fy+fh/2, Inches(0.3), fill=lighten(col,0.75))
        T(sl, sym, lx+Inches(0.1), fy+Inches(0.24),
          Inches(0.6), Inches(0.6), sz=18, bold=True, color=col, align=PP_ALIGN.CENTER)
        lines2 = txt.split('\n')
        T(sl, lines2[0], lx+Inches(0.78), fy+Inches(0.2),
          fw-Inches(0.96), Inches(0.42), sz=12, bold=True, color=NAVY)
        if len(lines2)>1:
            T(sl, lines2[1], lx+Inches(0.78), fy+Inches(0.62),
              fw-Inches(0.96), Inches(0.7), sz=10.5, color=GRAY_500)

    slide_num(sl, 4)
    return sl

# ══════════════════════════════════════════════════════════════════════════
# SLIDE 5 — KEY FEATURES
# ══════════════════════════════════════════════════════════════════════════
def s05():
    sl = prs.slides.add_slide(BLANK); fade_trans(sl)
    slide_bg(sl, GRAY_50)
    tag(sl, "What We Built")
    h1(sl, "Key Features")
    rule(sl)

    feats5 = [
        ("S", "5-Step Booking Flow",
         "Provider search → Date & time → Visit location (GPS) → Review → Mock-card payment",
         TEAL, lighten(TEAL, 0.88)),
        ("C", "Real-Time In-App Chat",
         "Messages with image, PDF & voice attachments. Read receipts, conversation threads.",
         SKY, lighten(SKY, 0.88)),
        ("M", "Structured Medical Records",
         "ICD-coded disease & allergy databases. Doctor notes, blood type, lab results.",
         GREEN, lighten(GREEN, 0.88)),
        ("G", "Cancellation & Refund Policy",
         "100% refund before provider acceptance. 80% refund after. 10%+10% fee split.",
         AMBER, lighten(AMBER, 0.88)),
        ("W", "Provider Wallet & Escrow",
         "Per-provider wallet with pending/paid balance. Admin commission. Transaction ledger.",
         VIOLET, lighten(VIOLET, 0.88)),
        ("R", "Rate Approval Gate",
         "Admin sets rate → Provider reviews & accepts → Account activates after approval.",
         ROSE, lighten(ROSE, 0.88)),
    ]

    cw5 = Inches(4.0); ch5 = Inches(2.25)
    cols5 = [Inches(0.5), Inches(4.68), Inches(8.85)]
    rows5 = [Inches(1.82), Inches(4.22)]

    for i,(sym,title,desc,col,bgc) in enumerate(feats5):
        row5,ci5 = divmod(i,3)
        lx = cols5[ci5]; ty = rows5[row5]
        shadow_card(sl, lx, ty, cw5, ch5, fill=WHITE, adj=22000)
        # Left accent
        GR(sl, lx, ty, Inches(0.058), ch5, col, lighten(col,0.3), 90)
        # Icon rounded square
        RR(sl, lx+Inches(0.22), ty+Inches(0.22),
           Inches(0.58), Inches(0.58), fill=bgc, adj=18000)
        T(sl, sym, lx+Inches(0.22), ty+Inches(0.22),
          Inches(0.58), Inches(0.58), sz=18, bold=True, color=col, align=PP_ALIGN.CENTER)
        # Title
        T(sl, title, lx+Inches(0.95), ty+Inches(0.18),
          cw5-Inches(1.12), Inches(0.48), sz=13, bold=True, color=NAVY)
        # Desc
        T(sl, desc, lx+Inches(0.22), ty+Inches(0.9),
          cw5-Inches(0.42), Inches(1.2), sz=11, color=GRAY_500)

    slide_num(sl, 5)
    return sl

# ══════════════════════════════════════════════════════════════════════════
# SLIDE 6 — AI RECOMMENDATION ENGINE
# ══════════════════════════════════════════════════════════════════════════
def s06():
    sl = prs.slides.add_slide(BLANK); fade_trans(sl)
    slide_bg(sl)
    tag(sl, "Intelligence Layer")
    h1(sl, "AI Recommendation Engine")
    sub(sl, "Explainable hybrid scoring · Cold-start safe · No external ML model required")
    rule(sl)

    eng_cx = Inches(6.67); eng_cy = Inches(4.1)

    # ── LEFT: Input nodes ──────────────────────────────
    inputs6 = [
        ("P","Patient Profile",      "Diseases · allergies · GPS location", TEAL),
        ("M","Medical File Tags",    "OCR text · AI analysis · analysisTags",SKY),
        ("S","Search Query",         "Free-text or voice-to-text intent",    VIOLET),
        ("G","GPS Location",         "Haversine distance calculation",        GREEN),
    ]
    iw6 = Inches(3.05); ih6 = Inches(0.82)
    for i,(sym,title,detail,col) in enumerate(inputs6):
        ty6 = Inches(2.55) + Inches(1.05)*i
        shadow_card(sl, Inches(0.38), ty6, iw6, ih6, fill=WHITE, adj=20000)
        OV(sl, Inches(0.38)+Inches(0.32), ty6+ih6/2, Inches(0.25), fill=lighten(col,0.75))
        T(sl, sym, Inches(0.38)+Inches(0.07), ty6+Inches(0.18),
          Inches(0.5), Inches(0.5), sz=15, bold=True, color=col, align=PP_ALIGN.CENTER)
        T(sl, title, Inches(0.38)+Inches(0.65), ty6+Inches(0.08),
          iw6-Inches(0.75), Inches(0.34), sz=12, bold=True, color=NAVY)
        T(sl, detail, Inches(0.38)+Inches(0.65), ty6+Inches(0.44),
          iw6-Inches(0.75), Inches(0.34), sz=9.5, color=GRAY_500)
        # Connector to center
        cy_line = ty6 + ih6/2
        CN(sl, Inches(0.38)+iw6, cy_line, eng_cx-Inches(1.4), cy_line,
           c=GRAY_200, lw=Pt(1.2))
        # Dot
        OV(sl, Inches(0.38)+iw6+Inches(0.06), cy_line, Inches(0.07), fill=col)

    # ── CENTER: AI Engine ──────────────────────────────
    # Glow rings
    for r6,op in [(Inches(1.45),0.04),(Inches(1.18),0.07),(Inches(0.95),0.12)]:
        f6 = RGBColor(_cl(TEAL[0]*(1-op)+255*op),
                      _cl(TEAL[1]*(1-op)+255*op),
                      _cl(TEAL[2]*(1-op)+255*op))
        OV(sl, eng_cx, eng_cy, r6, fill=f6)
    # Main circle gradient
    main_c = sl.shapes.add_shape(9, eng_cx-Inches(0.78), eng_cy-Inches(0.78),
                                  Inches(1.56), Inches(1.56))
    main_c.line.fill.background()
    _grad(main_c, TEAL, SKY, 135)
    # Brain icon - simplified neural lines
    OVR(sl, eng_cx, eng_cy, Inches(0.78), lc=WHITE, lw=Pt(0.5))
    T(sl, "AI", eng_cx-Inches(0.78), eng_cy-Inches(0.38),
      Inches(1.56), Inches(0.5), sz=22, bold=True, color=WHITE, align=PP_ALIGN.CENTER)
    T(sl, "Engine", eng_cx-Inches(0.78), eng_cy+Inches(0.08),
      Inches(1.56), Inches(0.3), sz=10, color=WHITE, align=PP_ALIGN.CENTER)

    # ── RIGHT: Ranked providers ────────────────────────
    rv = [("Dr. Ahmed H.","0.92",4.9,TEAL),
          ("Nurse Lina M.","0.88",4.8,SKY),
          ("Dr. Sara K.","0.81",4.7,GREEN)]
    rw6 = Inches(3.2); rh6 = Inches(0.88)
    rx6 = Inches(9.72)
    T(sl, "Ranked Providers", rx6, Inches(2.38), rw6, Inches(0.36),
      sz=11.5, bold=True, color=NAVY)
    T(sl, "Match reason · Score breakdown", rx6, Inches(2.74), rw6, Inches(0.28),
      sz=9, color=GRAY_500)
    for i,(name,score,stars,col) in enumerate(rv):
        ty6r = Inches(3.12)+Inches(1.0)*i
        shadow_card(sl, rx6, ty6r, rw6, rh6, fill=WHITE, adj=20000)
        OV(sl, rx6+Inches(0.3), ty6r+rh6/2, Inches(0.25), fill=lighten(col,0.7))
        T(sl, name[0], rx6+Inches(0.05), ty6r+Inches(0.2),
          Inches(0.5), Inches(0.5), sz=13, bold=True, color=col, align=PP_ALIGN.CENTER)
        T(sl, name, rx6+Inches(0.62), ty6r+Inches(0.1),
          rw6-Inches(1.0), Inches(0.36), sz=12, bold=True, color=NAVY)
        # Stars
        T(sl, f"★ {stars}", rx6+Inches(0.62), ty6r+Inches(0.48),
          Inches(0.8), Inches(0.28), sz=9.5, color=AMBER)
        # Score badge
        RR(sl, rx6+rw6-Inches(0.7), ty6r+Inches(0.22), Inches(0.58), Inches(0.44),
           fill=lighten(col,0.8), adj=50000)
        T(sl, score, rx6+rw6-Inches(0.7), ty6r+Inches(0.22),
          Inches(0.58), Inches(0.44), sz=13, bold=True, color=col, align=PP_ALIGN.CENTER)
        # Connector from engine
        ry6 = ty6r + rh6/2
        CN(sl, eng_cx+Inches(0.78), ry6, rx6, ry6, c=GRAY_200, lw=Pt(1.2))
        OV(sl, rx6-Inches(0.06), ry6, Inches(0.07), fill=col)

    T(sl, "· · ·", rx6+rw6/2-Inches(0.2), Inches(6.08),
      Inches(0.5), Inches(0.3), sz=14, color=GRAY_400, align=PP_ALIGN.CENTER)

    # ── Bottom scoring factors ─────────────────────────
    factors = [
        ("Specialization Match","ICD + keyword"),
        ("Experience Score","0.4 → 1.0"),
        ("Rating Score","Normalized"),
        ("Location Score","≤ 1 km = perfect"),
        ("Medical Compatibility","Tags vs specialization"),
    ]
    fcolors = [TEAL,SKY,AMBER,GREEN,VIOLET]
    fw6 = Inches(2.42); fy6 = Inches(6.65)
    for i,(label,detail) in enumerate(factors):
        lx6 = Inches(0.38) + (fw6+Inches(0.07))*i
        RR(sl, lx6, fy6, fw6, Inches(0.72), fill=lighten(fcolors[i],0.88), adj=18000)
        OV(sl, lx6+Inches(0.22), fy6+Inches(0.36), Inches(0.1), fill=fcolors[i])
        T(sl, label, lx6+Inches(0.4), fy6+Inches(0.06),
          fw6-Inches(0.5), Inches(0.32), sz=9.5, bold=True, color=NAVY)
        T(sl, detail, lx6+Inches(0.4), fy6+Inches(0.38),
          fw6-Inches(0.5), Inches(0.28), sz=8.5, color=GRAY_500)

    slide_num(sl, 6)
    return sl

# ══════════════════════════════════════════════════════════════════════════
# SLIDE 7 — SYSTEM ARCHITECTURE
# ══════════════════════════════════════════════════════════════════════════
def s07():
    sl = prs.slides.add_slide(BLANK); fade_trans(sl)
    slide_bg(sl)
    tag(sl, "How It's Built")
    h1(sl, "System Architecture")
    rule(sl)

    # 3 columns
    cols7 = [
        ("CLIENTS", TEAL,
         ["/  Patient App", "/  Doctor App", "/  Nurse App", "/  Admin Panel"]),
        ("BACKEND SERVICES\n(Node.js)", SKY,
         ["/patient", "/doctor", "/nurse", "/admin", "/providers", "/payments",
          "/recommendations", "/medical-records", "/notifications", "/api/ratings",
          "/api/email-auth", "/demo/graduation-flow"]),
        ("DATABASE\n(MySQL)", GREEN,
         ["user", "patient", "careprovider", "servicerequest",
          "payment", "medicalrecord", "availabilityslot", "message",
          "providervisitrating", "provider_rates", "provider_wallet", "admin_wallet"]),
    ]
    cw7 = Inches(3.6); cx_list = [Inches(0.55), Inches(4.88), Inches(9.2)]

    for i,(title,col,items) in enumerate(cols7):
        lx7 = cx_list[i]; ty7 = Inches(1.65)
        # Column header
        GR(sl, lx7, ty7, cw7, Inches(0.88), col, lighten(col,0.2), 135, rnd=True, adj=20000)
        T(sl, title, lx7, ty7+Inches(0.08), cw7, Inches(0.72),
          sz=11.5, bold=True, color=WHITE, align=PP_ALIGN.CENTER)
        # Items card
        shadow_card(sl, lx7, ty7+Inches(0.88), cw7, Inches(4.32), fill=WHITE, adj=20000)
        visible = items[:10]
        for j,it in enumerate(visible):
            iy7 = ty7+Inches(1.08)+Inches(0.38)*j
            if iy7 < ty7+Inches(5.0):
                OV(sl, lx7+Inches(0.22), iy7+Inches(0.14), Inches(0.08), fill=col)
                T(sl, it, lx7+Inches(0.38), iy7,
                  cw7-Inches(0.52), Inches(0.34), sz=10.5, color=GRAY_700)
        # Arrow to next
        if i < len(cols7)-1:
            mx7 = lx7 + cw7 + (cx_list[i+1]-lx7-cw7)/2
            my7 = ty7 + Inches(2.32)
            arrow_w = cx_list[i+1] - lx7 - cw7 - Inches(0.06)
            GR(sl, lx7+cw7+Inches(0.04), my7-Inches(0.015),
               arrow_w-Inches(0.04), Inches(0.03), col, lighten(col,0.4), 0)
            # Arrowhead
            CN(sl, lx7+cw7+arrow_w-Inches(0.12), my7-Inches(0.09),
               lx7+cw7+arrow_w, my7, c=col, lw=Pt(1.5))
            CN(sl, lx7+cw7+arrow_w-Inches(0.12), my7+Inches(0.09),
               lx7+cw7+arrow_w, my7, c=col, lw=Pt(1.5))

    # Bottom services row
    svcs7 = [
        ("Secure\nComm. (HTTPS)", TEAL),
        ("JWT Auth\n& Authorization", SKY),
        ("File Storage\n(Images, PDFs, Voice)", GREEN),
        ("Real-time\nNotifications", AMBER),
    ]
    sw7 = Inches(2.85); sy7 = H-Inches(1.2)
    for i,(lbl,col) in enumerate(svcs7):
        lx7b = Inches(0.55) + (sw7+Inches(0.22))*i
        RR(sl, lx7b, sy7, sw7, Inches(0.88), fill=lighten(col,0.88), adj=18000)
        OV(sl, lx7b+Inches(0.3), sy7+Inches(0.44), Inches(0.18), fill=col)
        T(sl, lbl, lx7b+Inches(0.56), sy7+Inches(0.08),
          sw7-Inches(0.68), Inches(0.78), sz=10, bold=True, color=col)

    slide_num(sl, 7)
    return sl

# ══════════════════════════════════════════════════════════════════════════
# SLIDE 8 — LIVE DEMO
# ══════════════════════════════════════════════════════════════════════════
def s08():
    sl = prs.slides.add_slide(BLANK); fade_trans(sl)
    slide_bg(sl, NAVY)

    # Left teal gradient panel
    GR(sl, 0, 0, Inches(7.2), H, RGBColor(0x0D,0x78,0x70), TEAL_L, 135)

    # "LIVE DEMO" text
    T(sl, "LIVE DEMO", Inches(0.6), Inches(1.4), Inches(6.2), Inches(1.5),
      sz=68, bold=True, color=WHITE)

    # Play button circle
    OV(sl, Inches(5.2), Inches(2.15), Inches(0.35), fill=WHITE)
    T(sl, "▶", Inches(4.85), Inches(1.8), Inches(0.7), Inches(0.7),
      sz=16, bold=True, color=TEAL, align=PP_ALIGN.CENTER)

    # Subtitle
    T(sl, "Experience CareLink\nin Action",
      Inches(0.6), Inches(3.1), Inches(6.2), Inches(1.0),
      sz=24, color=TEAL_LL)

    # Flow chips bottom left
    demo_steps = ["Booking Flow","AI Matching","Secure Payment","Doctor Accepts","Real-time Chat"]
    cw8 = Inches(1.32); ch8 = Inches(0.45); cy8 = Inches(6.0)
    for i,lbl in enumerate(demo_steps):
        lx8 = Inches(0.55) + (cw8+Inches(0.14))*i
        RR(sl, lx8, cy8, cw8, ch8, fill=RGBColor(0x06,0x3E,0x38), adj=50000)
        s8 = sl.shapes[-1]
        s8.line.color.rgb = TEAL_LL; s8.line.width = Pt(0.8)
        T(sl, lbl, lx8, cy8+Inches(0.07), cw8, ch8-Inches(0.07),
          sz=8.5, bold=True, color=TEAL_LL, align=PP_ALIGN.CENTER)
        if i < len(demo_steps)-1:
            CN(sl, lx8+cw8, cy8+ch8/2, lx8+cw8+Inches(0.14), cy8+ch8/2,
               c=TEAL_LL, lw=Pt(1))

    # Right: Phone mockup (larger)
    phone(sl, Inches(10.5), Inches(3.8), scale=1.2)

    # "Find Care" label on right panel
    T(sl, "Find Care", Inches(8.5), Inches(1.2), Inches(4.0), Inches(0.6),
      sz=13, bold=True, color=GRAY_400)

    slide_num(sl, 8)
    return sl

# ══════════════════════════════════════════════════════════════════════════
# SLIDE 9 — TECHNOLOGIES
# ══════════════════════════════════════════════════════════════════════════
def s09():
    sl = prs.slides.add_slide(BLANK); fade_trans(sl)
    slide_bg(sl, GRAY_50)
    tag(sl, "The Stack")
    h1(sl, "Technologies Used")
    rule(sl)

    techs = [
        # Row 1
        ("Flutter","F","Dart",    RGBColor(0x02,0x75,0xBD), "Cross-platform UI"),
        ("Node.js","N","JS",      RGBColor(0x33,0x99,0x33), "REST API runtime"),
        ("Express.js","e","REST", RGBColor(0x26,0x26,0x26), "Web framework"),
        ("MySQL","My","SQL",      RGBColor(0x00,0x61,0x8A), "Relational DB"),
        # Row 2
        ("Firebase","F","FCM",    RGBColor(0xFF,0xCA,0x28), "Push (planned)"),
        ("JWT","J","WT",          RGBColor(0xD6,0x3A,0xFF), "Auth tokens"),
        ("Twilio","~","SMS",      RGBColor(0xF2,0x2F,0x46), "OTP / SMS"),
        ("GitHub","G","H",        RGBColor(0x24,0x29,0x2F), "Version control"),
    ]
    tw9 = Inches(1.45); th9 = Inches(1.62); tgap = Inches(0.18)
    row_total = 4*(tw9+tgap)-tgap
    tx0 = (W - row_total) / 2
    for i,(name,abbr,sub9,col,desc) in enumerate(techs):
        row9 = i // 4; ci9 = i % 4
        lx9 = tx0 + (tw9+tgap)*ci9
        ty9 = Inches(1.85) + (th9+Inches(0.22))*row9
        shadow_card(sl, lx9, ty9, tw9, th9, fill=WHITE, adj=22000)
        # Logo box
        lbw = Inches(0.72); lbh = Inches(0.72)
        GR(sl, lx9+(tw9-lbw)/2, ty9+Inches(0.18),
           lbw, lbh, col, lighten(col,0.25), 135, rnd=True, adj=16000)
        T(sl, abbr, lx9+(tw9-lbw)/2, ty9+Inches(0.18),
          lbw, lbh, sz=16, bold=True, color=WHITE, align=PP_ALIGN.CENTER)
        # Name
        T(sl, name, lx9, ty9+Inches(1.02), tw9, Inches(0.32),
          sz=10.5, bold=True, color=NAVY, align=PP_ALIGN.CENTER)
        # Desc
        T(sl, desc, lx9, ty9+Inches(1.32), tw9, Inches(0.24),
          sz=8.5, color=GRAY_500, align=PP_ALIGN.CENTER)

    slide_num(sl, 9)
    return sl

# ══════════════════════════════════════════════════════════════════════════
# SLIDE 10 — FUTURE WORK
# ══════════════════════════════════════════════════════════════════════════
def s10():
    sl = prs.slides.add_slide(BLANK); fade_trans(sl)
    slide_bg(sl)
    tag(sl, "What's Next")
    h1(sl, "Future Roadmap")
    rule(sl)

    phases10 = [
        ("2026",  "$", "Real Payment\nGateway",
         "Stripe / HyperPay integration to replace simulated payments",
         TEAL),
        ("2026+", "V", "Video Consultation\n& Telemedicine",
         "In-app video calls between patient and care provider",
         SKY),
        ("2026+", "W", "Wearables &\nHealth Monitoring",
         "Heart rate, glucose, BP device integration via Bluetooth",
         GREEN),
        ("2026+", "AI","AI Predictive\nHealth Insights",
         "ML model trained on visit history for proactive recommendations",
         VIOLET),
    ]
    n10 = len(phases10); phase_w = W / n10
    line_y = Inches(4.0)

    # Timeline line
    GR(sl, Inches(0.6), line_y-Inches(0.018), W-Inches(1.2), Inches(0.036), TEAL_LL, TEAL, 0)

    for i,(yr,sym,title,desc,col) in enumerate(phases10):
        cx10 = Inches(0.6) + phase_w*(i+0.5)
        # Node circle
        OV(sl, cx10, line_y, Inches(0.3), fill=lighten(col,0.75))
        OVR(sl, cx10, line_y, Inches(0.3), lc=col, lw=Pt(2.2))
        # Year tag above line
        RR(sl, cx10-Inches(0.45), line_y-Inches(1.05), Inches(0.9), Inches(0.36),
           fill=lighten(col,0.88), adj=50000)
        T(sl, yr, cx10-Inches(0.45), line_y-Inches(1.05), Inches(0.9), Inches(0.36),
          sz=10, bold=True, color=col, align=PP_ALIGN.CENTER)
        # Icon circle above year
        OV(sl, cx10, line_y-Inches(1.7), Inches(0.38), fill=lighten(col,0.75))
        T(sl, sym, cx10-Inches(0.38), line_y-Inches(2.08),
          Inches(0.76), Inches(0.76), sz=18, bold=True, color=col, align=PP_ALIGN.CENTER)
        # Card below line
        cw10 = phase_w - Inches(0.36); ch10 = Inches(2.35)
        cl10 = cx10 - cw10/2
        shadow_card(sl, cl10, line_y+Inches(0.5), cw10, ch10, fill=WHITE, adj=22000)
        GR(sl, cl10, line_y+Inches(0.5), cw10, Inches(0.058), col, lighten(col,0.3), 0)
        T(sl, title, cl10+Inches(0.18), line_y+Inches(0.62),
          cw10-Inches(0.36), Inches(0.62), sz=12.5, bold=True, color=NAVY)
        T(sl, desc, cl10+Inches(0.18), line_y+Inches(1.32),
          cw10-Inches(0.36), Inches(1.4), sz=10.5, color=GRAY_500)

    slide_num(sl, 10)
    return sl

# ══════════════════════════════════════════════════════════════════════════
# SLIDE 11 — CONCLUSION
# ══════════════════════════════════════════════════════════════════════════
def s11():
    sl = prs.slides.add_slide(BLANK); fade_trans(sl)
    slide_bg(sl, GRAY_50)
    tag(sl, "Conclusion")
    h1(sl, "CareLink at a Glance")
    rule(sl)

    pillars11 = [
        ("AI","AI-Powered\nMatching",     "Smarter care\nconnections",   TEAL),
        ("$", "Secure\nPayments",         "Governed &\nprotected",       SKY),
        ("S", "Smart\nBooking",           "Real-time &\nconflict-free",  GREEN),
        ("M", "Medical\nRecords",         "Structured &\ncontinuous",    AMBER),
        ("H", "Better\nHealthcare",       "Accessible,\ntrusted, human", VIOLET),
    ]
    n11 = len(pillars11); cw11 = Inches(2.35); ch11 = Inches(3.38)
    total11 = n11*(cw11+Inches(0.14))-Inches(0.14)
    x011 = (W-total11)/2

    for i,(sym,title,sub11,col) in enumerate(pillars11):
        lx11 = x011 + (cw11+Inches(0.14))*i; ty11 = Inches(1.92)
        shadow_card(sl, lx11, ty11, cw11, ch11, fill=WHITE, adj=24000)
        # Icon
        ic_size = Inches(0.72)
        RR(sl, lx11+(cw11-ic_size)/2, ty11+Inches(0.3), ic_size, ic_size,
           fill=lighten(col,0.82), adj=20000)
        T(sl, sym, lx11+(cw11-ic_size)/2, ty11+Inches(0.3), ic_size, ic_size,
          sz=24, bold=True, color=col, align=PP_ALIGN.CENTER)
        # Title
        T(sl, title, lx11, ty11+Inches(1.18), cw11, Inches(0.65),
          sz=13.5, bold=True, color=NAVY, align=PP_ALIGN.CENTER)
        # Sub
        T(sl, sub11, lx11, ty11+Inches(1.95), cw11, Inches(0.7),
          sz=11, color=GRAY_500, align=PP_ALIGN.CENTER)
        # Bottom color bar
        GR(sl, lx11, ty11+ch11-Inches(0.055), cw11, Inches(0.055), col, lighten(col,0.3), 0)

    # Tagline
    T(sl, "♥  CareLink is building the future of home healthcare.",
      Inches(0.6), H-Inches(1.08), W-Inches(1.2), Inches(0.45),
      sz=13.5, bold=True, color=TEAL, align=PP_ALIGN.CENTER)

    slide_num(sl, 11)
    return sl

# ══════════════════════════════════════════════════════════════════════════
# SLIDE 12 — THANK YOU
# ══════════════════════════════════════════════════════════════════════════
def s12():
    sl = prs.slides.add_slide(BLANK); fade_trans(sl)
    slide_bg(sl, WHITE)

    # Soft teal wash top-left
    GR(sl, 0, 0, Inches(8.8), H, MINT_BG, WHITE, 0)
    GR(sl, 0, 0, Inches(0.07), H, TEAL, TEAL_L, 90)

    # CareLink logo top-left
    hx12=Inches(0.88); hy12=Inches(0.82); hr12=Inches(0.16)
    OV(sl, hx12, hy12, hr12, fill=TEAL)
    OV(sl, hx12+Inches(0.2), hy12, hr12, fill=TEAL)
    T(sl, "CareLink", Inches(1.32), Inches(0.66), Inches(3.5), Inches(0.48),
      sz=22, bold=True, color=NAVY)

    # Main "Thank You!"
    T(sl, "Thank You!", Inches(0.75), Inches(1.45), Inches(7.5), Inches(1.65),
      sz=66, bold=True, color=TEAL_L)

    # Tagline
    T(sl, "AI-Powered Home Healthcare, Redefined",
      Inches(0.75), Inches(3.12), Inches(7.5), Inches(0.55),
      sz=17, color=GRAY_500)

    # Accent rule
    GR(sl, Inches(0.75), Inches(3.78), Inches(2.0), Inches(0.04), TEAL_L, TEAL)

    # Any Questions?
    T(sl, "Any Questions?",
      Inches(0.75), Inches(4.1), Inches(7.5), Inches(0.55),
      sz=22, bold=True, color=GRAY_700)

    # Team info
    for i,line in enumerate([
        "Computer Science Department  ·  Faculty of Engineering",
        "Graduation Project 2025 – 2026",
        "Supervised by: [Dr. Supervisor Name]",
        "Team: [Team Member Names]",
    ]):
        T(sl, line, Inches(0.75), Inches(4.82)+Inches(0.4)*i,
          Inches(7.5), Inches(0.36), sz=11.5, color=GRAY_500)

    # Right: Illustration of doctor + patient
    # Background blob
    OV(sl, Inches(11.0), Inches(4.5), Inches(2.8),
       fill=RGBColor(0xE0,0xF8,0xF5))
    # Doctor
    avatar(sl, Inches(10.2), Inches(4.0), "D", TEAL, size=1.2)
    # Patient (elderly)
    avatar(sl, Inches(11.8), Inches(4.4), "P", SKY, size=1.1)
    # Nurse
    avatar(sl, Inches(12.8), Inches(3.9), "N", GREEN, size=1.0)
    # Connecting arc / stethoscope hint
    OVR(sl, Inches(11.5), Inches(3.8), Inches(1.4), lc=TEAL_LL, lw=Pt(0.8))

    # Decorative plus signs
    for (px12,py12,sz12) in [(Inches(8.8),Inches(1.2),0.22),(Inches(12.9),Inches(6.5),0.14)]:
        R(sl, px12-Inches(0.04), py12-Inches(sz12/2),
          Inches(0.08), Inches(sz12), fill=RGBColor(0xCC,0xF5,0xF1))
        R(sl, px12-Inches(sz12/2), py12-Inches(0.04),
          Inches(sz12), Inches(0.08), fill=RGBColor(0xCC,0xF5,0xF1))

    slide_num(sl, 12)
    return sl

# ══════════════════════════════════════════════════════════════════════════
# BUILD
# ══════════════════════════════════════════════════════════════════════════
print("Building slides...")
for i,(fn,name) in enumerate([
    (s01,"Cover"), (s02,"Introduction"), (s03,"Problem Statement"),
    (s04,"Our Solution"), (s05,"Key Features"), (s06,"AI Engine"),
    (s07,"Architecture"), (s08,"Live Demo"), (s09,"Technologies"),
    (s10,"Future Work"), (s11,"Conclusion"), (s12,"Thank You"),
]):
    print(f"  Slide {i+1:2d}  {name} ...")
    fn()

OUT = "D:/carelink-care-link/CareLink_Premium_v2.pptx"
prs.save(OUT)
print(f"\nDone  ->  {OUT}")
