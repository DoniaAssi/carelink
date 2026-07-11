# -*- coding: utf-8 -*-
"""
CareLink — Premium Graduation Defense Presentation
Design language: Apple Keynote · Stripe · Linear · Modern Healthcare Startup
All content derived exclusively from the analyzed CareLink codebase.
"""

from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.oxml.ns import qn
from lxml import etree

# ─────────────────────────────────────────────────────────────────────────────
# DESIGN TOKENS
# ─────────────────────────────────────────────────────────────────────────────
W = Inches(13.33)
H = Inches(7.5)

# Primary palette
C_NAVY       = RGBColor(0x12, 0x34, 0x4D)   # #12344D
C_TEAL       = RGBColor(0x38, 0xB2, 0xAC)   # #38B2AC
C_TEAL_L     = RGBColor(0x4F, 0xD1, 0xC5)   # #4FD1C5
C_MINT       = RGBColor(0xA7, 0xF3, 0xD0)   # #A7F3D0
C_CYAN       = RGBColor(0x06, 0xB6, 0xD4)   # #06B6D4
C_CYAN_PALE  = RGBColor(0xE0, 0xF7, 0xF4)   # very pale teal
C_GHOST      = RGBColor(0xF0, 0xFD, 0xFA)   # near-white teal

# Neutrals
C_WHITE      = RGBColor(0xFF, 0xFF, 0xFF)
C_GRAY_50    = RGBColor(0xF8, 0xFA, 0xFC)
C_GRAY_100   = RGBColor(0xF1, 0xF5, 0xF9)
C_GRAY_200   = RGBColor(0xE2, 0xE8, 0xF0)
C_GRAY_400   = RGBColor(0x94, 0xA3, 0xB8)
C_GRAY_600   = RGBColor(0x47, 0x55, 0x69)
C_GRAY_800   = RGBColor(0x1E, 0x29, 0x3B)

# Accent
C_AMBER      = RGBColor(0xF5, 0x9E, 0x0B)
C_GREEN      = RGBColor(0x10, 0xB9, 0x81)
C_VIOLET     = RGBColor(0x81, 0x8C, 0xF8)
C_ROSE       = RGBColor(0xFB, 0x71, 0x85)

FONT = "Calibri"

prs = Presentation()
prs.slide_width  = W
prs.slide_height = H
BLANK = prs.slide_layouts[6]

# ─────────────────────────────────────────────────────────────────────────────
# UTILITIES
# ─────────────────────────────────────────────────────────────────────────────
def rgb(c): return f"{c[0]:02X}{c[1]:02X}{c[2]:02X}"

def _spPr(shape): return shape._element.find(qn('p:spPr'))

def _set_round(shape, adj=40000):
    sp = shape._element
    spPr = sp.find(qn('p:spPr'))
    for old in spPr.findall(qn('a:prstGeom')):
        spPr.remove(old)
    xml = f'<a:prstGeom xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" prst="roundRect"><a:avLst><a:gd name="adj" fmla="val {adj}"/></a:avLst></a:prstGeom>'
    spPr.insert(0, etree.fromstring(xml))

def _grad_fill(shape, c1, c2, angle=135):
    spPr = _spPr(shape)
    for tag in ('a:solidFill','a:gradFill','a:noFill','a:blipFill','a:pattFill'):
        for el in spPr.findall(tag.replace('a:','{http://schemas.openxmlformats.org/drawingml/2006/main}')):
            spPr.remove(el)
    ang = int(angle * 60000)
    xml = f'''<a:gradFill xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
      <a:gsLst>
        <a:gs pos="0"><a:srgbClr val="{rgb(c1)}"/></a:gs>
        <a:gs pos="100000"><a:srgbClr val="{rgb(c2)}"/></a:gs>
      </a:gsLst>
      <a:lin ang="{ang}" scaled="0"/>
    </a:gradFill>'''
    spPr.insert(0, etree.fromstring(xml))

def rect(slide, l, t, w, h, fill=C_WHITE, line=None, lw=Pt(1)):
    s = slide.shapes.add_shape(1, l, t, w, h)
    s.fill.solid(); s.fill.fore_color.rgb = fill
    s.line.fill.background()
    if line: s.line.color.rgb = line; s.line.width = lw
    return s

def rrect(slide, l, t, w, h, fill=C_WHITE, line=None, lw=Pt(1), adj=35000):
    s = rect(slide, l, t, w, h, fill, line, lw)
    _set_round(s, adj)
    return s

def grect(slide, l, t, w, h, c1, c2, angle=135, radius=False, adj=35000):
    s = slide.shapes.add_shape(1, l, t, w, h)
    s.line.fill.background()
    if radius: _set_round(s, adj)
    _grad_fill(s, c1, c2, angle)
    return s

def oval(slide, cx, cy, r, fill=C_TEAL, line=None, lw=Pt(1.5)):
    s = slide.shapes.add_shape(9, cx-r, cy-r, r*2, r*2)
    s.fill.solid(); s.fill.fore_color.rgb = fill
    s.line.fill.background()
    if line: s.line.color.rgb = line; s.line.width = lw
    return s

def oval_ring(slide, cx, cy, r, color=C_TEAL, lw=Pt(2)):
    s = slide.shapes.add_shape(9, cx-r, cy-r, r*2, r*2)
    s.fill.background()
    s.line.color.rgb = color; s.line.width = lw
    return s

def line_shape(slide, x1, y1, x2, y2, color=C_TEAL, width=Pt(2)):
    c = slide.shapes.add_connector(1, x1, y1, x2, y2)
    c.line.color.rgb = color; c.line.width = width
    return c

def tb(slide, text, l, t, w, h,
       sz=Pt(12), bold=False, color=C_GRAY_800,
       align=PP_ALIGN.LEFT, italic=False):
    box = slide.shapes.add_textbox(l, t, w, h)
    tf = box.text_frame; tf.word_wrap = True
    p = tf.paragraphs[0]; p.alignment = align
    r = p.add_run(); r.text = text
    r.font.size = sz; r.font.bold = bold
    r.font.color.rgb = color; r.font.italic = italic
    r.font.name = FONT
    return box

def tb_multi(slide, lines, l, t, w, h,
             sz=Pt(12), bold=False, color=C_GRAY_800, align=PP_ALIGN.LEFT):
    box = slide.shapes.add_textbox(l, t, w, h)
    tf = box.text_frame; tf.word_wrap = True
    for i, line in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = align; p.space_after = Pt(3)
        r = p.add_run()
        if isinstance(line, dict):
            r.text = line.get('text', '')
            r.font.size = line.get('sz', sz)
            r.font.bold = line.get('bold', bold)
            r.font.color.rgb = line.get('color', color)
        else:
            r.text = line; r.font.size = sz; r.font.bold = bold
            r.font.color.rgb = color
        r.font.name = FONT
    return box

def slide_trans_fade(slide):
    xml = '<p:transition xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" spd="med" advClick="1"><p:fade/></p:transition>'
    try: slide._element.append(etree.fromstring(xml))
    except: pass

# ─────────────────────────────────────────────────────────────────────────────
# ANIMATION HELPERS
# ─────────────────────────────────────────────────────────────────────────────
_anim_id_counter = [100]

def _next_id():
    _anim_id_counter[0] += 1
    return _anim_id_counter[0]

NS_P = "http://schemas.openxmlformats.org/presentationml/2006/main"
NS_A = "http://schemas.openxmlformats.org/drawingml/2006/main"

