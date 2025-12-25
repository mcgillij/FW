#!/usr/bin/env python3
"""Simple API doc generator for the FW GDScript files.
Scans `addons/fw/` for .gd files and extracts `class_name`, function signatures and
preceding comment blocks, then writes docs/api/generated.md.
"""

import os
import re

ROOT = os.path.dirname(os.path.dirname(__file__))
SRC_DIR = os.path.join(ROOT, 'addons', 'fw')
OUT = os.path.join(ROOT, 'docs', 'api', 'generated.md')

FUNC_RE = re.compile(r'^\s*func\s+([a-zA-Z0-9_]+)\s*(\([^)]*\))\s*(?:->\s*([^:\s]+))?')
CLASSNAME_RE = re.compile(r'^\s*class_name\s+([A-Za-z0-9_]+)')


def extract_comments(lines, idx):
    # Walk backwards collecting contiguous comment lines
    comments = []
    i = idx - 1
    while i >= 0:
        line = lines[i].rstrip('\n')
        if line.strip().startswith('#'):
            comments.insert(0, line.strip()[1:].lstrip())
            i -= 1
        elif line.strip() == '':
            # skip a single blank line
            i -= 1
            continue
        else:
            break
    return '\n'.join(comments).strip()


def parse_docblock(doc: str) -> dict:
    """Parse docblock annotations from comment text.

    Supports:
    - Multi-line @param descriptions (continuation lines that are indented or do not start with '@')
    - Optional typed @param: `@param <type> <name> <desc>` or `@param <name> <desc>`
    - @return with optional type `@return <type> <desc>` or 'Returns: <desc>'

    Returns a dict with keys: 'summary' (str), 'params' (dict of name -> {type, desc}),
    and 'returns' -> {type, desc}.
    """
    res = {"summary": "", "params": {}, "returns": {"type": "", "desc": ""}}
    if not doc:
        return res
    lines = doc.split('\n')
    # We'll iterate lines and capture annotations with continuation support
    summary_lines = []
    i = 0
    current_param = None
    while i < len(lines):
        raw = lines[i]
        l = raw.strip()
        if l.startswith('@param'):
            # @param [type] name desc...
            m = re.match(r'^@param(?:\s+(\S+))?(?:\s+(\S+))?(?:\s+(.*))?$', l)
            if m:
                gtype = m.group(1) if m.group(1) and not m.group(2) else (m.group(1) if m.group(2) else "")
                # If both groups present, detect which is type vs name: prefer pattern where second is name
                if m.group(2) and m.group(1):
                    pname = m.group(2)
                    ptype = m.group(1)
                    pdesc = m.group(3) or ""
                elif m.group(2):
                    pname = m.group(2)
                    ptype = ""
                    pdesc = m.group(3) or ""
                else:
                    pname = m.group(1) or ''
                    ptype = ''
                    pdesc = ''
                res["params"][pname] = {"type": ptype, "desc": pdesc}
                current_param = pname
            else:
                current_param = None
        elif l.startswith('@return') or l.lower().startswith('returns:') or l.lower().startswith('return:'):
            # capture @return [type] description
            m = re.match(r'^@return(?:\s+(\S+))?(?:\s+(.*))?$', l)
            if m:
                rtype = m.group(1) or ""
                rdesc = m.group(2) or ""
                res["returns"]["type"] = rtype
                res["returns"]["desc"] = rdesc
            else:
                # fallback: after ':'
                if ':' in l:
                    res["returns"]["desc"] = l.split(':',1)[1].strip()
            current_param = None
        elif l.startswith('@'):
            # unknown annotation, skip
            current_param = None
        else:
            # Continuation lines or summary
            if current_param:
                # append to last param description
                prev = res["params"].get(current_param, {"type": "", "desc": ""})
                # join with space and preserve small formatting
                newdesc = (prev["desc"] + '\n' + raw.strip()) if prev["desc"] else raw.strip()
                res["params"][current_param]["desc"] = newdesc
            else:
                # part of summary
                summary_lines.append(raw.strip())
        i += 1
    res["summary"] = '\n'.join([ln for ln in summary_lines if ln.strip()])
    return res


def scan_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    rel = os.path.relpath(path, ROOT)
    class_name = None
    class_doc = ''
    funcs = []

    for i, line in enumerate(lines):
        m = CLASSNAME_RE.match(line)
        if m:
            class_name = m.group(1)
            class_doc = extract_comments(lines, i)
        m2 = FUNC_RE.match(line)
        if m2:
            name = m2.group(1)
            sig = m2.group(2)
            ret = m2.group(3) if m2.group(3) else ''
            doc = extract_comments(lines, i)
            parsed = parse_docblock(doc)
            funcs.append((name, sig, ret, parsed))

    return rel, class_name, class_doc, funcs


