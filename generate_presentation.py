"""
CareLink Graduation Defense Presentation Generator
Generates a premium 12-slide PowerPoint presentation.
"""

from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.util import Inches, Pt
from pptx.oxml.ns import qn
from pptx.oxml import parse_xml
from pptx.enum.dml import MSO_THEME_COLOR
import copy
from lxml import etree
import io, math

# ── Palette ────────────────────────────────────────────────────────────────
TEAL        = RGBColor(0x0D, 0x94, 0x88)
TEAL_MED    = RGBColor(0x0F, 0xB2, 0xA3)
TEAL_LIGHT  = RGBColor(0x5E, 0xEA, 0xD4)
TEAL_GHOST  = RGBColor(0xCC, 0xF5, 0xF1)
CYAN        = RGBColor(0x06, 0xB6, 0xD4)
CYAN_LIGHT  = RGBColor(0xA5, 0xF3, 0xFC)
DARK_NAVY   = RGBColor(0x0F, 0x17, 0x2A)
DARK_SLATE  = RGBColor(0x1E, 0x29, 0x3B)
SLATE_600   = RGBColor(0x47, 0x55, 0x69)
SLATE_400   = RGBColor(0x94, 0xA3, 0xB8)
SLATE_200   = RGBColor(0xE2, 0xE8, 0xF0)
WHITE       = RGBColor(0xFF, 0xFF, 0xFF)
WARM_AMBER  = RGBColor(0xF5, 0x9E, 0x0B)
SOFT_GREEN  = RGBColor(0x10, 0xB9, 0x81)
LAVENDER    = RGBColor(0x81, 0x8C, 0xF8)
SOFT_ROSE   = RGBColor(0xFB, 0x71, 0x85)

# Slide size: 16:9 widescreen
W = Inches(13.33)
H = Inches(7.5)

prs = Presentation()
prs.slide_width  = W
prs.slide_height = H

BLANK = prs.slide_layouts[6]   # blank layout

# ═══════════════════════════════════════════════════════════════════════════
# LOW-LEVEL HELPERS
# ═══════════════════════════════════════════════════════════════════════════

def rgb_hex(c: RGBColor) -> str:
    return f"{c[0]:02X}{c[1]:02X}{c[2]:02X}"

def add_rect(slide, l, t, w, h, fill=None, line=None, line_w=Pt(1), radius=None):
    shape = slide.shapes.add_shape(
        1,   # MSO_SHAPE_TYPE.RECTANGLE
        l, t, w, h
    )
    shape.line.fill.background()
    if fill:
        shape.fill.solid()
        shape.fill.fore_color.rgb = fill
    else:
        shape.fill.background()
    if line:
        shape.line.color.rgb = line
        shape.line.width = line_w
    else:
        shape.line.fill.background()
    if radius is not None:
        _set_radius(shape, radius)
    return shape

def _set_radius(shape, radius_pt):
    """Apply rounded corners via XML adj."""
    sp = shape._element
    spPr = sp.find(qn('p:spPr'))
    prstGeom = spPr.find(qn('a:prstGeom'))
    if prstGeom is not None:
        spPr.remove(prstGeom)
    # Build custGeom for rounded rectangle using prstGeom with avLst
    xml_str = f"""
    <a:prstGeom xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" prst="roundRect">
      <a:avLst>
        <a:gd name="adj" fmla="val 30000"/>
      </a:avLst>
    </a:prstGeom>"""
    new_geom = etree.fromstring(xml_str)
    spPr.insert(0, new_geom)

def add_textbox(slide, text, l, t, w, h,
                font_size=Pt(12), bold=False, color=WHITE,
                align=PP_ALIGN.LEFT, italic=False, font_name="Calibri"):
    txBox = slide.shapes.add_textbox(l, t, w, h)
    tf = txBox.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.alignment = align
    run = p.add_run()
    run.text = text
    run.font.size = font_size
    run.font.bold = bold
    run.font.color.rgb = color
    run.font.italic = italic
    run.font.name = font_name
    return txBox

def add_multiline_textbox(slide, lines, l, t, w, h,
                          font_size=Pt(11), bold=False, color=WHITE,
                          align=PP_ALIGN.LEFT, line_spacing=1.2, font_name="Calibri"):
    txBox = slide.shapes.add_textbox(l, t, w, h)
    tf = txBox.text_frame
    tf.word_wrap = True
    for i, line in enumerate(lines):
        if i == 0:
            p = tf.paragraphs[0]
        else:
            p = tf.add_paragraph()
        p.alignment = align
        p.space_after = Pt(2)
        run = p.add_run()
        if isinstance(line, tuple):
            run.text = line[0]
            run.font.size = line[1]
            run.font.bold = line[2] if len(line) > 2 else bold
            run.font.color.rgb = line[3] if len(line) > 3 else color
        else:
            run.text = line
            run.font.size = font_size
            run.font.bold = bold
            run.font.color.rgb = color
        run.font.name = font_name
    return txBox

def add_gradient_rect(slide, l, t, w, h, c1: RGBColor, c2: RGBColor, radius=None, angle=135):
    """Add a shape with linear gradient fill."""
    shape = slide.shapes.add_shape(1, l, t, w, h)
    shape.line.fill.background()
    if radius:
        _set_radius(shape, radius)
    spPr = shape._element.find(qn('p:spPr'))
    # Remove old fill
    for old in spPr.findall(qn('a:solidFill')):
        spPr.remove(old)
    for old in spPr.findall(qn('a:gradFill')):
        spPr.remove(old)
    # Angle in 60000ths of a degree
    ang = int(angle * 60000)
    grad_xml = f"""
    <a:gradFill xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
      <a:gsLst>
        <a:gs pos="0">
          <a:srgbClr val="{rgb_hex(c1)}"/>
        </a:gs>
        <a:gs pos="100000">
          <a:srgbClr val="{rgb_hex(c2)}"/>
        </a:gs>
      </a:gsLst>
      <a:lin ang="{ang}" scaled="0"/>
    </a:gradFill>"""
    spPr.insert(0, etree.fromstring(grad_xml))
    shape.fill._xPr  # touch to sync
    return shape

def add_circle(slide, cx, cy, r, fill=None, line=None, line_w=Pt(1.5)):
    shape = slide.shapes.add_shape(
        9,  # oval
        cx - r, cy - r, r * 2, r * 2
    )
    if fill:
        shape.fill.solid()
        shape.fill.fore_color.rgb = fill
    else:
        shape.fill.background()
    if line:
        shape.line.color.rgb = line
        shape.line.width = line_w
    else:
        shape.line.fill.background()
    return shape

def add_line(slide, x1, y1, x2, y2, color=TEAL, width=Pt(2)):
    connector = slide.shapes.add_connector(1, x1, y1, x2, y2)
    connector.line.color.rgb = color
    connector.line.width = width
    return connector