def add_slide_animations(slide, anims):
    """
    anims: list of dict with keys: sp_id, delay (ms), dur (ms), preset
      preset: 'fade' (10), 'fly_up' (2), 'zoom' (19)
    Auto-play: all animations play sequentially after 0 delay (no click needed for first group).
    """
    preset_map = {'fade': ('10','0'), 'fly_up': ('2','8'), 'zoom': ('19','0')}
    _anim_id_counter[0] = 100 * (slide.slide_id if hasattr(slide,'slide_id') else 1)

    inner = ""
    for anim in anims:
        sp_id   = anim['sp_id']
        delay   = anim.get('delay', 0)
        dur     = anim.get('dur', 600)
        ptype   = anim.get('preset', 'fade')
        pid, psub = preset_map.get(ptype, ('10','0'))
        i1=_next_id(); i2=_next_id(); i3=_next_id(); i4=_next_id()

        inner += f"""
        <p:par xmlns:p="{NS_P}">
          <p:cTn id="{i1}" fill="hold">
            <p:stCondLst><p:cond delay="{delay}"/></p:stCondLst>
            <p:childTnLst>
              <p:par>
                <p:cTn id="{i2}" fill="hold">
                  <p:stCondLst><p:cond delay="0"/></p:stCondLst>
                  <p:childTnLst>
                    <p:par>
                      <p:cTn id="{i3}" presetID="{pid}" presetClass="entr" presetSubtype="{psub}"
                             fill="hold" grpId="{i1}" nodeType="withPrevious" dur="{dur}">
                        <p:stCondLst><p:cond delay="0"/></p:stCondLst>
                        <p:childTnLst>
                          <p:set>
                            <p:cBhvr>
                              <p:cTn id="{i4}" dur="1" fill="hold"/>
                              <p:tgtEl><p:spTgt spid="{sp_id}"/></p:tgtEl>
                              <p:attrNameLst><p:attrName>style.visibility</p:attrName></p:attrNameLst>
                            </p:cBhvr>
                            <p:to><p:strVal val="visible"/></p:to>
                          </p:set>
                          <p:animEffect transition="in" filter="fade"/>
                        </p:childTnLst>
                      </p:cTn>
                    </p:par>
                  </p:childTnLst>
                </p:cTn>
              </p:par>
            </p:childTnLst>
          </p:cTn>
        </p:par>"""

    root_id = _next_id(); seq_id = _next_id(); grp_id = _next_id()
    timing_xml = f"""<p:timing xmlns:p="{NS_P}">
      <p:tnLst>
        <p:par>
          <p:cTn id="{root_id}" dur="indefinite" restart="whenNotActive" nodeType="tmRoot">
            <p:childTnLst>
              <p:seq concurrent="1" nextAc="seek">
                <p:cTn id="{seq_id}" dur="indefinite" nodeType="mainSeq">
                  <p:childTnLst>
                    <p:par>
                      <p:cTn id="{grp_id}" fill="hold">
                        <p:stCondLst><p:cond delay="0"/></p:stCondLst>
                        <p:childTnLst>{inner}</p:childTnLst>
                      </p:cTn>
                    </p:par>
                  </p:childTnLst>
                </p:cTn>
                <p:prevCondLst><p:cond evt="onPrevClick" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:prevCondLst>
                <p:nextCondLst><p:cond evt="onNextClick" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:nextCondLst>
              </p:seq>
            </p:childTnLst>
          </p:cTn>
        </p:par>
      </p:tnLst>
      <p:bldLst/>
    </p:timing>"""
    try:
        slide._element.append(etree.fromstring(timing_xml))
    except Exception as e:
        pass  # silently skip if malformed

# ─────────────────────────────────────────────────────────────────────────────
# DESIGN COMPONENTS
# ─────────────────────────────────────────────────────────────────────────────
def bg_white(slide):       rect(slide, 0,0,W,H, fill=C_WHITE)
def bg_gray(slide):        rect(slide, 0,0,W,H, fill=C_GRAY_50)
def bg_navy(slide):        grect(slide, 0,0,W,H, C_NAVY, C_GRAY_800, 135)
def bg_teal(slide):        grect(slide, 0,0,W,H, C_TEAL, C_CYAN, 135)

def top_bar(slide):
    grect(slide, 0, 0, W, Inches(0.055), C_TEAL_L, C_CYAN)

def section_label(slide, text, l=Inches(0.8), t=Inches(0.35)):
    tb(slide, text.upper(), l, t, Inches(4), Inches(0.32),
       sz=Pt(9.5), bold=True, color=C_TEAL)

def h1(slide, text, l=Inches(0.8), t=Inches(0.65), w=Inches(11.8), color=C_NAVY):
    return tb(slide, text, l, t, w, Inches(0.85), sz=Pt(40), bold=True, color=color)

def h2(slide, text, l=Inches(0.8), t=Inches(1.45), w=Inches(10), color=C_GRAY_600):
    return tb(slide, text, l, t, w, Inches(0.4), sz=Pt(15), color=color)

def rule(slide, t=Inches(1.9)):
    grect(slide, Inches(0.8), t, Inches(1.2), Inches(0.045), C_TEAL_L, C_CYAN)

def chip(slide, text, l, t, w=Inches(1.8), h=Inches(0.32),
         bg=C_GHOST, tc=C_TEAL, sz=Pt(9.5)):
    s = rrect(slide, l, t, w, h, fill=bg, adj=50000)
    tb(slide, text, l, t+Inches(0.04), w, h, sz=sz, bold=True,
       color=tc, align=PP_ALIGN.CENTER)
    return s

def icon_pill(slide, icon, label, l, t, color=C_TEAL):
    rrect(slide, l, t, Inches(2.0), Inches(0.48),
          fill=RGBColor(int(color[0]*0.12), int(color[1]*0.12), int(color[2]*0.12)),
          adj=50000)
    oval(slide, l+Inches(0.28), t+Inches(0.24), Inches(0.18), fill=color)
    tb(slide, label, l+Inches(0.55), t+Inches(0.09),
       Inches(1.4), Inches(0.35), sz=Pt(11), bold=True, color=color)

def glass_card(slide, l, t, w, h, border=C_TEAL_L, lw=Pt(1.3)):
    shadow = rrect(slide, l+Inches(0.05), t+Inches(0.07), w, h,
                   fill=RGBColor(0xCB,0xE8,0xE5))
    card   = rrect(slide, l, t, w, h, fill=C_WHITE, line=border, lw=lw)
    return card

def kpi_strip(slide, items, y=Inches(6.75)):
    grect(slide, 0, y, W, Inches(0.75), C_GHOST, C_CYAN_PALE, angle=0)
    n = len(items)
    col_w = W / n
    for i, (val, lbl) in enumerate(items):
        x = col_w * i
        tb(slide, val, x, y+Inches(0.04), col_w, Inches(0.38),
           sz=Pt(20), bold=True, color=C_TEAL, align=PP_ALIGN.CENTER)
        tb(slide, lbl, x, y+Inches(0.42), col_w, Inches(0.28),
           sz=Pt(9), color=C_GRAY_600, align=PP_ALIGN.CENTER)

def arrow_down(slide, cx, y1, y2, color=C_TEAL, lw=Pt(2)):
    line_shape(slide, cx, y1, cx, y2, color=color, width=lw)
    # arrow head
    line_shape(slide, cx-Inches(0.08), y2-Inches(0.12), cx, y2, color=color, width=lw)
    line_shape(slide, cx+Inches(0.08), y2-Inches(0.12), cx, y2, color=color, width=lw)

def arrow_right(slide, x1, cy, x2, color=C_TEAL, lw=Pt(2)):
    line_shape(slide, x1, cy, x2, cy, color=color, width=lw)
    line_shape(slide, x2-Inches(0.1), cy-Inches(0.07), x2, cy, color=color, width=lw)
    line_shape(slide, x2-Inches(0.1), cy+Inches(0.07), x2, cy, color=color, width=lw)

