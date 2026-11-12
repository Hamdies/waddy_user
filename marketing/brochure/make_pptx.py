"""Editable PowerPoint for the partner brochure.

Reads out/master_dom.json and out/raster/*.png (written by build_master.js)
and rebuilds every page as native PowerPoint objects: headlines, body copy,
placeholders and boxes are real text boxes and shapes you can edit. Phone
mockups, maps, ad creatives and icons are pictures.

    python3 make_pptx.py

The deck uses the app's own fonts, Alexandria and Thmanyah Sans
(assets/font/). Install them before opening the file, or PowerPoint will
substitute and lines will re-wrap.
"""
import json
import os

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Emu, Pt

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
PX = 9525  # EMU per CSS pixel: 1280 px = 13.333 in
# CSS weight -> the installed family that carries it. PowerPoint only knows
# regular/bold per family, so the heavier cuts are addressed by family name.
def face(ff, fw):
    if ff == 'Alexandria':
        if fw >= 900:
            return 'Alexandria Black', False
        if fw >= 800:
            return 'Alexandria ExtraBold', False
        if fw >= 600:
            return 'Alexandria', True
        return 'Alexandria Medium', False
    if ff == 'Thmanyah':
        if fw >= 600:
            return 'thmanyah sans', True
        if fw >= 500:
            return 'thmanyah sans Med', False
        return 'thmanyah sans', False
    return ff, fw >= 600


def emu(v):
    return Emu(int(round(v * PX)))


def rgb(c):
    return RGBColor(int(c['r']), int(c['g']), int(c['b']))


def set_alpha(fill, a):
    if a >= 1:
        return
    clr = fill._xPr.find(qn('a:solidFill'))[0]
    el = clr.makeelement(qn('a:alpha'), {'val': str(int(a * 100000))})
    clr.append(el)


def add_rect(slide, it):
    w, h = it['w'], it['h']
    if w < 1 or h < 1:
        return
    rad = min(it['rad'], min(w, h) / 2)
    round_ = rad >= min(w, h) / 2 - 0.5
    kind = MSO_SHAPE.OVAL if round_ and abs(w - h) < 1.5 else (MSO_SHAPE.ROUNDED_RECTANGLE if rad > 0.5 else MSO_SHAPE.RECTANGLE)
    sh = slide.shapes.add_shape(kind, emu(it['x']), emu(it['y']), emu(w), emu(h))
    if kind == MSO_SHAPE.ROUNDED_RECTANGLE:
        sh.adjustments[0] = min(0.5, rad / min(w, h))
    sh.shadow.inherit = False
    st = sh._element.find(qn('p:style'))
    if st is not None:  # drop the theme style so no default shadow or outline comes back
        sh._element.remove(st)
    if it['fill']:
        sh.fill.solid()
        sh.fill.fore_color.rgb = rgb(it['fill'])
        set_alpha(sh.fill, it['fill']['a'])
    else:
        sh.fill.background()
    if it['line']:
        sh.line.color.rgb = rgb(it['line'])
        sh.line.width = Pt(max(0.5, it['lw'] * 0.75))
    else:
        sh.line.fill.background()


def add_text(slide, it):
    runs = [r for r in it['runs'] if r.get('br') or r.get('tx')]
    if not runs:
        return
    locked = any(r.get('br') for r in runs)  # headline with the browser's own line breaks
    # slack so a font-metric difference can't wrap or clip; wide for locked headlines
    pad = it['w'] * 0.12 if locked else (3 if it['multi'] else 6)
    x, w = it['x'], it['w'] + pad
    if it['al'] == 'c':
        x -= pad / 2
    tb = slide.shapes.add_textbox(emu(x), emu(it['y']), emu(w), emu(max(it['h'], it['lh'])))
    tf = tb.text_frame
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.word_wrap = bool(it['multi']) or locked
    tf.vertical_anchor = MSO_ANCHOR.TOP
    p = tf.paragraphs[0]

    def style(par):
        par.alignment = PP_ALIGN.CENTER if it['al'] == 'c' else PP_ALIGN.LEFT
        par.line_spacing = Pt(round(it['lh'] * 0.75, 1))

    style(p)
    for r in runs:
        if r.get('br'):
            p.add_line_break()
            continue
        run = p.add_run()
        run.text = r['tx']
        f = run.font
        f.size = Pt(round(r['fs'] * 0.75, 1))
        f.name, f.bold = face(r['ff'], r['fw'])
        f.color.rgb = rgb(r['c'])
        rpr = run._r.get_or_add_rPr()
        if r['ls']:
            rpr.set('spc', str(int(round(r['ls'] * 75))))
        if r.get('hl'):  # amber [placeholder] chips stay visibly highlighted
            hl = rpr.makeelement(qn('a:highlight'), {})
            c = hl.makeelement(qn('a:srgbClr'), {'val': '%02X%02X%02X' % (int(r['hl']['r']), int(r['hl']['g']), int(r['hl']['b']))})
            hl.append(c)
            # schema order: ln, fill, effect, highlight, ... latin
            anchor = rpr.find(qn('a:latin'))
            if anchor is not None:
                anchor.addprevious(hl)
            else:
                rpr.append(hl)


def main():
    dom = json.load(open(os.path.join(OUT, 'master_dom.json')))
    prs = Presentation()
    prs.slide_width, prs.slide_height = emu(1280), emu(720)
    blank = prs.slide_layouts[6]
    for page in dom:
        s = prs.slides.add_slide(blank)
        bg = s.background.fill
        bg.solid()
        bg.fore_color.rgb = rgb(page['bg'])
        for it in page['items']:
            if it['t'] == 'rect':
                add_rect(s, it)
            elif it['t'] == 'img':
                path = os.path.join(OUT, 'raster', '%d.png' % it['id'])
                if os.path.exists(path) and it['w'] > 0 and it['h'] > 0:
                    s.shapes.add_picture(path, emu(it['x']), emu(it['y']), emu(it['w']), emu(it['h']))
            else:
                add_text(s, it)
    dest = os.path.join(OUT, 'waddy-partner-brochure.pptx')
    prs.save(dest)
    print('wrote', dest, len(dom), 'slides')


if __name__ == '__main__':
    main()