def main():
    entries = []
    for root, dirs, files in os.walk(SRC_DIR):
        for fn in files:
            if fn.endswith('.gd'):
                path = os.path.join(root, fn)
                entries.append(scan_file(path))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    # Ensure classes dir
    CLASSES_DIR = os.path.join(os.path.dirname(OUT), 'classes')
    os.makedirs(CLASSES_DIR, exist_ok=True)

    # Build a map of class name -> class md path for cross-linking
    class_map = {}
    for rel, cname, cdoc, funcs in entries:
        if cname:
            class_md = 'classes/' + os.path.splitext(rel)[0] + '.md'
            class_map[cname] = class_md

    # Helper to link types if they match a known class
    def link_type(t: str) -> str:
        if not t:
            return t
        # simple tokenization: replace any token that matches a class name
        def repl(m):
            tok = m.group(0)
            if tok in class_map:
                return '[%s](%s)' % (tok, class_map[tok])
            return tok
        return re.sub(r'\b[A-Za-z_][A-Za-z0-9_]*\b', repl, t)

    # We'll manage unique anchors per class/function
    # (no search index when hosting as static markdown on GitHub)

    # Write per-class files and a combined generated file
    with open(OUT, 'w', encoding='utf-8') as out:
        out.write('# Generated API Reference\n\n')
        out.write('This file is generated by `scripts/generate_api_docs.py`. Run it when code changes to refresh API docs.\n\n')
        for rel, cname, cdoc, funcs in sorted(entries):
            # Combined file entry (link to per-class file)
            class_md_rel = os.path.splitext(rel)[0] + '.md'
            out.write('## [%s](classes/%s)\n\n' % (rel, class_md_rel))
            if cname:
                out.write('*Class*: `%s`\n\n' % cname)
            if cdoc:
                out.write('%s\n\n' % cdoc)
            if funcs:
                out.write('### Functions\n\n')
                # prepare anchors for this class
                anchors = {}
                safe_class = os.path.splitext(rel)[0].replace('/', '_').replace('.', '_')
                for idx, (name, sig, ret, parsed) in enumerate(funcs):
                    base = 'fn-%s' % name
                    count = anchors.get(base, 0)
                    anchor = base if count == 0 else '%s-%d' % (base, count)
                    anchors[base] = count + 1
                    # Combined file anchor (global-ish)
                    combined_anchor = 'g-%s-%s' % (safe_class, anchor)
                    out.write('<a name="%s"></a>\n' % combined_anchor)
                    # link to class file + anchor for detailed doc
                    class_md_path = 'classes/' + os.path.splitext(rel)[0] + '.md'
                    out.write('- [`%s%s`](%s#%s)\n' % (name, sig, class_md_path, anchor))


                    if ret:
                        out.write('  - Returns: `%s`\n' % link_type(ret))
                    if parsed and parsed.get('summary'):
                        for ln in parsed['summary'].split('\n'):
                            out.write('  - %s\n' % ln)
                    if parsed and parsed.get('params'):
                        out.write('  - Params:\n')
                        for pname, pinfo in parsed['params'].items():
                            ptype = pinfo.get('type','')
                            pdesc = pinfo.get('desc','')
                            if ptype:
                                out.write('    - `%s` (`%s`): %s\n' % (pname, link_type(ptype), pdesc))
                            else:
                                out.write('    - `%s`: %s\n' % (pname, pdesc))
                    if parsed and parsed.get('returns'):
                        r = parsed['returns']
                        rtype = r.get('type') or ''
                        if rtype:
                            out.write('  - Return: `%s` - %s\n' % (link_type(rtype), r.get('desc')))
                        elif r.get('desc'):
                            out.write('  - Return: %s\n' % r.get('desc'))
                out.write('\n')

            # Also write per-class file
            class_path_noext = os.path.splitext(rel)[0]
            class_out = os.path.join(CLASSES_DIR, class_path_noext + '.md')
            class_dir = os.path.dirname(class_out)
            os.makedirs(class_dir, exist_ok=True)
            with open(class_out, 'w', encoding='utf-8') as cf:
                cf.write('# %s\n\n' % rel)
                if cname:
                    cf.write('*Class*: `%s`\n\n' % cname)
                if cdoc:
                    cf.write('%s\n\n' % cdoc)
                if funcs:
                    cf.write('### Functions\n\n')
                    anchors = {}
                    for idx, (name, sig, ret, parsed) in enumerate(funcs):
                        base = 'fn-%s' % name
                        count = anchors.get(base, 0)
                        anchor = base if count == 0 else '%s-%d' % (base, count)
                        anchors[base] = count + 1
                        cf.write('<a name="%s"></a>\n' % anchor)
                        cf.write('#### `%s%s`\n\n' % (name, sig))
                        if parsed and parsed.get('summary'):
                            cf.write('%s\n\n' % parsed['summary'])
                        if ret:
                            cf.write('- **Signature return**: `%s`\n' % link_type(ret))
                        if parsed and parsed.get('returns'):
                            r = parsed['returns']
                            if r.get('type'):
                                cf.write('- **Return**: `%s` — %s\n' % (link_type(r.get('type')), r.get('desc')))
                            elif r.get('desc'):
                                cf.write('- **Return**: %s\n' % r.get('desc'))
                        if parsed and parsed.get('params'):
                            cf.write('\n**Params**:\n\n')
                            for pname, pinfo in parsed['params'].items():
                                ptype = pinfo.get('type','')
                                pdesc = pinfo.get('desc','')
                                if ptype:
                                    cf.write('- `%s` (`%s`): %s\n' % (pname, link_type(ptype), pdesc))
                                else:
                                    cf.write('- `%s`: %s\n' % (pname, pdesc))
                        cf.write('\n')

    # Generate an index file grouped by top-level module for easier browsing
    index_out = os.path.join(os.path.dirname(OUT), 'index.md')
    modules = {}
    for rel, cname, cdoc, funcs in sorted(entries):
        top = rel.split('/')[1] if '/' in rel else rel
        modules.setdefault(top, []).append((rel, cname))

    with open(index_out, 'w', encoding='utf-8') as idx:
        idx.write('# API Index\n\n')
        idx.write('This index links to per-class API pages in `docs/api/classes/` generated by `scripts/generate_api_docs.py`.\n\n')
        for m, items in sorted(modules.items()):
            idx.write('## %s\n\n' % m)
            for rel, cname in items:
                class_md_path = 'classes/' + os.path.splitext(rel)[0] + '.md'
                display = cname or rel
                idx.write('- [%s](%s)\n' % (display, class_md_path))
            idx.write('\n')


    print('Generated', OUT)


if __name__ == '__main__':
    main()