def deco_blob(slide, cx, cy, rx, ry, color, alpha=0.18):
    """Soft decorative ellipse used as background decoration."""
    r = RGBColor(min(255,int(color[0]+( 255-color[0])*(1-alpha))),
                 min(255,int(color[1]+( 255-color[1])*(1-alpha))),
                 min(255,int(color[2]+( 255-color[2])*(1-alpha))))
    s = slide.shapes.add_shape(9, cx-rx, cy-ry, rx*2, ry*2)
    s.fill.solid(); s.fill.fore_color.rgb = r
    s.line.fill.background()
    return s

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 1 — COVER
# ─────────────────────────────────────────────────────────────────────────────
def s01_cover():
    slide = prs.slides.add_slide(BLANK); slide_trans_fade(slide)
    anims = []

    # Background gradient
    grect(slide, 0, 0, W, H, C_NAVY, C_GRAY_800, 150)

    # Decorative circles — top-right glow
    deco_blob(slide, W-Inches(1.2), Inches(1.0), Inches(2.8), Inches(2.8), C_TEAL)
    deco_blob(slide, W+Inches(0.5), Inches(0.0), Inches(2.2), Inches(2.2),
              RGBColor(0x06,0xB6,0xD4))
    # Bottom-left glow
    deco_blob(slide, Inches(0.0), H+Inches(0.2), Inches(2.0), Inches(2.0), C_TEAL_L)

    # Left accent stripe
    grect(slide, 0, 0, Inches(0.1), H, C_TEAL_L, C_CYAN, 90)

    # ── Medical cross (top-right cluster) ──
    cross_cx = Inches(10.9); cross_cy = Inches(2.4)
    cv = Inches(0.18); ch = Inches(0.6)
    # Outer ring
    oval_ring(slide, cross_cx, cross_cy, Inches(1.05),
              color=RGBColor(0x4F,0xD1,0xC5), lw=Pt(1.5))
    oval_ring(slide, cross_cx, cross_cy, Inches(1.35),
              color=RGBColor(0x38,0xB2,0xAC), lw=Pt(0.8))
    # Cross bars
    grect(slide, cross_cx-cv/2, cross_cy-ch/2, cv, ch,
          C_TEAL_L, C_CYAN, 90)
    grect(slide, cross_cx-ch/2, cross_cy-cv/2, ch, cv,
          C_TEAL_L, C_CYAN, 0)

    # ── CareLink wordmark ──
    s = tb(slide, "CareLink",
           Inches(0.85), Inches(1.8), Inches(9), Inches(1.4),
           sz=Pt(76), bold=True, color=C_WHITE)
    anims.append({'sp_id': s.shape_id, 'delay': 0, 'dur': 700, 'preset': 'fade'})

    # Teal underline
    s2 = grect(slide, Inches(0.85), Inches(3.15), Inches(4.8), Inches(0.055),
               C_TEAL_L, C_CYAN)
    anims.append({'sp_id': s2.shape_id, 'delay': 200, 'dur': 500, 'preset': 'fade'})

    # Tagline
    s3 = tb(slide, "AI-Powered Home Healthcare, Redefined",
            Inches(0.85), Inches(3.32), Inches(10), Inches(0.65),
            sz=Pt(22), color=RGBColor(0xA7,0xF3,0xD0))
    anims.append({'sp_id': s3.shape_id, 'delay': 350, 'dur': 600, 'preset': 'fade'})

    # Role pills
    roles = [("Patient", C_TEAL_L), ("Doctor", C_CYAN),
             ("Nurse", C_GREEN), ("Admin", C_AMBER)]
    for i,(lbl,col) in enumerate(roles):
        px = Inches(0.85) + Inches(2.15)*i
        bg = RGBColor(min(255,col[0]+100), min(255,col[1]+80), min(255,col[2]+60))
        p = rrect(slide, px, Inches(4.1), Inches(1.95), Inches(0.42),
                  fill=RGBColor(0x0C,0x28,0x40), adj=50000)
        oval(slide, px+Inches(0.28), Inches(4.31), Inches(0.13), fill=col)
        tb(slide, lbl, px+Inches(0.5), Inches(4.14), Inches(1.4), Inches(0.36),
           sz=Pt(12), bold=True, color=col)
        anims.append({'sp_id': p.shape_id, 'delay': 500+i*100, 'dur': 500, 'preset': 'fade'})

    # Divider
    rect(slide, Inches(0.85), Inches(4.72), Inches(11.5), Inches(0.02),
         fill=RGBColor(0x1E,0x3A,0x50))

    # Team info card
    info_bg = rrect(slide, Inches(0.7), Inches(4.9), Inches(11.9), Inches(2.2),
                    fill=RGBColor(0x0C,0x23,0x35), adj=20000)
    anims.append({'sp_id': info_bg.shape_id, 'delay': 900, 'dur': 600, 'preset': 'fade'})

    info_lines = [
        ("Graduation Project  ·  Faculty of Engineering  ·  Computer Science Department",
         Pt(13), False, C_GRAY_400),
        ("Supervised by:  [Dr. Supervisor Name]",
         Pt(12.5), False, C_GRAY_400),
        ("Team:  [Team Member Names]",
         Pt(12.5), False, C_GRAY_400),
        ("Academic Year 2025 – 2026",
         Pt(11.5), False, C_GRAY_600),
    ]
    for i,(txt,sz,bd,cl) in enumerate(info_lines):
        tb(slide, txt, Inches(1.1), Inches(5.06)+Inches(0.47)*i,
           Inches(11.1), Inches(0.42), sz=sz, bold=bd, color=cl)

    add_slide_animations(slide, anims)
    return slide

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 2 — INTRODUCTION
# ─────────────────────────────────────────────────────────────────────────────
def s02_intro():
    slide = prs.slides.add_slide(BLANK); slide_trans_fade(slide)
    anims = []
    bg_white(slide); top_bar(slide)

    section_label(slide, "Introduction")
    h1s = h1(slide, "What is CareLink?")
    anims.append({'sp_id': h1s.shape_id, 'delay': 0, 'dur': 600})

    h2s = h2(slide, "A full-stack mobile platform built for home healthcare delivery")
    anims.append({'sp_id': h2s.shape_id, 'delay': 150, 'dur': 600})
    rule(slide)

    # Description
    ds = tb(slide,
        "CareLink connects patients with verified doctors and nurses through an intelligent, "
        "bilingual (Arabic / English) mobile application — featuring AI-driven provider matching, "
        "real-time scheduling, structured medical records, in-app chat, and a governed payment system.",
        Inches(0.8), Inches(2.05), Inches(11.7), Inches(0.85),
        sz=Pt(13.5), color=C_GRAY_600)
    anims.append({'sp_id': ds.shape_id, 'delay': 300, 'dur': 600})

    # ── 3 role cards ──
    roles = [
        ("P", "Patient", C_TEAL, C_GHOST,
         ["Browse & book care providers","AI-matched recommendations",
          "Real-time chat with care team","View structured medical records"]),
        ("D", "Doctor", C_CYAN, RGBColor(0xEC,0xFE,0xFF),
         ["Accept / complete requests","Manage schedule & availability",
          "Submit clinical & diagnosis reports","Rate-approval gate for activation"]),
        ("N", "Nurse", C_GREEN, RGBColor(0xEC,0xFD,0xF5),
         ["Home-visit service requests","Visit tracking & earnings",
          "Medical report forms","Settings & notification prefs"]),
    ]
    cw = Inches(3.9); starts = [Inches(0.55), Inches(4.68), Inches(8.82)]
    for i,(icon,role,col,bgc,bullets) in enumerate(roles):
        lx = starts[i]; ty = Inches(3.05)
        # shadow
        rrect(slide, lx+Inches(0.05), ty+Inches(0.07), cw, Inches(3.9),
              fill=RGBColor(0xD1,0xE8,0xE5))
        c = rrect(slide, lx, ty, cw, Inches(3.9), fill=bgc,
                  line=col, lw=Pt(1.5))
        anims.append({'sp_id': c.shape_id, 'delay': 450+i*130, 'dur': 600})

        # icon circle
        oval(slide, lx+cw/2, ty+Inches(0.62), Inches(0.38), fill=col)
        tb(slide, icon, lx+cw/2-Inches(0.38), ty+Inches(0.27),
           Inches(0.76), Inches(0.72),
           sz=Pt(20), bold=True, color=C_WHITE, align=PP_ALIGN.CENTER)
        # title
        tb(slide, role, lx, ty+Inches(1.15), cw, Inches(0.45),
           sz=Pt(16), bold=True, color=col, align=PP_ALIGN.CENTER)
        # bullets
        for j,b in enumerate(bullets):
            tb(slide, "›  "+b, lx+Inches(0.22), ty+Inches(1.72)+Inches(0.5)*j,
               cw-Inches(0.44), Inches(0.45), sz=Pt(11), color=C_GRAY_600)

    kpi_strip(slide, [("4","User Roles"), ("12","API Route Groups"),
                      ("AR / EN","Bilingual Interface"), ("AI","Smart Matching")])
    add_slide_animations(slide, anims)
    return slide

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 3 — PROBLEM STATEMENT
# ─────────────────────────────────────────────────────────────────────────────
def s03_problem():
    slide = prs.slides.add_slide(BLANK); slide_trans_fade(slide)
    anims = []
    bg_gray(slide); top_bar(slide)

    section_label(slide, "The Challenge")
    h1s = h1(slide, "Three Gaps in Home Healthcare")
    anims.append({'sp_id': h1s.shape_id, 'delay': 0, 'dur': 600})
    rule(slide)

    probs = [
        ("01", "No Unified Platform",
         "Patients lacked a single trusted source to discover, verify, and book qualified home-care doctors and nurses — forcing reliance on informal referrals.",
         C_ROSE, RGBColor(0xFF,0xF1,0xF4)),
        ("02", "Fragmented Scheduling",
         "No real-time availability checking, no conflict detection, no reschedule workflow. Appointments were lost to double-bookings, no-shows, and no audit trail.",
         C_AMBER, RGBColor(0xFF,0xFB,0xEB)),
        ("03", "Opaque Payments & No Governance",
         "No cancellation policy, no provider rate approval gate, no escrow mechanism. Neither patients nor providers had financial protection.",
         C_VIOLET, RGBColor(0xEE,0xEF,0xFF)),
    ]
    cw = Inches(3.85); starts = [Inches(0.5), Inches(4.67), Inches(8.82)]
    for i,(num,title,desc,col,bgc) in enumerate(probs):
        lx = starts[i]; ty = Inches(2.05)
        # shadow
        rrect(slide, lx+Inches(0.06), ty+Inches(0.08), cw, Inches(4.9),
              fill=C_GRAY_200)
        c = rrect(slide, lx, ty, cw, Inches(4.9), fill=bgc,
                  line=col, lw=Pt(2))
        anims.append({'sp_id': c.shape_id, 'delay': 200+i*150, 'dur': 650})

        # number
        tb(slide, num, lx+Inches(0.22), ty+Inches(0.2),
           Inches(1.2), Inches(0.9), sz=Pt(52), bold=True, color=col)
        # color bar right side
        grect(slide, lx+cw-Inches(0.07), ty+Inches(1.2),
              Inches(0.07), Inches(3.5), col,
              RGBColor(min(255,col[0]+60), min(255,col[1]+60), min(255,col[2]+60)),
              angle=90)
        # title
        tb(slide, title, lx+Inches(0.22), ty+Inches(1.15),
           cw-Inches(0.44), Inches(0.55), sz=Pt(16), bold=True, color=C_NAVY)
        # desc
        tb(slide, desc, lx+Inches(0.22), ty+Inches(1.8),
           cw-Inches(0.44), Inches(2.8), sz=Pt(12), color=C_GRAY_600)

    add_slide_animations(slide, anims)
    return slide

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 4 — OUR SOLUTION
# ─────────────────────────────────────────────────────────────────────────────
def s04_solution():
    slide = prs.slides.add_slide(BLANK); slide_trans_fade(slide)
    anims = []
    bg_white(slide); top_bar(slide)

    section_label(slide, "Our Solution")
    h1s = h1(slide, "CareLink — End-to-End Home Care")
    anims.append({'sp_id': h1s.shape_id, 'delay': 0, 'dur': 600})
    rule(slide)

    # LEFT: before panel
    lp = rrect(slide, Inches(0.5), Inches(2.05), Inches(4.6), Inches(5.1),
               fill=RGBColor(0xFE,0xF2,0xF2), line=C_ROSE, lw=Pt(1.5))
    anims.append({'sp_id': lp.shape_id, 'delay': 200, 'dur': 600})
    tb(slide, "Before CareLink", Inches(0.75), Inches(2.22), Inches(4.1), Inches(0.45),
       sz=Pt(15), bold=True, color=C_ROSE)
    befores = [
        "No verified provider directory",
        "Manual scheduling, no conflict detection",
        "No payment protection or policy",
        "No medical record continuity",
        "No intelligent matching or AI",
    ]
    for i,b in enumerate(befores):
        tb(slide, "✗   "+b, Inches(0.75), Inches(2.85)+Inches(0.78)*i,
           Inches(4.1), Inches(0.65), sz=Pt(12), color=C_GRAY_600)

    # Center arrow + label
    arrow_right(slide, Inches(5.25), Inches(4.6), Inches(6.05), color=C_TEAL, lw=Pt(2.5))
    tb(slide, "CareLink", Inches(5.05), Inches(4.7), Inches(1.2), Inches(0.35),
       sz=Pt(9), bold=True, color=C_TEAL, align=PP_ALIGN.CENTER)

    # RIGHT: solution panel
    rp = rrect(slide, Inches(6.2), Inches(2.05), Inches(6.7), Inches(5.1),
               fill=C_GHOST, line=C_TEAL_L, lw=Pt(1.8))
    anims.append({'sp_id': rp.shape_id, 'delay': 400, 'dur': 600})
    tb(slide, "With CareLink", Inches(6.45), Inches(2.22), Inches(6.2), Inches(0.45),
       sz=Pt(15), bold=True, color=C_TEAL)

    pillars = [
        ("S","5-Step Intelligent Booking", "Select provider → Schedule → Location → Review → Pay"),
        ("A","Explainable AI Matching",    "Medical tags + GPS + rating + experience scoring"),
        ("P","Governed Payment System",    "Simulated escrow · 100% / 80% refund policy"),
        ("R","Structured Medical Records", "Disease / allergy DBs with clinical notes"),
        ("N","Bilingual Real-Time Chat",   "AR/EN · file & voice attachments · read receipts"),
    ]
    colors_p = [C_TEAL, C_CYAN, C_GREEN, C_AMBER, C_VIOLET]
    for i,(ic,title,sub) in enumerate(pillars):
        ty = Inches(2.82)+Inches(0.83)*i
        oval(slide, Inches(6.72), ty+Inches(0.2), Inches(0.2), fill=colors_p[i])
        tb(slide, title, Inches(7.1), ty, Inches(5.6), Inches(0.42),
           sz=Pt(13), bold=True, color=C_NAVY)
        tb(slide, sub, Inches(7.4), ty+Inches(0.4), Inches(5.3), Inches(0.38),
           sz=Pt(10.5), color=C_GRAY_600)

    add_slide_animations(slide, anims)
    return slide

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 5 — KEY FEATURES
# ─────────────────────────────────────────────────────────────────────────────
def s05_features():
    slide = prs.slides.add_slide(BLANK); slide_trans_fade(slide)
    anims = []
    bg_gray(slide); top_bar(slide)

    section_label(slide, "What We Built")
    h1s = h1(slide, "Key Features")
    anims.append({'sp_id': h1s.shape_id, 'delay': 0, 'dur': 600})
    rule(slide)

    features = [
        ("S", "5-Step Booking Flow",
         "Provider search → Date & time slot selection → Visit location (GPS) → Summary review → Mock-card payment",
         C_TEAL),
        ("C", "Real-Time In-App Chat",
         "Full messaging with image, PDF, and voice note attachments. Read receipts, typing indicators, conversation threads.",
         C_CYAN),
        ("M", "Structured Medical Records",
         "ICD-coded disease and allergy databases with status tracking. Doctor notes, nurse notes, blood type, lab results.",
         C_GREEN),
        ("G", "Cancellation & Refund Governance",
         "100% refund before provider acceptance. 80% refund after acceptance. 10% provider + 10% platform fee retained.",
         C_AMBER),
        ("W", "Provider Wallet & Escrow",
         "Per-provider wallet with pending/paid balance. Admin commission split. Transaction ledger per booking.",
         C_VIOLET),
        ("R", "Rate Approval Gate",
         "Admin sets provider rate → Doctor reviews & accepts or rejects → Account activates only after mutual approval.",
         C_ROSE),
    ]

    cw = Inches(4.0); ch = Inches(2.25)
    col_x = [Inches(0.5), Inches(4.7), Inches(8.9)]
    row_y = [Inches(2.0), Inches(4.45)]

    for i,(ic,title,desc,col) in enumerate(features):
        row,coli = divmod(i,3)
        lx = col_x[coli]; ty = row_y[row]
        # shadow
        rrect(slide, lx+Inches(0.05), ty+Inches(0.07), cw, ch, fill=C_GRAY_200)
        c = rrect(slide, lx, ty, cw, ch, fill=C_WHITE, line=col, lw=Pt(1.5))
        anims.append({'sp_id': c.shape_id, 'delay': 200+i*90, 'dur': 550})

        # Left color stripe
        grect(slide, lx, ty, Inches(0.065), ch, col,
              RGBColor(min(255,col[0]+40),min(255,col[1]+40),min(255,col[2]+40)), 90)
        # Icon circle
        oval(slide, lx+Inches(0.48), ty+Inches(0.46), Inches(0.3), fill=col)
        tb(slide, ic, lx+Inches(0.18), ty+Inches(0.16),
           Inches(0.6), Inches(0.6), sz=Pt(16), bold=True, color=C_WHITE,
           align=PP_ALIGN.CENTER)
        # Title
        tb(slide, title, lx+Inches(0.9), ty+Inches(0.1),
           cw-Inches(1.1), Inches(0.42), sz=Pt(13), bold=True, color=C_NAVY)
        # Desc
        tb(slide, desc, lx+Inches(0.12), ty+Inches(0.7),
           cw-Inches(0.25), Inches(1.45), sz=Pt(10.5), color=C_GRAY_600)

    add_slide_animations(slide, anims)
    return slide

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 6 — AI RECOMMENDATION ENGINE
# ─────────────────────────────────────────────────────────────────────────────
def s06_ai():
    slide = prs.slides.add_slide(BLANK); slide_trans_fade(slide)
    anims = []
    bg_white(slide); top_bar(slide)

    section_label(slide, "Intelligence Layer")
    h1s = h1(slide, "AI Recommendation Engine")
    anims.append({'sp_id': h1s.shape_id, 'delay': 0, 'dur': 600})
    h2s = h2(slide, "Explainable hybrid scoring — no cloud ML required · Cold-start safe")
    anims.append({'sp_id': h2s.shape_id, 'delay': 120, 'dur': 600})
    rule(slide)

    # ── Central AI circle ──
    eng_cx = W/2; eng_cy = Inches(4.3)
    R_outer = Inches(1.3); R_inner = Inches(1.0)
    # Glow rings
    for r,a in [(Inches(2.0),0.06),(Inches(1.65),0.09),(Inches(1.45),0.12)]:
        v = int(255*(1-a)); col = RGBColor(int(C_TEAL[0]*a+255*(1-a)),
                                           int(C_TEAL[1]*a+255*(1-a)),
                                           int(C_TEAL[2]*a+255*(1-a)))
        oval(slide, eng_cx, eng_cy, r, fill=col)
    # Main engine circle
    s_eng = slide.shapes.add_shape(9,
        eng_cx-R_inner, eng_cy-R_inner, R_inner*2, R_inner*2)
    _grad_fill(s_eng, C_TEAL, C_CYAN, 135)
    s_eng.line.fill.background()
    anims.append({'sp_id': s_eng.shape_id, 'delay': 300, 'dur': 700})
    tb(slide, "AI", eng_cx-R_inner, eng_cy-Inches(0.35),
       R_inner*2, Inches(0.45), sz=Pt(22), bold=True, color=C_WHITE,
       align=PP_ALIGN.CENTER)
    tb(slide, "Engine", eng_cx-R_inner, eng_cy+Inches(0.05),
       R_inner*2, Inches(0.35), sz=Pt(12), color=C_WHITE, align=PP_ALIGN.CENTER)

    # ── Left inputs ──
    inputs = [
        ("P", "Patient Profile",       "Chronic diseases · allergies · medications",  C_TEAL,   Inches(3.6)),
        ("M", "Medical File Tags",     "OCR text + AI analysis · analysisTags DB",     C_CYAN,   Inches(4.7)),
        ("S", "Search Query",          "Free-text or voice-to-text care intent",        C_VIOLET, Inches(5.8)),
        ("G", "GPS Location",          "Patient coordinates (Haversine distance)",      C_GREEN,  Inches(6.9)),
    ]
    iw = Inches(3.4)
    for ic,title,sub,col,ty in inputs:
        lx = Inches(0.4)
        # card
        c = rrect(slide, lx, ty, iw, Inches(0.82),
                  fill=RGBColor(min(255,int(col[0]*0.08+230)), min(255,int(col[1]*0.08+230)), min(255,int(col[2]*0.08+230))),
                  line=col, lw=Pt(1.2))
        anims.append({'sp_id': c.shape_id, 'delay': 450, 'dur': 500})
        oval(slide, lx+Inches(0.28), ty+Inches(0.41), Inches(0.22), fill=col)
        tb(slide, ic, lx+Inches(0.06), ty+Inches(0.13),
           Inches(0.44), Inches(0.44), sz=Pt(13), bold=True, color=C_WHITE,
           align=PP_ALIGN.CENTER)
        tb(slide, title, lx+Inches(0.58), ty+Inches(0.06),
           iw-Inches(0.75), Inches(0.38), sz=Pt(12), bold=True, color=C_NAVY)
        tb(slide, sub, lx+Inches(0.58), ty+Inches(0.42),
           iw-Inches(0.75), Inches(0.35), sz=Pt(9.5), color=C_GRAY_600)
        # connector to engine
        cy_card = ty+Inches(0.41)
        line_shape(slide, lx+iw, cy_card, eng_cx-R_inner, cy_card,
                   color=RGBColor(0xC7,0xE8,0xE5), width=Pt(1.3))
        # dot on card
        oval(slide, lx+iw+Inches(0.04), cy_card, Inches(0.06), fill=col)

    # ── Right outputs / scoring ──
    scores = [
        ("Specialization Match", "Keyword + ICD tag matching",   C_TEAL,   Inches(3.6)),
        ("Experience Score",     "0.4 (junior) → 1.0 (10+ yr)", C_CYAN,   Inches(4.6)),
        ("Rating Score",         "Normalized · 3/5 cold-start",  C_AMBER,  Inches(5.6)),
        ("Location Score",       "Haversine · ≤1 km = perfect",  C_GREEN,  Inches(6.6)),
        ("Medical Compatibility","analysisTags vs specialization",C_VIOLET, Inches(7.2)),
    ]
    ow = Inches(3.6)
    out_l = eng_cx + R_inner + Inches(0.5)
    for label,detail,col,ty in scores:
        c = rrect(slide, out_l, ty, ow, Inches(0.72),
                  fill=RGBColor(min(255,int(col[0]*0.05+235)),min(255,int(col[1]*0.05+235)),min(255,int(col[2]*0.05+235))),
                  line=col, lw=Pt(1.2))
        anims.append({'sp_id': c.shape_id, 'delay': 600, 'dur': 500})
        oval(slide, out_l+Inches(0.22), ty+Inches(0.36), Inches(0.15), fill=col)
        tb(slide, label, out_l+Inches(0.48), ty+Inches(0.04),
           ow-Inches(0.65), Inches(0.36), sz=Pt(12), bold=True, color=C_NAVY)
        tb(slide, detail, out_l+Inches(0.48), ty+Inches(0.38),
           ow-Inches(0.65), Inches(0.3), sz=Pt(9.5), color=C_GRAY_600)
        # connector from engine
        cy_out = ty+Inches(0.36)
        line_shape(slide, eng_cx+R_inner, cy_out, out_l,
                   cy_out, color=RGBColor(0xC7,0xE8,0xE5), width=Pt(1.3))
        oval(slide, out_l-Inches(0.04), cy_out, Inches(0.06), fill=col)

    # Output label
    tb(slide, "Ranked Providers + Match Reason + Score Breakdown",
       out_l, Inches(7.95), ow, Inches(0.38),
       sz=Pt(9.5), color=C_TEAL, bold=True)

    # Bottom note strip
    ns = rrect(slide, Inches(0.5), Inches(7.1), Inches(12.3), Inches(0.3),
               fill=C_GHOST, adj=50000)
    tb(slide, "Cold-start: historyWeight = 0 until visit signals exist.  "
       "Voice search via speech_to_text → rawQuery → requestedServiceKeyword → scoring engine.",
       Inches(0.65), Inches(7.13), Inches(12.0), Inches(0.25),
       sz=Pt(9), color=C_TEAL, align=PP_ALIGN.CENTER)

    add_slide_animations(slide, anims)
    return slide

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 7 — SYSTEM ARCHITECTURE
# ─────────────────────────────────────────────────────────────────────────────
def s07_arch():
    slide = prs.slides.add_slide(BLANK); slide_trans_fade(slide)
    anims = []

    # Dark premium background
    bg_navy(slide)
    grect(slide, 0, 0, W, Inches(0.055), C_TEAL_L, C_CYAN)

    # Title on dark bg
    section_label(slide, "How It's Built")
    for s in [slide.shapes[-1]]:
        s.text_frame.paragraphs[0].runs[0].font.color.rgb = C_TEAL_L
    h1s = h1(slide, "System Architecture", color=C_WHITE)
    anims.append({'sp_id': h1s.shape_id, 'delay': 0, 'dur': 600})
    hs = h2(slide, "Flutter  →  Express REST API  →  Backend Services  →  MySQL Database",
            color=C_GRAY_400)
    anims.append({'sp_id': hs.shape_id, 'delay': 150, 'dur': 600})
    grect(slide, Inches(0.8), Inches(1.9), Inches(1.2), Inches(0.04),
          C_TEAL_L, C_CYAN)

    # ── TIER 1: Clients ──
    t1y = Inches(2.15)
    client_data = [
        ("P", "Patient App",   C_TEAL_L),
        ("D", "Doctor App",    C_CYAN),
        ("N", "Nurse App",     C_GREEN),
        ("A", "Admin Panel",   C_AMBER),
    ]
    cw_cl = Inches(2.5)
    cx_starts = [Inches(2.5), Inches(5.2), Inches(7.9), Inches(10.6)]
    # Tier label
    tb(slide, "CLIENTS", Inches(0.5), t1y+Inches(0.2),
       Inches(1.8), Inches(0.36), sz=Pt(9), bold=True, color=C_GRAY_400)
    for i,(ic,lbl,col) in enumerate(client_data):
        lx = cx_starts[i]
        c = rrect(slide, lx, t1y, cw_cl, Inches(0.75),
                  fill=RGBColor(0x0C,0x25,0x38), line=col, lw=Pt(1.5))
        anims.append({'sp_id': c.shape_id, 'delay': 250+i*80, 'dur': 500})
        oval(slide, lx+Inches(0.35), t1y+Inches(0.375), Inches(0.25), fill=col)
        tb(slide, lbl, lx+Inches(0.7), t1y+Inches(0.18),
           Inches(1.7), Inches(0.4), sz=Pt(12), bold=True, color=col)

    # Arrow tier1 → tier2
    arr_cx = W/2
    arrow_down(slide, arr_cx, t1y+Inches(0.75), t1y+Inches(1.35),
               color=C_TEAL_L, lw=Pt(1.8))
    tb(slide, "REST API  (JSON over HTTP, port 3000)",
       arr_cx-Inches(2.2), t1y+Inches(0.78), Inches(4.4), Inches(0.28),
       sz=Pt(9.5), color=C_TEAL_L, align=PP_ALIGN.CENTER)

    # ── TIER 2: API Layer ──
    t2y = t1y + Inches(1.35)
    t2h = Inches(2.1)
    api_bg = rrect(slide, Inches(0.5), t2y, Inches(12.3), t2h,
                   fill=RGBColor(0x0C,0x20,0x30), line=C_TEAL, lw=Pt(1.3))
    anims.append({'sp_id': api_bg.shape_id, 'delay': 500, 'dur': 600})
    tb(slide, "API", Inches(0.55), t2y+Inches(0.05),
       Inches(1.8), Inches(0.35), sz=Pt(9), bold=True, color=C_GRAY_400)

    # Route chips
    routes = ["/patient","/doctor","/nurse","/admin","/providers","/payments",
              "/api/payments","/recommendations","/medical-records","/notifications","/ratings","/email-auth"]
    rw = Inches(1.7); rh = Inches(0.31)
    rcols = 6
    rc = [C_TEAL,C_CYAN,C_GREEN,C_AMBER,C_VIOLET,C_ROSE]
    for i,r in enumerate(routes):
        row_r,col_r = divmod(i,rcols)
        px = Inches(2.1)+(rw+Inches(0.16))*col_r
        py = t2y+Inches(0.15)+(rh+Inches(0.16))*row_r
        col_c = rc[col_r%len(rc)]
        bg_r = RGBColor(int(col_c[0]*0.12+10),int(col_c[1]*0.12+10),int(col_c[2]*0.12+10))
        c = rrect(slide, px, py, rw, rh, fill=bg_r, line=col_c, lw=Pt(0.8), adj=50000)
        tb(slide, r, px, py+Inches(0.04), rw, rh-Inches(0.04),
           sz=Pt(8.5), bold=True, color=col_c, align=PP_ALIGN.CENTER)

    # Service layer inside tier2
    svcs = ["bookingPayment","cancellationPolicy","aiRecommendation","emailOTP","notifications"]
    sw2 = Inches(2.1); sy2 = t2y+t2h-Inches(0.42)
    sx_start = (W-(sw2+Inches(0.12))*len(svcs)-Inches(0.12))/2
    for i,svc in enumerate(svcs):
        sx = sx_start+(sw2+Inches(0.12))*i
        c = rrect(slide, sx, sy2, sw2, Inches(0.32),
                  fill=RGBColor(0x06,0x18,0x24), line=C_TEAL_L, lw=Pt(0.7), adj=50000)
        tb(slide, svc, sx, sy2+Inches(0.05), sw2, Inches(0.25),
           sz=Pt(8), bold=True, color=C_TEAL_L, align=PP_ALIGN.CENTER)

    # Arrow tier2 → tier3
    arrow_down(slide, arr_cx, t2y+t2h, t2y+t2h+Inches(0.45),
               color=C_TEAL_L, lw=Pt(1.8))
    tb(slide, "mysql2 (connection pool, utf8mb4, 10 connections)",
       arr_cx-Inches(2.5), t2y+t2h+Inches(0.04), Inches(5.0), Inches(0.28),
       sz=Pt(9.5), color=C_TEAL_L, align=PP_ALIGN.CENTER)

    # ── TIER 3: Database ──
    t3y = t2y+t2h+Inches(0.45); t3h = Inches(0.9)
    db_bg = rrect(slide, Inches(0.5), t3y, Inches(12.3), t3h,
                  fill=RGBColor(0x06,0x18,0x24), line=C_CYAN, lw=Pt(1.3))
    anims.append({'sp_id': db_bg.shape_id, 'delay': 700, 'dur': 600})
    tb(slide, "DB", Inches(0.55), t3y+Inches(0.08),
       Inches(1.5), Inches(0.35), sz=Pt(9), bold=True, color=C_GRAY_400)

    tables = ["user","patient","careprovider","servicerequest",
              "payment","medicalrecord","availabilityslot","message",
              "providervisitrating","provider_rates","provider_wallet","admin_wallet"]
    tw2 = Inches(0.9); th2 = Inches(0.26)
    for i,tbl in enumerate(tables):
        col_t = i%6; row_t = i//6
        tx = Inches(2.1)+(tw2+Inches(0.2))*col_t
        ty2 = t3y+Inches(0.07)+(th2+Inches(0.3))*row_t
        col_tb = rc[col_t%len(rc)]
        c = rrect(slide, tx, ty2, tw2, th2,
                  fill=RGBColor(0x0A,0x22,0x30), line=col_tb, lw=Pt(0.7), adj=50000)
        tb(slide, tbl, tx, ty2+Inches(0.04), tw2, th2-Inches(0.04),
           sz=Pt(7), bold=True, color=col_tb, align=PP_ALIGN.CENTER)

    add_slide_animations(slide, anims)
    return slide

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 8 — LIVE DEMO (TRANSITION)
# ─────────────────────────────────────────────────────────────────────────────
def s08_demo():
    slide = prs.slides.add_slide(BLANK); slide_trans_fade(slide)
    anims = []

    # Full-bleed teal gradient
    grect(slide, 0, 0, W, H, C_NAVY, C_TEAL, 145)

    # Decorative rings
    for r in [Inches(3.8), Inches(3.0), Inches(2.3)]:
        oval_ring(slide, W/2, H/2, r,
                  color=RGBColor(0xFF,0xFF,0xFF), lw=Pt(0.5 if r>Inches(3.4) else 0.8))

    # ── Phone silhouette ──
    ph_w, ph_h = Inches(2.0), Inches(3.8)
    ph_l, ph_t = W/2 - ph_w/2, H/2 - ph_h/2 - Inches(0.2)
    # Shadow
    shadow_shape = rrect(slide, ph_l+Inches(0.14), ph_t+Inches(0.18), ph_w, ph_h,
                         fill=RGBColor(0x03,0x40,0x3C), adj=25000)
    # Phone body
    phone = rrect(slide, ph_l, ph_t, ph_w, ph_h,
                  fill=RGBColor(0x08,0x55,0x50), adj=25000)
    phone.line.color.rgb = RGBColor(0xA7,0xF3,0xD0); phone.line.width = Pt(1.8)
    anims.append({'sp_id': phone.shape_id, 'delay': 200, 'dur': 700})
    # Screen
    rrect(slide, ph_l+Inches(0.13), ph_t+Inches(0.27),
          ph_w-Inches(0.26), ph_h-Inches(0.52),
          fill=RGBColor(0xEC,0xFD,0xF9), adj=18000)
    # Camera notch
    oval(slide, W/2, ph_t+Inches(0.14), Inches(0.07),
         fill=RGBColor(0x06,0x45,0x42))
    # Home indicator
    rrect(slide, W/2-Inches(0.35), ph_t+ph_h-Inches(0.18),
          Inches(0.7), Inches(0.07),
          fill=RGBColor(0xA7,0xF3,0xD0), adj=50000)

    # Screen content (mockup)
    tb(slide, "CareLink", W/2-Inches(0.8), ph_t+Inches(0.5),
       Inches(1.6), Inches(0.35), sz=Pt(10), bold=True, color=C_TEAL,
       align=PP_ALIGN.CENTER)
    for i,bar in enumerate(["####  ######", "###  #####", "####  ####"]):
        rrect(slide, W/2-Inches(0.7), ph_t+Inches(0.95)+Inches(0.38)*i,
              Inches(1.4), Inches(0.22),
              fill=RGBColor(0xCC,0xF5,0xF1), adj=50000)

    # LIVE DEMO title
    s = tb(slide, "LIVE DEMO",
           Inches(0.5), Inches(0.7), W-Inches(1), Inches(1.5),
           sz=Pt(72), bold=True, color=C_WHITE, align=PP_ALIGN.CENTER)
    anims.append({'sp_id': s.shape_id, 'delay': 0, 'dur': 700})

    # Subtitle
    s2 = tb(slide, "See CareLink in action",
            Inches(0.5), Inches(2.1), W-Inches(1), Inches(0.6),
            sz=Pt(24), color=C_MINT, align=PP_ALIGN.CENTER)
    anims.append({'sp_id': s2.shape_id, 'delay': 300, 'dur': 600})

    # Bottom demo flow
    chips = ["Booking Flow", "AI Matching", "Payment", "Doctor Accepts", "Chat"]
    total_cw = Inches(2.0)*len(chips)+Inches(0.25)*(len(chips)-1)
    sx = (W-total_cw)/2
    for i,chip_text in enumerate(chips):
        cx2 = sx+Inches(2.25)*i
        c = rrect(slide, cx2, Inches(6.45), Inches(2.0), Inches(0.42),
                  fill=RGBColor(0x06,0x3F,0x3B), adj=50000)
        c.line.color.rgb = C_MINT; c.line.width = Pt(0.9)
        tb(slide, chip_text, cx2, Inches(6.5), Inches(2.0), Inches(0.35),
           sz=Pt(11), bold=True, color=C_MINT, align=PP_ALIGN.CENTER)
        anims.append({'sp_id': c.shape_id, 'delay': 500+i*80, 'dur': 450})
        if i < len(chips)-1:
            line_shape(slide, cx2+Inches(2.0), Inches(6.66),
                       cx2+Inches(2.25), Inches(6.66),
                       color=C_MINT, width=Pt(1.2))

    add_slide_animations(slide, anims)
    return slide

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 9 — TECHNOLOGIES
# ─────────────────────────────────────────────────────────────────────────────
def s09_tech():
    slide = prs.slides.add_slide(BLANK); slide_trans_fade(slide)
    anims = []
    bg_white(slide); top_bar(slide)

    section_label(slide, "The Stack")
    h1s = h1(slide, "Technologies Used")
    anims.append({'sp_id': h1s.shape_id, 'delay': 0, 'dur': 600})
    rule(slide)

    col_data = [
        ("F", "Frontend  —  Flutter / Dart", C_TEAL, [
            ("Flutter 3 + Dart",          "Cross-platform: Android, iOS, Web, Desktop",    C_TEAL),
            ("speech_to_text",            "Voice search input for AI recommendation flow", C_CYAN),
            ("geolocator + flutter_map",  "GPS acquisition + Haversine proximity",          C_GREEN),
            ("table_calendar",            "Provider availability slot selection UI",        C_AMBER),
            ("http  +  shared_preferences","REST calls, session token storage",             C_VIOLET),
            ("pdf  +  printing",          "Prescription & report PDF generation",           C_ROSE),
        ]),
        ("B", "Backend  —  Node.js / Express", C_CYAN, [
            ("Express.js",               "12 route groups · REST API · port 3000",          C_TEAL),
            ("MySQL2  +  pool",          "utf8mb4 charset · schema-adaptive migrations",    C_CYAN),
            ("bcrypt  +  OTP",           "Password hashing · Phone (Twilio) + Email OTP",  C_GREEN),
            ("multer",                   "Image, PDF, voice uploads up to 25 MB",          C_AMBER),
            ("nodemailer",               "SMTP email verification codes",                   C_VIOLET),
            ("crypto (randomUUID)",      "Booking, payment, session UUID generation",       C_ROSE),
        ]),
    ]

    col_w2 = Inches(5.9)
    col_starts2 = [Inches(0.55), Inches(6.88)]
    for ci,(hic,htitle,hcol,items) in enumerate(col_data):
        lx = col_starts2[ci]
        # Column header
        ch = grect(slide, lx, Inches(2.05), col_w2, Inches(0.58),
                   hcol, C_CYAN if ci==0 else C_VIOLET, 135, radius=True)
        anims.append({'sp_id': ch.shape_id, 'delay': 150+ci*120, 'dur': 550})
        oval(slide, lx+Inches(0.32), Inches(2.34), Inches(0.22), fill=C_WHITE)
        tb(slide, hic, lx+Inches(0.1), Inches(2.1),
           Inches(0.44), Inches(0.44), sz=Pt(13), bold=True, color=hcol,
           align=PP_ALIGN.CENTER)
        tb(slide, htitle, lx+Inches(0.65), Inches(2.14),
           col_w2-Inches(0.85), Inches(0.42), sz=Pt(13.5), bold=True, color=C_WHITE)

        for ti,(name,detail,col) in enumerate(items):
            ty = Inches(2.78)+Inches(0.77)*ti
            c = rrect(slide, lx, ty, col_w2, Inches(0.66),
                      fill=C_GRAY_50, line=col, lw=Pt(1.2))
            anims.append({'sp_id': c.shape_id, 'delay': 300+ci*120+ti*70, 'dur': 500})
            oval(slide, lx+Inches(0.22), ty+Inches(0.33), Inches(0.14), fill=col)
            tb(slide, name, lx+Inches(0.45), ty+Inches(0.04),
               col_w2-Inches(0.6), Inches(0.34), sz=Pt(12.5), bold=True, color=C_NAVY)
            tb(slide, detail, lx+Inches(0.45), ty+Inches(0.36),
               col_w2-Inches(0.6), Inches(0.28), sz=Pt(10), color=C_GRAY_600)

    add_slide_animations(slide, anims)
    return slide

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 10 — FUTURE WORK
# ─────────────────────────────────────────────────────────────────────────────
def s10_future():
    slide = prs.slides.add_slide(BLANK); slide_trans_fade(slide)
    anims = []
    bg_gray(slide); top_bar(slide)

    section_label(slide, "What's Next")
    h1s = h1(slide, "Future Roadmap")
    anims.append({'sp_id': h1s.shape_id, 'delay': 0, 'dur': 600})
    rule(slide)

    # Timeline line
    line_y = Inches(3.5)
    grect(slide, Inches(0.7), line_y-Inches(0.025), Inches(11.8), Inches(0.05),
          C_TEAL_L, C_CYAN)

    phases = [
        ("1", "Phase 1", "Production-Ready", C_TEAL, Inches(1.5), [
            "Real payment gateway (Stripe / HyperPay)",
            "Firebase Cloud Messaging push notifications",
            "JWT authentication (replace userId-as-token)",
            "Rate limiting and input validation middleware",
        ]),
        ("2", "Phase 2", "Enhanced Clinical", C_CYAN, Inches(5.15), [
            "Video consultation module",
            "In-app prescription PDF generation",
            "Lab result upload with OCR parsing",
            "Doctor-to-doctor referral workflow",
        ]),
        ("3", "Phase 3", "AI & Wearables", C_VIOLET, Inches(8.8), [
            "ML-trained recommendation model",
            "Wearable device (heart rate, glucose) integration",
            "Predictive scheduling from visit history",
            "Multi-language NLP symptom parsing",
        ]),
    ]

    for num,phase,subtitle,col,px,items in phases:
        # Above-line badge
        badge = rrect(slide, px-Inches(0.2), line_y-Inches(1.15),
                      Inches(1.55), Inches(0.88), fill=C_WHITE,
                      line=col, lw=Pt(1.5), adj=20000)
        anims.append({'sp_id': badge.shape_id, 'delay': 300, 'dur': 600})
        tb(slide, phase, px-Inches(0.2), line_y-Inches(1.1),
           Inches(1.55), Inches(0.38), sz=Pt(12), bold=True, color=col,
           align=PP_ALIGN.CENTER)
        tb(slide, subtitle, px-Inches(0.2), line_y-Inches(0.74),
           Inches(1.55), Inches(0.32), sz=Pt(9.5), color=C_GRAY_600,
           align=PP_ALIGN.CENTER)

        # Node circle on line
        oval(slide, px+Inches(0.575), line_y, Inches(0.22), fill=col)
        oval_ring(slide, px+Inches(0.575), line_y, Inches(0.36), color=col, lw=Pt(1.5))

        # Below-line card
        card_l = px - Inches(0.25); card_t = line_y + Inches(0.45)
        card_w3 = Inches(3.75); card_h3 = Inches(2.65)
        rrect(slide, card_l+Inches(0.06), card_t+Inches(0.07), card_w3, card_h3,
              fill=C_GRAY_200)
        c = rrect(slide, card_l, card_t, card_w3, card_h3,
                  fill=C_WHITE, line=col, lw=Pt(1.5))
        anims.append({'sp_id': c.shape_id, 'delay': 450, 'dur': 600})
        grect(slide, card_l, card_t, card_w3, Inches(0.065), col,
              RGBColor(min(255,col[0]+40),min(255,col[1]+40),min(255,col[2]+40)))
        for i,item in enumerate(items):
            oval(slide, card_l+Inches(0.22), card_t+Inches(0.3)+Inches(0.58)*i+Inches(0.12),
                 Inches(0.08), fill=col)
            tb(slide, item,
               card_l+Inches(0.42), card_t+Inches(0.18)+Inches(0.58)*i,
               card_w3-Inches(0.55), Inches(0.5), sz=Pt(11), color=C_GRAY_600)

    add_slide_animations(slide, anims)
    return slide

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 11 — CONCLUSION
# ─────────────────────────────────────────────────────────────────────────────
def s11_conclusion():
    slide = prs.slides.add_slide(BLANK); slide_trans_fade(slide)
    anims = []
    bg_white(slide); top_bar(slide)

    section_label(slide, "Wrap-Up")
    h1s = h1(slide, "What CareLink Delivers")
    anims.append({'sp_id': h1s.shape_id, 'delay': 0, 'dur': 600})
    rule(slide)

    achievements = [
        ("1", "Full-Stack Mobile Platform",
         "Flutter + Node.js + MySQL serving four distinct user roles — Patient, Doctor, Nurse, and Admin — each with dedicated dashboards, governed workflows, and access-controlled APIs.",
         C_TEAL),
        ("2", "Explainable AI Matching",
         "Hybrid content-based scoring engine that ingests OCR-extracted medical file tags, GPS distance, specialization keywords, and visit ratings to rank providers with human-readable match reasons.",
         C_CYAN),
        ("3", "Governance & Finance Layer",
         "Admin rate approval gate, simulated escrow payment system, 100% / 80% cancellation refund policy, provider wallet, admin commission split — all enforced server-side.",
         C_GREEN),
    ]

    cw4 = Inches(3.85); ch4 = Inches(4.0)
    starts4 = [Inches(0.5), Inches(4.65), Inches(8.8)]
    for i,(num,title,desc,col) in enumerate(achievements):
        lx = starts4[i]; ty = Inches(2.1)
        # shadow
        rrect(slide, lx+Inches(0.06), ty+Inches(0.08), cw4, ch4, fill=C_GRAY_200)
        c = rrect(slide, lx, ty, cw4, ch4, fill=C_WHITE, line=col, lw=Pt(2))
        anims.append({'sp_id': c.shape_id, 'delay': 200+i*150, 'dur': 650})

        # Top gradient band
        grect(slide, lx, ty, cw4, Inches(0.7), col,
              RGBColor(min(255,col[0]+50),min(255,col[1]+50),min(255,col[2]+30)))
        # Number in circle
        oval(slide, lx+Inches(0.45), ty+Inches(0.35), Inches(0.3), fill=C_WHITE)
        tb(slide, num, lx+Inches(0.15), ty+Inches(0.09),
           Inches(0.6), Inches(0.56), sz=Pt(20), bold=True, color=col,
           align=PP_ALIGN.CENTER)
        # Title
        tb(slide, title, lx+Inches(0.18), ty+Inches(0.85),
           cw4-Inches(0.36), Inches(0.52), sz=Pt(14.5), bold=True, color=C_NAVY)
        # Desc
        tb(slide, desc, lx+Inches(0.18), ty+Inches(1.5),
           cw4-Inches(0.36), Inches(2.38), sz=Pt(11.5), color=C_GRAY_600)

    # Closing banner
    s_ban = grect(slide, Inches(0.5), Inches(6.28), Inches(12.3), Inches(0.87),
                  C_GHOST, C_CYAN_PALE, radius=True)
    anims.append({'sp_id': s_ban.shape_id, 'delay': 700, 'dur': 600})
    tb(slide,
       "CareLink demonstrates that a focused engineering team can design, build, and govern "
       "a complete digital healthcare ecosystem — from first symptom to completed home visit.",
       Inches(0.85), Inches(6.4), Inches(11.6), Inches(0.65),
       sz=Pt(13), color=C_TEAL, align=PP_ALIGN.CENTER, bold=True)

    add_slide_animations(slide, anims)
    return slide

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 12 — THANK YOU
# ─────────────────────────────────────────────────────────────────────────────
def s12_thanks():
    slide = prs.slides.add_slide(BLANK); slide_trans_fade(slide)
    anims = []

    # Background
    grect(slide, 0, 0, W, H, C_NAVY, RGBColor(0x08,0x50,0x4C), 145)

    # Decorative circles
    deco_blob(slide, W-Inches(1.5), Inches(1.5), Inches(2.5), Inches(2.5), C_TEAL)
    deco_blob(slide, Inches(0.0),   H-Inches(1), Inches(2.2), Inches(2.2), C_TEAL_L)
    deco_blob(slide, W/2, H-Inches(0.5), Inches(4.0), Inches(1.5), C_CYAN)

    # Thin side stripe
    grect(slide, 0, 0, Inches(0.1), H, C_TEAL_L, C_CYAN, 90)

    # CareLink wordmark
    s_wm = tb(slide, "CareLink", Inches(0.5), Inches(0.55), W-Inches(1), Inches(0.8),
              sz=Pt(32), bold=True, color=C_MINT, align=PP_ALIGN.CENTER)
    anims.append({'sp_id': s_wm.shape_id, 'delay': 0, 'dur': 600})

    # Divider below wordmark
    grect(slide, W/2-Inches(2.0), Inches(1.35), Inches(4.0), Inches(0.04),
          C_TEAL_L, C_CYAN)

    # Thank You
    s_ty = tb(slide, "Thank You",
              Inches(0.5), Inches(1.55), W-Inches(1), Inches(1.6),
              sz=Pt(80), bold=True, color=C_WHITE, align=PP_ALIGN.CENTER)
    anims.append({'sp_id': s_ty.shape_id, 'delay': 150, 'dur': 700})

    # Subtitle
    s_q = tb(slide, "Open for Questions",
             Inches(0.5), Inches(3.15), W-Inches(1), Inches(0.7),
             sz=Pt(26), color=C_MINT, align=PP_ALIGN.CENTER)
    anims.append({'sp_id': s_q.shape_id, 'delay': 400, 'dur': 600})

    # Divider
    grect(slide, W/2-Inches(3.5), Inches(3.9), Inches(7.0), Inches(0.04),
          C_TEAL_L, C_CYAN)

    # Team / uni info
    infos = [
        "Computer Science Department  ·  Graduation Project  ·  2025 – 2026",
        "Supervised by:  [Dr. Supervisor Name]",
        "Team:  [Team Member Names]",
    ]
    for i,inf in enumerate(infos):
        tb(slide, inf, Inches(0.5), Inches(4.1)+Inches(0.42)*i,
           W-Inches(1), Inches(0.38), sz=Pt(12), color=C_GRAY_400,
           align=PP_ALIGN.CENTER)

    # Bottom summary chips
    chips_f = ["Full-Stack Platform", "4 User Roles", "AI Engine", "Governed Payments", "Bilingual"]
    total_c = Inches(2.1)*len(chips_f)+Inches(0.2)*(len(chips_f)-1)
    sx_f = (W-total_c)/2
    for i,ch_text in enumerate(chips_f):
        cx_f = sx_f+Inches(2.3)*i
        c = rrect(slide, cx_f, Inches(5.88), Inches(2.1), Inches(0.4),
                  fill=RGBColor(0x06,0x35,0x32), adj=50000)
        c.line.color.rgb = C_TEAL_L; c.line.width = Pt(0.9)
        tb(slide, ch_text, cx_f, Inches(5.92), Inches(2.1), Inches(0.35),
           sz=Pt(10.5), bold=True, color=C_TEAL_L, align=PP_ALIGN.CENTER)
        anims.append({'sp_id': c.shape_id, 'delay': 650+i*80, 'dur': 450})

    # Medical cross bottom-right
    cross_cx2 = Inches(11.4); cross_cy2 = Inches(6.7)
    oval_ring(slide, cross_cx2, cross_cy2, Inches(0.75), color=C_TEAL_L, lw=Pt(0.8))
    grect(slide, cross_cx2-Inches(0.1), cross_cy2-Inches(0.38),
          Inches(0.2), Inches(0.76), C_TEAL_L, C_CYAN, 90)
    grect(slide, cross_cx2-Inches(0.38), cross_cy2-Inches(0.1),
          Inches(0.76), Inches(0.2), C_TEAL_L, C_CYAN, 0)

    add_slide_animations(slide, anims)
    return slide

# ─────────────────────────────────────────────────────────────────────────────
# BUILD
# ─────────────────────────────────────────────────────────────────────────────
print("Slide  1  Cover ...")
s01_cover()
print("Slide  2  Introduction ...")
s02_intro()
print("Slide  3  Problem Statement ...")
s03_problem()
print("Slide  4  Our Solution ...")
s04_solution()
print("Slide  5  Key Features ...")
s05_features()
print("Slide  6  AI Recommendation Engine ...")
s06_ai()
print("Slide  7  System Architecture ...")
s07_arch()
print("Slide  8  Live Demo ...")
s08_demo()
print("Slide  9  Technologies ...")
s09_tech()
print("Slide 10  Future Work ...")
s10_future()
print("Slide 11  Conclusion ...")
s11_conclusion()
print("Slide 12  Thank You ...")
s12_thanks()

OUT = "D:/carelink-care-link/CareLink_Premium_Presentation.pptx"
prs.save(OUT)
print("Done. Saved to:", OUT)