def glass_card(slide, l, t, w, h, fill=WHITE, fill_alpha=0.85,
               border=TEAL_LIGHT, border_w=Pt(1.2), radius=True):
    """Glassmorphism card — white with teal border + subtle shadow via layering."""
    # Shadow layer
    shadow = add_rect(slide, l + Inches(0.04), t + Inches(0.04), w, h,
                      fill=TEAL_GHOST, radius=radius)
    # Main card
    card = add_rect(slide, l, t, w, h, fill=fill, line=border,
                    line_w=border_w, radius=radius)
    return card

def accent_bar(slide, l, t, h=Inches(0.06), w=Inches(0.5)):
    """Small teal decorative bar."""
    add_gradient_rect(slide, l, t, w, h, TEAL, CYAN, radius=False)

def slide_header(slide, title, subtitle=None, light_bg=True):
    """Standard slide top section."""
    tc = DARK_NAVY if light_bg else WHITE
    sc = SLATE_600 if light_bg else TEAL_LIGHT
    add_textbox(slide, title, Inches(0.7), Inches(0.35), Inches(11.9), Inches(0.65),
                font_size=Pt(30), bold=True, color=tc, font_name="Calibri")
    if subtitle:
        add_textbox(slide, subtitle, Inches(0.7), Inches(0.95), Inches(11.9), Inches(0.35),
                    font_size=Pt(14), color=sc, font_name="Calibri")
    # Thin teal underline
    add_gradient_rect(slide, Inches(0.7), Inches(1.32), Inches(12.6), Inches(0.04),
                      TEAL, CYAN)

def white_bg(slide):
    add_rect(slide, 0, 0, W, H, fill=WHITE)

def light_teal_bg(slide):
    """Very light teal gradient background."""
    add_gradient_rect(slide, 0, 0, W, H,
                      RGBColor(0xF0, 0xFD, 0xFA), RGBColor(0xE0, 0xF7, 0xF4), angle=135)

def dark_teal_bg(slide):
    add_gradient_rect(slide, 0, 0, W, H, DARK_NAVY, DARK_SLATE, angle=135)

def teal_gradient_bg(slide):
    add_gradient_rect(slide, 0, 0, W, H, TEAL, CYAN, angle=135)

def icon_circle(slide, cx, cy, r, icon_text, bg=TEAL, text_color=WHITE, icon_size=Pt(18)):
    add_circle(slide, cx, cy, r, fill=bg)
    add_textbox(slide, icon_text,
                cx - r, cy - r, r * 2, r * 2,
                font_size=icon_size, bold=True, color=text_color,
                align=PP_ALIGN.CENTER, font_name="Segoe UI Symbol")

def pill_badge(slide, text, l, t, w=Inches(1.6), h=Inches(0.32),
               bg=TEAL_GHOST, text_color=TEAL, font_size=Pt(9.5)):
    badge = add_rect(slide, l, t, w, h, fill=bg, radius=True)
    add_textbox(slide, text, l, t + Inches(0.03), w, h - Inches(0.03),
                font_size=font_size, bold=True, color=text_color,
                align=PP_ALIGN.CENTER, font_name="Calibri")

def arrow_right(slide, x, y, length=Inches(0.4), color=TEAL):
    add_line(slide, x, y, x + length, y, color=color, width=Pt(2))
    # Arrow head (small triangle via tiny lines)
    add_line(slide, x + length - Inches(0.08), y - Inches(0.05),
             x + length, y, color=color, width=Pt(2))
    add_line(slide, x + length - Inches(0.08), y + Inches(0.05),
             x + length, y, color=color, width=Pt(2))

def add_transition(slide):
    """Add a smooth fade transition to the slide via XML."""
    spTree = slide.shapes._spTree
    slide_elem = slide._element
    # Add transition element
    trans_xml = '<p:transition xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" spd="med" advClick="1"><p:fade/></p:transition>'
    try:
        trans_elem = etree.fromstring(trans_xml)
        slide_elem.append(trans_elem)
    except Exception:
        pass

# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 1 — COVER
# ═══════════════════════════════════════════════════════════════════════════
def slide_cover():
    slide = prs.slides.add_slide(BLANK)
    add_transition(slide)

    # Background: dark teal gradient
    add_gradient_rect(slide, 0, 0, W, H, DARK_NAVY, RGBColor(0x07, 0x4A, 0x45), angle=140)

    # Decorative circles (glassmorphism blobs)
    add_circle(slide, Inches(12.0), Inches(1.0), Inches(2.2),
               fill=RGBColor(0x0D, 0x94, 0x88))
    add_circle(slide, Inches(11.0), Inches(6.5), Inches(1.5),
               fill=RGBColor(0x06, 0x76, 0x6E))
    add_circle(slide, Inches(1.5), Inches(5.8), Inches(1.0),
               fill=RGBColor(0x06, 0x76, 0x6E))
    add_circle(slide, Inches(0.4), Inches(1.2), Inches(0.7),
               fill=RGBColor(0x09, 0x5B, 0x56))

    # Teal accent stripe on left
    add_gradient_rect(slide, 0, 0, Inches(0.12), H, TEAL, CYAN, angle=90)

    # CareLink logo wordmark
    add_textbox(slide, "CareLink",
                Inches(1.0), Inches(1.5), Inches(8), Inches(1.2),
                font_size=Pt(64), bold=True, color=WHITE, font_name="Calibri")

    # Teal underline below wordmark
    add_gradient_rect(slide, Inches(1.0), Inches(2.65), Inches(5.5), Inches(0.06),
                      TEAL_LIGHT, CYAN_LIGHT)

    # Tagline
    add_textbox(slide,
                "AI-Powered Home Healthcare, Redefined",
                Inches(1.0), Inches(2.8), Inches(9), Inches(0.6),
                font_size=Pt(20), bold=False, color=TEAL_LIGHT, font_name="Calibri")

    # Role pills
    roles = [("👤  Patient", Inches(1.0)),
             ("🩺  Doctor", Inches(3.1)),
             ("💉  Nurse", Inches(5.2))]
    for label, lx in roles:
        pill_badge(slide, label, lx, Inches(3.6),
                   w=Inches(1.85), h=Inches(0.36),
                   bg=RGBColor(0x0F, 0x5E, 0x58),
                   text_color=TEAL_LIGHT, font_size=Pt(10.5))

    # Divider
    add_rect(slide, Inches(1.0), Inches(4.15), Inches(11.3), Inches(0.015),
             fill=RGBColor(0x1F, 0x4F, 0x4B))

    # Team / university info
    info_lines = [
        "Graduation Project  ·  Computer Science Department",
        "Supervised by: [Supervisor Name]",
        "Team: [Team Members]                                        2025 – 2026"
    ]
    for i, line in enumerate(info_lines):
        add_textbox(slide, line,
                    Inches(1.0), Inches(4.28) + Inches(0.38) * i,
                    Inches(11.3), Inches(0.38),
                    font_size=Pt(11.5), color=SLATE_400, font_name="Calibri")

    # Right-side medical cross illustration (SVG-free, using shapes)
    # Vertical bar of cross
    add_gradient_rect(slide, Inches(10.8), Inches(2.5), Inches(0.35), Inches(1.2),
                      TEAL_LIGHT, CYAN_LIGHT)
    # Horizontal bar of cross
    add_gradient_rect(slide, Inches(10.37), Inches(2.87), Inches(1.2), Inches(0.35),
                      TEAL_LIGHT, CYAN_LIGHT)
    add_circle(slide, Inches(11.0), Inches(3.1), Inches(0.8),
               line=TEAL_LIGHT, line_w=Pt(1.5))

    return slide

# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 2 — INTRODUCTION
# ═══════════════════════════════════════════════════════════════════════════
def slide_introduction():
    slide = prs.slides.add_slide(BLANK)
    add_transition(slide)
    white_bg(slide)

    # Top teal accent bar
    add_gradient_rect(slide, 0, 0, W, Inches(0.07), TEAL, CYAN)

    slide_header(slide, "Introduction",
                 "What is CareLink and who does it serve?")

    # Central description
    add_textbox(slide,
                "CareLink is a full-stack mobile platform that connects patients with verified home-care doctors and nurses — enabling intelligent scheduling, AI-driven matching, secure payments, and structured medical records in a bilingual (Arabic / English) interface.",
                Inches(0.7), Inches(1.5), Inches(11.9), Inches(0.9),
                font_size=Pt(13.5), color=SLATE_600, font_name="Calibri")

    # Three role cards
    role_data = [
        ("👤", "Patient", TEAL,
         ["Browse & book providers", "AI-matched recommendations", "Chat with care team", "View medical records"]),
        ("🩺", "Doctor", CYAN,
         ["Accept / complete requests", "Manage schedule & slots", "Submit diagnosis reports", "View patient records"]),
        ("💉", "Nurse", SOFT_GREEN,
         ["Home-visit service requests", "Visit tracking & reporting", "Earnings & payments", "Availability management"]),
    ]

    card_w = Inches(3.9)
    card_h = Inches(4.0)
    starts = [Inches(0.55), Inches(4.72), Inches(8.88)]

    for i, (icon, role, color, bullets) in enumerate(role_data):
        lx = starts[i]
        ty = Inches(2.5)
        # Shadow
        add_rect(slide, lx + Inches(0.05), ty + Inches(0.05), card_w, card_h,
                 fill=SLATE_200, radius=True)
        # Card
        card = add_rect(slide, lx, ty, card_w, card_h,
                        fill=WHITE, line=color, line_w=Pt(1.8), radius=True)
        # Color header band
        add_gradient_rect(slide, lx, ty, card_w, Inches(0.9), color,
                          RGBColor(int(color[0]*0.8), int(color[1]*0.8), int(color[2]*1.1)))
        # Fix radius on header — just use rect
        # Icon + role
        add_textbox(slide, icon + "  " + role,
                    lx + Inches(0.15), ty + Inches(0.1),
                    card_w - Inches(0.3), Inches(0.7),
                    font_size=Pt(18), bold=True, color=WHITE, font_name="Calibri")
        # Bullets
        for j, b in enumerate(bullets):
            add_textbox(slide, "›  " + b,
                        lx + Inches(0.2), ty + Inches(1.05) + Inches(0.68) * j,
                        card_w - Inches(0.4), Inches(0.6),
                        font_size=Pt(11.5), color=SLATE_600, font_name="Calibri")

    # Bottom stat strip
    stats = [("4", "User Roles"), ("12", "API Route Groups"),
             ("AR/EN", "Bilingual UI"), ("AI", "Smart Matching")]
    strip_y = Inches(6.75)
    add_gradient_rect(slide, 0, strip_y, W, Inches(0.75), TEAL_GHOST, CYAN_LIGHT, angle=0)
    for i, (val, label) in enumerate(stats):
        sx = Inches(1.6) + Inches(2.7) * i
        add_textbox(slide, val, sx, strip_y + Inches(0.03), Inches(1.5), Inches(0.35),
                    font_size=Pt(18), bold=True, color=TEAL, align=PP_ALIGN.CENTER)
        add_textbox(slide, label, sx, strip_y + Inches(0.36), Inches(1.5), Inches(0.3),
                    font_size=Pt(9), color=SLATE_600, align=PP_ALIGN.CENTER)

    return slide

# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 3 — PROBLEM STATEMENT
# ═══════════════════════════════════════════════════════════════════════════
def slide_problem():
    slide = prs.slides.add_slide(BLANK)
    add_transition(slide)
    light_teal_bg(slide)

    add_gradient_rect(slide, 0, 0, W, Inches(0.07), TEAL, CYAN)
    slide_header(slide, "Problem Statement",
                 "The gaps that CareLink was built to close")

    problems = [
        ("⚠", "No Unified Platform",
         "Patients had no single trusted place to find, verify, and book home-care doctors or nurses — leading to informal, unsafe arrangements.",
         WARM_AMBER),
        ("📅", "Manual & Fragmented Scheduling",
         "No conflict detection, no real-time availability, no reschedule workflow. Appointments were lost to double-bookings and no-shows.",
         SOFT_ROSE),
        ("💳", "Opaque Payments & No Governance",
         "No clear cancellation/refund policy, no provider rate approval gate, and no escrow mechanism to protect both patient and provider.",
         LAVENDER),
    ]

    card_w = Inches(3.8)
    card_h = Inches(4.2)
    gap = Inches(0.45)
    starts = [gap, gap + card_w + gap, gap + (card_w + gap) * 2]

    for i, (icon, title, desc, color) in enumerate(problems):
        lx = starts[i]
        ty = Inches(1.65)
        # Glow shadow
        add_rect(slide, lx + Inches(0.06), ty + Inches(0.06), card_w, card_h,
                 fill=RGBColor(int(color[0]*0.9), int(color[1]*0.9), int(color[2]*0.9)),
                 radius=True)
        add_rect(slide, lx, ty, card_w, card_h, fill=WHITE,
                 line=color, line_w=Pt(2), radius=True)
        # Colored top strip
        add_rect(slide, lx, ty, card_w, Inches(0.08), fill=color, radius=False)
        # Icon circle
        add_circle(slide, lx + Inches(0.7), ty + Inches(0.8), Inches(0.45), fill=color)
        add_textbox(slide, icon,
                    lx + Inches(0.25), ty + Inches(0.45), Inches(0.9), Inches(0.7),
                    font_size=Pt(20), align=PP_ALIGN.CENTER, color=WHITE)
        # Title
        add_textbox(slide, title,
                    lx + Inches(0.2), ty + Inches(1.45), card_w - Inches(0.4), Inches(0.55),
                    font_size=Pt(15.5), bold=True, color=DARK_NAVY, font_name="Calibri")
        # Desc
        add_textbox(slide, desc,
                    lx + Inches(0.2), ty + Inches(2.0), card_w - Inches(0.4), Inches(2.0),
                    font_size=Pt(11.5), color=SLATE_600, font_name="Calibri")

    return slide

# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 4 — OUR SOLUTION
# ═══════════════════════════════════════════════════════════════════════════
def slide_solution():
    slide = prs.slides.add_slide(BLANK)
    add_transition(slide)
    white_bg(slide)

    add_gradient_rect(slide, 0, 0, W, Inches(0.07), TEAL, CYAN)
    slide_header(slide, "Our Solution",
                 "CareLink — a complete, governed home-care platform")

    # LEFT: Problem column
    add_rect(slide, Inches(0.5), Inches(1.55), Inches(4.5), Inches(5.6),
             fill=RGBColor(0xFE, 0xF9, 0xF9), line=SOFT_ROSE, line_w=Pt(1), radius=True)
    add_textbox(slide, "Before CareLink",
                Inches(0.7), Inches(1.7), Inches(4.1), Inches(0.5),
                font_size=Pt(13), bold=True, color=SOFT_ROSE, font_name="Calibri")
    before = [
        "✗   Scattered, unverified providers",
        "✗   No booking or scheduling system",
        "✗   No payment protection",
        "✗   No medical record continuity",
        "✗   No AI or intelligent matching",
    ]
    for i, b in enumerate(before):
        add_textbox(slide, b, Inches(0.7), Inches(2.35) + Inches(0.78) * i,
                    Inches(4.1), Inches(0.65),
                    font_size=Pt(11.5), color=SLATE_600, font_name="Calibri")

    # ARROW
    arrow_right(slide, Inches(5.2), Inches(4.35), length=Inches(0.85), color=TEAL)

    # RIGHT: Solution column
    add_rect(slide, Inches(6.2), Inches(1.55), Inches(6.6), Inches(5.6),
             fill=TEAL_GHOST, line=TEAL, line_w=Pt(1.5), radius=True)
    add_textbox(slide, "With CareLink",
                Inches(6.4), Inches(1.7), Inches(6.2), Inches(0.5),
                font_size=Pt(13), bold=True, color=TEAL, font_name="Calibri")

    pillars = [
        ("🔍", "5-Step Intelligent Booking Flow",
         "Select → Schedule → Location → Review → Pay"),
        ("🤖", "Explainable AI Recommendation Engine",
         "Medical record tags + GPS + rating scoring"),
        ("💳", "Simulated Escrow Payment System",
         "100% / 80% refund governance policy"),
        ("📋", "Structured Medical Records",
         "Disease/allergy DB + doctor & nurse notes"),
        ("🔔", "Real-Time Notifications + Bilingual Chat",
         "AR/EN push notifications + file/audio chat"),
    ]
    for i, (icon, title, sub) in enumerate(pillars):
        ty = Inches(2.35) + Inches(0.9) * i
        add_textbox(slide, f"{icon}  {title}",
                    Inches(6.45), ty, Inches(6.1), Inches(0.45),
                    font_size=Pt(12.5), bold=True, color=DARK_NAVY)
        add_textbox(slide, sub,
                    Inches(6.8), ty + Inches(0.4), Inches(5.7), Inches(0.38),
                    font_size=Pt(10.5), color=SLATE_600)

    return slide

# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 5 — KEY FEATURES
# ═══════════════════════════════════════════════════════════════════════════
def slide_features():
    slide = prs.slides.add_slide(BLANK)
    add_transition(slide)
    light_teal_bg(slide)

    add_gradient_rect(slide, 0, 0, W, Inches(0.07), TEAL, CYAN)
    slide_header(slide, "Key Features",
                 "Six core capabilities built into the real implementation")

    features = [
        ("📅", "5-Step Booking Flow",
         "Provider search → Date/time slot → Visit location (GPS) → Review → Mock-card payment",
         TEAL),
        ("💬", "Real-Time Chat",
         "In-app messaging with image, PDF, and voice attachments. Read receipts and typing indicators.",
         CYAN),
        ("📋", "Structured Medical Records",
         "Disease (ICD codes) and allergy databases with status tracking. Doctor & nurse clinical notes.",
         SOFT_GREEN),
        ("💳", "Cancellation & Refund Governance",
         "100% refund before provider acceptance. 80% refund after. 10% provider + 10% platform fee.",
         WARM_AMBER),
        ("💰", "Wallet & Commission System",
         "Provider wallet tracks pending/paid amounts. Admin commission split. Escrow ledger per transaction.",
         LAVENDER),
        ("🔐", "Rate Approval Gate",
         "Admin sets provider rate → Doctor accepts/rejects → Account activates only on mutual approval.",
         SOFT_ROSE),
    ]

    card_w = Inches(3.9)
    card_h = Inches(2.2)
    col_starts = [Inches(0.5), Inches(4.65), Inches(8.8)]
    row_starts = [Inches(1.65), Inches(4.1)]

    for i, (icon, title, desc, color) in enumerate(features):
        row, col = divmod(i, 3)
        lx = col_starts[col]
        ty = row_starts[row]

        # Shadow
        add_rect(slide, lx + Inches(0.05), ty + Inches(0.05), card_w, card_h,
                 fill=SLATE_200, radius=True)
        # Card
        add_rect(slide, lx, ty, card_w, card_h, fill=WHITE,
                 line=color, line_w=Pt(1.5), radius=True)
        # Left color bar
        add_rect(slide, lx, ty, Inches(0.06), card_h, fill=color, radius=False)
        # Icon
        add_textbox(slide, icon,
                    lx + Inches(0.15), ty + Inches(0.12), Inches(0.6), Inches(0.5),
                    font_size=Pt(20), align=PP_ALIGN.CENTER, color=color)
        # Title
        add_textbox(slide, title,
                    lx + Inches(0.75), ty + Inches(0.1), card_w - Inches(0.9), Inches(0.5),
                    font_size=Pt(12.5), bold=True, color=DARK_NAVY)
        # Desc
        add_textbox(slide, desc,
                    lx + Inches(0.15), ty + Inches(0.68), card_w - Inches(0.3), Inches(1.4),
                    font_size=Pt(10.5), color=SLATE_600)

    return slide

# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 6 — AI RECOMMENDATION ENGINE
# ═══════════════════════════════════════════════════════════════════════════
def slide_ai():
    slide = prs.slides.add_slide(BLANK)
    add_transition(slide)
    white_bg(slide)

    add_gradient_rect(slide, 0, 0, W, Inches(0.07), TEAL, CYAN)
    slide_header(slide, "AI Recommendation Engine",
                 "Explainable hybrid content-based scoring — no external ML model required")

    # ── INPUT COLUMN ──
    input_y = Inches(1.6)
    inputs = [
        ("📁", "Medical File Tags", "OCR text + AI analysis\n(patientmedicalfile)"),
        ("💊", "Health Profile", "Chronic diseases, allergies,\ncurrent medications"),
        ("🗣", "Search Query", "Free-text or voice-to-text\ncare intent"),
        ("📍", "GPS Location", "Patient coordinates\n(Haversine distance)"),
    ]
    icard_h = Inches(1.08)
    icard_w = Inches(2.9)
    for i, (icon, title, sub) in enumerate(inputs):
        ty = input_y + (icard_h + Inches(0.15)) * i
        add_rect(slide, Inches(0.4), ty, icard_w, icard_h,
                 fill=TEAL_GHOST, line=TEAL_LIGHT, line_w=Pt(1), radius=True)
        add_textbox(slide, icon, Inches(0.5), ty + Inches(0.25), Inches(0.45), Inches(0.55),
                    font_size=Pt(16), align=PP_ALIGN.CENTER, color=TEAL)
        add_textbox(slide, title,
                    Inches(1.0), ty + Inches(0.1), icard_w - Inches(0.65), Inches(0.38),
                    font_size=Pt(11.5), bold=True, color=DARK_NAVY)
        add_textbox(slide, sub,
                    Inches(1.0), ty + Inches(0.48), icard_w - Inches(0.65), Inches(0.52),
                    font_size=Pt(9.5), color=SLATE_600)
        # Arrow to engine
        add_line(slide, Inches(3.3), ty + icard_h / 2,
                 Inches(4.55), ty + icard_h / 2, color=TEAL_MED, width=Pt(1.5))

    # ── ENGINE BOX ──
    eng_l = Inches(4.55)
    eng_t = Inches(1.55)
    eng_w = Inches(4.2)
    eng_h = Inches(4.9)
    add_gradient_rect(slide, eng_l, eng_t, eng_w, eng_h, TEAL, CYAN, angle=135)
    add_textbox(slide, "🤖  Scoring Engine",
                eng_l + Inches(0.2), eng_t + Inches(0.15), eng_w - Inches(0.4), Inches(0.5),
                font_size=Pt(14), bold=True, color=WHITE, align=PP_ALIGN.CENTER)

    # Sub-scores
    scores = [
        ("Specialization Match", "Keyword + ICD tag matching against\npatient conditions & search query"),
        ("Experience Score", "0.4 (junior) → 1.0 (10+ years)\nTiered weighting"),
        ("Rating Score", "Normalized 0–1 (neutral 3/5\nfor new providers)"),
        ("Location Score", "Haversine decay: ≤1km → 1.0\n≤10km → 0.4"),
        ("Medical Compatibility", "analysisTags from uploaded\nrecords vs. specialization"),
    ]
    for i, (label, detail) in enumerate(scores):
        sy = eng_t + Inches(0.8) + Inches(0.8) * i
        add_rect(slide, eng_l + Inches(0.2), sy, eng_w - Inches(0.4), Inches(0.72),
                 fill=RGBColor(0x0A, 0x6E, 0x65), line=TEAL_LIGHT, line_w=Pt(0.7), radius=True)
        add_textbox(slide, label,
                    eng_l + Inches(0.35), sy + Inches(0.04), eng_w - Inches(0.7), Inches(0.3),
                    font_size=Pt(10.5), bold=True, color=WHITE)
        add_textbox(slide, detail,
                    eng_l + Inches(0.35), sy + Inches(0.34), eng_w - Inches(0.7), Inches(0.35),
                    font_size=Pt(8.5), color=TEAL_LIGHT)

    # ── OUTPUT COLUMN ──
    out_l = Inches(9.0)
    out_t = Inches(1.55)
    outputs = [
        ("🏅", "Ranked Providers", "finalScore + matchPercentage"),
        ("🔎", "Match Reason", "\"Recommended for cardiology\ndetected in your records\""),
        ("🏷", "Matched Tags", "analysisTags mapped to\nhuman-readable labels"),
        ("📊", "Score Breakdown", "Per-dimension score visible\nfor transparency"),
    ]
    ocard_h = Inches(1.08)
    ocard_w = Inches(3.8)
    for i, (icon, title, sub) in enumerate(outputs):
        ty = out_t + (ocard_h + Inches(0.15)) * i
        # Arrow from engine
        add_line(slide, Inches(8.75), ty + ocard_h / 2,
                 out_l, ty + ocard_h / 2, color=TEAL_MED, width=Pt(1.5))
        add_rect(slide, out_l, ty, ocard_w, ocard_h,
                 fill=RGBColor(0xF0, 0xFD, 0xFA), line=CYAN_LIGHT, line_w=Pt(1.2), radius=True)
        add_textbox(slide, icon, out_l + Inches(0.1), ty + Inches(0.25), Inches(0.45), Inches(0.5),
                    font_size=Pt(16), align=PP_ALIGN.CENTER, color=CYAN)
        add_textbox(slide, title,
                    out_l + Inches(0.6), ty + Inches(0.1), ocard_w - Inches(0.75), Inches(0.38),
                    font_size=Pt(11.5), bold=True, color=DARK_NAVY)
        add_textbox(slide, sub,
                    out_l + Inches(0.6), ty + Inches(0.48), ocard_w - Inches(0.75), Inches(0.52),
                    font_size=Pt(9.5), color=SLATE_600)

    # Bottom note
    add_textbox(slide,
                "Cold-start: historyWeight = 0 until visit signals exist. Voice search via speech_to_text → rawQuery → requestedServiceKeyword.",
                Inches(0.5), Inches(6.8), Inches(12.3), Inches(0.4),
                font_size=Pt(9.5), color=SLATE_400, align=PP_ALIGN.CENTER)

    return slide

# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 7 — SYSTEM ARCHITECTURE
# ═══════════════════════════════════════════════════════════════════════════
def slide_architecture():
    slide = prs.slides.add_slide(BLANK)
    add_transition(slide)
    light_teal_bg(slide)

    add_gradient_rect(slide, 0, 0, W, Inches(0.07), TEAL, CYAN)
    slide_header(slide, "System Architecture",
                 "Flutter → Express REST API → MySQL  ·  3-Tier, 12 Route Groups, 5 Services")

    # ── TIER 1: CLIENTS ──
    tier_top = Inches(1.6)
    tier_h   = Inches(1.45)
    tier_gap = Inches(0.55)
    tier_w   = Inches(3.7)

    # Client tier header
    add_gradient_rect(slide, Inches(0.4), tier_top, Inches(2.2), tier_h,
                      TEAL, CYAN)
    add_textbox(slide, "Flutter\nClients",
                Inches(0.4), tier_top + Inches(0.35), Inches(2.2), Inches(0.8),
                font_size=Pt(13), bold=True, color=WHITE, align=PP_ALIGN.CENTER)

    clients = ["👤 Patient", "🩺 Doctor", "💉 Nurse", "🛡 Admin"]
    client_colors = [TEAL, CYAN, SOFT_GREEN, WARM_AMBER]
    for i, (c, col) in enumerate(zip(clients, client_colors)):
        cx = Inches(2.85) + Inches(2.45) * i
        add_rect(slide, cx, tier_top, Inches(2.2), tier_h,
                 fill=WHITE, line=col, line_w=Pt(1.5), radius=True)
        add_textbox(slide, c,
                    cx, tier_top + Inches(0.45), Inches(2.2), Inches(0.55),
                    font_size=Pt(13), bold=True, color=col, align=PP_ALIGN.CENTER)

    # Downward arrows tier1 → tier2
    mid_x = Inches(6.65)
    arr_y1 = tier_top + tier_h
    arr_y2 = arr_y1 + tier_gap
    add_line(slide, mid_x, arr_y1, mid_x, arr_y2, color=TEAL, width=Pt(2))
    add_textbox(slide, "REST API  (HTTP/JSON)", Inches(5.0), arr_y1 + Inches(0.05),
                Inches(3.3), Inches(0.38), font_size=Pt(9.5), color=TEAL,
                align=PP_ALIGN.CENTER)

    # ── TIER 2: API ──
    api_top = arr_y2
    api_h   = Inches(2.0)

    add_gradient_rect(slide, Inches(0.4), api_top, Inches(2.2), api_h,
                      DARK_NAVY, DARK_SLATE)
    add_textbox(slide, "Express\nAPI Layer",
                Inches(0.4), api_top + Inches(0.5), Inches(2.2), Inches(1.0),
                font_size=Pt(13), bold=True, color=WHITE, align=PP_ALIGN.CENTER)

    # Route group pills
    routes = [
        "/patient", "/doctor", "/nurse", "/admin",
        "/payments", "/api/payments", "/recommendations",
        "/medical-records", "/providers", "/notifications",
        "/ratings", "/email-auth"
    ]
    pill_w = Inches(1.55)
    pill_h = Inches(0.32)
    cols_r = 6
    for i, r in enumerate(routes):
        row_r, col_r = divmod(i, cols_r)
        px = Inches(2.85) + (pill_w + Inches(0.17)) * col_r
        py = api_top + Inches(0.18) + (pill_h + Inches(0.22)) * row_r
        bg = TEAL_GHOST if i % 3 == 0 else (CYAN_LIGHT if i % 3 == 1 else RGBColor(0xF0, 0xF9, 0xFF))
        tc = TEAL if i % 3 == 0 else (RGBColor(0x07, 0x6E, 0x8F) if i % 3 == 1 else RGBColor(0x1D, 0x4E, 0x89))
        add_rect(slide, px, py, pill_w, pill_h, fill=bg, line=SLATE_200, line_w=Pt(0.7), radius=True)
        add_textbox(slide, r, px, py + Inches(0.04), pill_w, pill_h - Inches(0.04),
                    font_size=Pt(8.5), bold=True, color=tc, align=PP_ALIGN.CENTER)

    # Services row
    services = ["bookingPayment", "cancellationPolicy", "aiRecommendation", "emailOTP", "notifications"]
    svc_y = api_top + Inches(1.55)
    svc_pill_w = Inches(1.88)
    for i, svc in enumerate(services):
        sx = Inches(2.85) + (svc_pill_w + Inches(0.12)) * i
        add_rect(slide, sx, svc_y, svc_pill_w, Inches(0.35),
                 fill=DARK_SLATE, line=TEAL_MED, line_w=Pt(0.8), radius=True)
        add_textbox(slide, "⚙ " + svc, sx, svc_y + Inches(0.04), svc_pill_w, Inches(0.3),
                    font_size=Pt(8.5), color=TEAL_LIGHT, align=PP_ALIGN.CENTER)

    # Arrows tier2 → tier3
    arr2_y1 = api_top + api_h
    arr2_y2 = arr2_y1 + Inches(0.42)
    add_line(slide, mid_x, arr2_y1, mid_x, arr2_y2, color=TEAL, width=Pt(2))
    add_textbox(slide, "mysql2  (connection pool)", Inches(5.0), arr2_y1 + Inches(0.06),
                Inches(3.3), Inches(0.3), font_size=Pt(9.5), color=TEAL, align=PP_ALIGN.CENTER)

    # ── TIER 3: DATABASE ──
    db_top = arr2_y2
    db_h   = Inches(0.95)

    add_gradient_rect(slide, Inches(0.4), db_top, Inches(2.2), db_h,
                      DARK_SLATE, DARK_NAVY)
    add_textbox(slide, "MySQL\nDatabase",
                Inches(0.4), db_top + Inches(0.18), Inches(2.2), Inches(0.7),
                font_size=Pt(12), bold=True, color=WHITE, align=PP_ALIGN.CENTER)

    tables = ["user", "patient", "careprovider", "servicerequest",
              "payment", "medicalrecord", "availabilityslot", "message",
              "providervisitrating", "provider_rates", "provider_wallet", "admin_wallet"]
    tbl_w = Inches(0.9)
    tbl_h = Inches(0.28)
    for i, tbl in enumerate(tables):
        col_t = i % 6
        row_t = i // 6
        tx = Inches(2.85) + (tbl_w + Inches(0.2)) * col_t
        ty = db_top + Inches(0.12) + (tbl_h + Inches(0.28)) * row_t
        add_rect(slide, tx, ty, tbl_w, tbl_h,
                 fill=RGBColor(0x0C, 0x3D, 0x38), line=TEAL_LIGHT, line_w=Pt(0.6), radius=True)
        add_textbox(slide, tbl, tx, ty + Inches(0.04), tbl_w, tbl_h - Inches(0.04),
                    font_size=Pt(7.5), color=TEAL_LIGHT, align=PP_ALIGN.CENTER, bold=True)

    return slide

# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 8 — LIVE DEMO (TRANSITION)
# ═══════════════════════════════════════════════════════════════════════════
def slide_demo():
    slide = prs.slides.add_slide(BLANK)
    add_transition(slide)

    # Full-bleed gradient
    add_gradient_rect(slide, 0, 0, W, H, TEAL, CYAN, angle=135)

    # Subtle radial glow shape
    add_circle(slide, W / 2, H / 2, Inches(3.5),
               fill=RGBColor(0x0B, 0x80, 0x78))
    add_circle(slide, W / 2, H / 2, Inches(2.6),
               fill=RGBColor(0x0D, 0x94, 0x88))

    # Phone silhouette (outer)
    ph_w, ph_h = Inches(1.6), Inches(2.8)
    ph_l = W / 2 - ph_w / 2
    ph_t = H / 2 - ph_h / 2
    add_rect(slide, ph_l, ph_t, ph_w, ph_h,
             fill=RGBColor(0x0A, 0x6D, 0x66), line=WHITE, line_w=Pt(2), radius=True)
    # Screen
    add_rect(slide, ph_l + Inches(0.1), ph_t + Inches(0.22),
             ph_w - Inches(0.2), ph_h - Inches(0.42),
             fill=WHITE, radius=False)
    # Home indicator
    add_circle(slide, W / 2, ph_t + ph_h - Inches(0.15), Inches(0.06), fill=WHITE)

    # Main label
    add_textbox(slide, "Live Demo",
                Inches(0.5), Inches(0.85), W - Inches(1), Inches(1.4),
                font_size=Pt(68), bold=True, color=WHITE,
                align=PP_ALIGN.CENTER, font_name="Calibri")

    # Demo flow chips
    chips = ["Patient Booking", "AI Matching", "Mock Payment", "Doctor Accept", "Chat"]
    chip_total_w = Inches(1.7) * len(chips) + Inches(0.3) * (len(chips) - 1)
    chip_start = (W - chip_total_w) / 2
    for i, chip in enumerate(chips):
        cx = chip_start + (Inches(1.7) + Inches(0.3)) * i
        cy = Inches(6.25)
        add_rect(slide, cx, cy, Inches(1.7), Inches(0.4),
                 fill=RGBColor(0x0A, 0x6D, 0x66), line=WHITE, line_w=Pt(1), radius=True)
        add_textbox(slide, chip, cx, cy + Inches(0.05), Inches(1.7), Inches(0.35),
                    font_size=Pt(10.5), bold=True, color=WHITE, align=PP_ALIGN.CENTER)
        if i < len(chips) - 1:
            sx = cx + Inches(1.7)
            add_line(slide, sx, cy + Inches(0.2), sx + Inches(0.3), cy + Inches(0.2),
                     color=WHITE, width=Pt(1.5))

    return slide

# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 9 — TECHNOLOGIES
# ═══════════════════════════════════════════════════════════════════════════
def slide_tech():
    slide = prs.slides.add_slide(BLANK)
    add_transition(slide)
    white_bg(slide)

    add_gradient_rect(slide, 0, 0, W, Inches(0.07), TEAL, CYAN)
    slide_header(slide, "Technologies Used",
                 "Production-grade open-source stack — Flutter · Node.js · MySQL")

    # Two columns
    col_data = [
        ("📱  Frontend — Flutter / Dart", [
            ("Flutter 3 + Dart", "Cross-platform mobile + web + desktop", TEAL),
            ("speech_to_text", "Voice search for AI screen", CYAN),
            ("geolocator + flutter_map", "GPS + Haversine distance", SOFT_GREEN),
            ("table_calendar", "Provider availability slots", WARM_AMBER),
            ("http + shared_preferences", "REST calls + session storage", LAVENDER),
            ("pdf + printing", "Prescription PDF generation", SOFT_ROSE),
        ]),
        ("⚙️  Backend — Node.js / Express", [
            ("Express.js", "12 route groups · REST API", TEAL),
            ("MySQL2 + connection pool", "utf8mb4 · 10 connections · schema-adaptive queries", CYAN),
            ("bcrypt + OTP", "Password hashing · Phone + Email OTP (Twilio/SMTP)", SOFT_GREEN),
            ("multer", "Image/PDF/voice file uploads (25 MB)", WARM_AMBER),
            ("nodemailer", "Email verification codes (SMTP)", LAVENDER),
            ("lxml / xml parsing", "Schema migration compatibility layer", SOFT_ROSE),
        ]),
    ]

    col_w = Inches(6.0)
    for ci, (col_title, techs) in enumerate(col_data):
        lx = Inches(0.45) + (col_w + Inches(0.45)) * ci
        # Column header
        add_gradient_rect(slide, lx, Inches(1.65), col_w, Inches(0.5), TEAL, CYAN)
        add_textbox(slide, col_title, lx + Inches(0.15), Inches(1.68),
                    col_w - Inches(0.3), Inches(0.45),
                    font_size=Pt(12), bold=True, color=WHITE)
        # Tech badges
        for ti, (name, detail, color) in enumerate(techs):
            ty = Inches(2.3) + Inches(0.8) * ti
            add_rect(slide, lx, ty, col_w, Inches(0.72),
                     fill=RGBColor(0xFA, 0xFD, 0xFC), line=color, line_w=Pt(1.2), radius=True)
            # Color dot
            add_circle(slide, lx + Inches(0.28), ty + Inches(0.36), Inches(0.12), fill=color)
            add_textbox(slide, name,
                        lx + Inches(0.5), ty + Inches(0.06), col_w - Inches(0.65), Inches(0.35),
                        font_size=Pt(12), bold=True, color=DARK_NAVY)
            add_textbox(slide, detail,
                        lx + Inches(0.5), ty + Inches(0.38), col_w - Inches(0.65), Inches(0.3),
                        font_size=Pt(9.5), color=SLATE_600)

    return slide

# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 10 — FUTURE WORK
# ═══════════════════════════════════════════════════════════════════════════
def slide_future():
    slide = prs.slides.add_slide(BLANK)
    add_transition(slide)
    light_teal_bg(slide)

    add_gradient_rect(slide, 0, 0, W, Inches(0.07), TEAL, CYAN)
    slide_header(slide, "Future Work",
                 "Three-phase roadmap to evolve CareLink beyond the graduation prototype")

    # Timeline line
    line_y = Inches(3.8)
    add_gradient_rect(slide, Inches(0.8), line_y - Inches(0.03), Inches(11.7), Inches(0.06),
                      TEAL, CYAN)

    phases = [
        ("Phase 1", "Production-Ready", TEAL, Inches(1.4), [
            "Real payment gateway (Stripe / HyperPay)",
            "Firebase Cloud Messaging (push notifications)",
            "JWT authentication (replace userId-as-token)",
            "Rate limiting + input validation middleware",
        ]),
        ("Phase 2", "Enhanced Clinical Tools", CYAN, Inches(5.15), [
            "Video consultation module",
            "In-app prescription PDF generation",
            "Lab result upload + OCR parsing",
            "Doctor-to-doctor referral workflow",
        ]),
        ("Phase 3", "AI & Wearables", SOFT_GREEN, Inches(8.85), [
            "ML-trained recommendation model",
            "Wearable device (heart rate, glucose) integration",
            "Predictive scheduling from visit history",
            "Multi-language NLP for symptom parsing",
        ]),
    ]

    for phase, subtitle, color, px, items in phases:
        # Node circle
        add_circle(slide, px + Inches(0.9), line_y, Inches(0.25), fill=color)
        add_circle(slide, px + Inches(0.9), line_y, Inches(0.45),
                   line=color, line_w=Pt(1.5))
        # Phase label above line
        add_textbox(slide, phase, px, line_y - Inches(0.8), Inches(1.8), Inches(0.38),
                    font_size=Pt(11), bold=True, color=color, align=PP_ALIGN.CENTER)
        add_textbox(slide, subtitle, px, line_y - Inches(0.45), Inches(1.8), Inches(0.35),
                    font_size=Pt(9.5), color=SLATE_600, align=PP_ALIGN.CENTER)
        # Card below line
        card_top = line_y + Inches(0.55)
        card_w2 = Inches(3.6)
        add_rect(slide, px - Inches(0.9), card_top, card_w2, Inches(2.55),
                 fill=WHITE, line=color, line_w=Pt(1.5), radius=True)
        add_rect(slide, px - Inches(0.9), card_top, card_w2, Inches(0.08),
                 fill=color, radius=False)
        for i, item in enumerate(items):
            add_textbox(slide, "›  " + item,
                        px - Inches(0.75), card_top + Inches(0.2) + Inches(0.55) * i,
                        card_w2 - Inches(0.2), Inches(0.48),
                        font_size=Pt(10.5), color=SLATE_600)

    return slide

# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 11 — CONCLUSION
# ═══════════════════════════════════════════════════════════════════════════
def slide_conclusion():
    slide = prs.slides.add_slide(BLANK)
    add_transition(slide)
    white_bg(slide)

    add_gradient_rect(slide, 0, 0, W, Inches(0.07), TEAL, CYAN)
    slide_header(slide, "Conclusion",
                 "What CareLink delivers as a graduation project")

    achievements = [
        ("✓", "Full-Stack Mobile Platform",
         "Flutter + Node.js + MySQL serving four distinct user roles — Patient, Doctor, Nurse, and Admin — each with dedicated dashboards, workflows, and access controls.",
         TEAL),
        ("✓", "Explainable AI Provider Matching",
         "Rule-based weighted scoring engine that ingests OCR-extracted medical file tags, GPS distance, specialization, and ratings to rank providers with human-readable reasons.",
         CYAN),
        ("✓", "Governance & Financial Layer",
         "Admin rate approval gate, escrow-style payment system, 100%/80% cancellation refund policy, provider wallet, and admin commission split — all implemented and enforced server-side.",
         SOFT_GREEN),
    ]

    card_w3 = Inches(3.8)
    card_h3 = Inches(3.6)
    starts3 = [Inches(0.45), Inches(4.65), Inches(8.85)]

    for i, (check, title, desc, color) in enumerate(achievements):
        lx = starts3[i]
        ty = Inches(1.8)
        # Shadow
        add_rect(slide, lx + Inches(0.05), ty + Inches(0.05), card_w3, card_h3,
                 fill=SLATE_200, radius=True)
        # Card
        add_rect(slide, lx, ty, card_w3, card_h3, fill=WHITE,
                 line=color, line_w=Pt(2), radius=True)
        # Top strip
        add_gradient_rect(slide, lx, ty, card_w3, Inches(0.55), color,
                          RGBColor(int(color[0]*0.8), int(color[1]*1.0), int(color[2]*1.0)))
        # Check + title
        add_textbox(slide, check + "  " + title,
                    lx + Inches(0.2), ty + Inches(0.65), card_w3 - Inches(0.4), Inches(0.55),
                    font_size=Pt(13.5), bold=True, color=DARK_NAVY)
        # Desc
        add_textbox(slide, desc,
                    lx + Inches(0.2), ty + Inches(1.35), card_w3 - Inches(0.4), Inches(2.1),
                    font_size=Pt(11), color=SLATE_600)

    # Closing statement
    add_gradient_rect(slide, Inches(0.5), Inches(5.65), Inches(12.3), Inches(0.9),
                      TEAL_GHOST, CYAN_LIGHT, angle=0)
    add_textbox(slide,
                "CareLink demonstrates that a small engineering team can design, build, and govern a complete digital healthcare ecosystem — from first symptom to completed visit.",
                Inches(0.7), Inches(5.73), Inches(11.9), Inches(0.75),
                font_size=Pt(12.5), color=TEAL, align=PP_ALIGN.CENTER, bold=True)

    return slide

# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 12 — THANK YOU
# ═══════════════════════════════════════════════════════════════════════════
def slide_thankyou():
    slide = prs.slides.add_slide(BLANK)
    add_transition(slide)

    add_gradient_rect(slide, 0, 0, W, H,
                      RGBColor(0x06, 0x55, 0x52), RGBColor(0x0D, 0x94, 0x88), angle=135)

    # Decorative circles
    add_circle(slide, Inches(1.5), Inches(1.0), Inches(1.8),
               fill=RGBColor(0x08, 0x6B, 0x67))
    add_circle(slide, Inches(11.8), Inches(6.5), Inches(2.0),
               fill=RGBColor(0x08, 0x6B, 0x67))
    add_circle(slide, Inches(12.5), Inches(1.5), Inches(1.0),
               fill=RGBColor(0x07, 0x76, 0x72))
    add_circle(slide, Inches(0.5), Inches(6.8), Inches(0.8),
               fill=RGBColor(0x07, 0x76, 0x72))

    # Thin accent stripe
    add_gradient_rect(slide, 0, 0, Inches(0.12), H, TEAL_LIGHT, CYAN_LIGHT, angle=90)

    # Thank You
    add_textbox(slide, "Thank You",
                Inches(0.5), Inches(1.6), W - Inches(1), Inches(1.5),
                font_size=Pt(72), bold=True, color=WHITE,
                align=PP_ALIGN.CENTER, font_name="Calibri")

    # CareLink brand
    add_textbox(slide, "CareLink",
                Inches(0.5), Inches(3.05), W - Inches(1), Inches(0.75),
                font_size=Pt(32), bold=False, color=TEAL_LIGHT,
                align=PP_ALIGN.CENTER, font_name="Calibri")

    # Divider
    add_gradient_rect(slide, Inches(4.0), Inches(3.85), Inches(5.3), Inches(0.05),
                      TEAL_LIGHT, CYAN_LIGHT)

    # Question prompt
    add_textbox(slide, "Open for Questions",
                Inches(0.5), Inches(4.05), W - Inches(1), Inches(0.6),
                font_size=Pt(18), color=TEAL_LIGHT,
                align=PP_ALIGN.CENTER, font_name="Calibri")

    # Team row
    add_textbox(slide, "Computer Science Department  ·  Graduation Project  ·  2025 – 2026",
                Inches(0.5), Inches(4.85), W - Inches(1), Inches(0.45),
                font_size=Pt(12), color=RGBColor(0x5E, 0xEA, 0xD4),
                align=PP_ALIGN.CENTER, font_name="Calibri")

    # Bottom chips — what we built
    chips12 = ["4 User Roles", "12 API Routes", "AI Engine", "Escrow Payments", "Bilingual"]
    chip_w12 = Inches(1.85)
    total_w12 = chip_w12 * len(chips12) + Inches(0.2) * (len(chips12) - 1)
    sx12 = (W - total_w12) / 2
    for i, chip in enumerate(chips12):
        cx12 = sx12 + (chip_w12 + Inches(0.2)) * i
        add_rect(slide, cx12, Inches(5.85), chip_w12, Inches(0.38),
                 fill=RGBColor(0x08, 0x50, 0x4D), line=TEAL_LIGHT, line_w=Pt(0.8), radius=True)
        add_textbox(slide, chip, cx12, Inches(5.9), chip_w12, Inches(0.32),
                    font_size=Pt(10), bold=True, color=WHITE, align=PP_ALIGN.CENTER)

    return slide

# ═══════════════════════════════════════════════════════════════════════════
# BUILD ALL SLIDES
# ═══════════════════════════════════════════════════════════════════════════
print("Building slide 1: Cover...")
slide_cover()
print("Building slide 2: Introduction...")
slide_introduction()
print("Building slide 3: Problem Statement...")
slide_problem()
print("Building slide 4: Solution...")
slide_solution()
print("Building slide 5: Key Features...")
slide_features()
print("Building slide 6: AI Recommendation...")
slide_ai()
print("Building slide 7: System Architecture...")
slide_architecture()
print("Building slide 8: Live Demo...")
slide_demo()
print("Building slide 9: Technologies...")
slide_tech()
print("Building slide 10: Future Work...")
slide_future()
print("Building slide 11: Conclusion...")
slide_conclusion()
print("Building slide 12: Thank You...")
slide_thankyou()

OUTPUT = "D:/carelink-care-link/CareLink_Graduation_Presentation.pptx"
prs.save(OUTPUT)
print(f"\n✅  Saved: {OUTPUT}")
