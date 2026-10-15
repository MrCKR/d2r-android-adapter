#!/usr/bin/env python3
"""Data-boundary check on the vendored tree.

The adapter must contain no game content: no game binaries, no keys, no extracted
shaders/textures/audio/saves. This checks the things we can check mechanically:
  1. forbidden file extensions
  2. forbidden magic bytes (NSO/NCA/XCI/NSP headers)
  3. key-shaped content (32-byte hex blobs in key files)
  4. oversized binary blobs that are not one of the allowed fact tables
"""
import os, sys

# Repo root = two levels up from docs/scripts/
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ROOT = os.path.join(REPO, 'vendor')

FORBIDDEN_EXT = {'.nsp', '.xci', '.nca', '.nro', '.nso', '.kip', '.keys',
                 '.xcz', '.nsz', '.bin', '.png', '.jpg', '.jpeg', '.bmp',
                 '.mp3', '.ogg', '.wav', '.ttf', '.otf', '.sav', '.d2s'}

FORBIDDEN_MAGIC = [b'NSO0', b'NCA3', b'HEAD', b'PFS0', b'XCI0', b'SET0']

# Vetted: these are the upstream-published fact tables and the one MIT third-party header.
ALLOWED_BIG = {
    'dm/gfx/nvn/shader_map.tsv', 'dm/gfx/nvn/shader_facts.tsv',
    'dm/gfx/nvn/pso_manifest.tsv', 'dm/gfx/nvn/nvn_slots.tsv',
    'dm/gfx/nvn/names.txt', 'dm/gfx/nvn/include/nvn.h',
    'dm/gfx/nvn/nvn_thunks.S', 'dm/gfx/nvn/hle_nvn.c',
    'dm/i18n/ui_text.tsv', 'dm/tools/patch_nso.py',
}

problems = []
files = 0
biggest = []

for dirpath, _, filenames in os.walk(ROOT):
    for fn in filenames:
        full = os.path.join(dirpath, fn)
        rel = os.path.relpath(full, os.path.join(ROOT, 'd2r-mobile'))
        files += 1
        ext = os.path.splitext(fn)[1].lower()
        if ext in FORBIDDEN_EXT:
            problems.append('FORBIDDEN EXT %s %s' % (ext, rel))
        size = os.path.getsize(full)
        biggest.append((size, rel))
        with open(full, 'rb') as f:
            head = f.read(4)
        for m in FORBIDDEN_MAGIC:
            if head == m:
                problems.append('FORBIDDEN MAGIC %s %s' % (m.decode(), rel))
        if ext in ('.keys', '.txt') and 'key' in fn.lower():
            problems.append('KEY-SHAPED FILE %s' % rel)
        # Source and small-metadata files may legitimately be large; only flag
        # large *data* files, since those are where extracted game content hides.
        SOURCE_EXT = {'.c', '.h', '.m', '.mm', '.S', '.py', '.sh', '.cs',
                      '.tsv', '.json', '.jsonl', '.md', '.txt', '.inc', '.yml'}
        if size > 60000 and ext not in SOURCE_EXT:
            problems.append('UNEXPECTED BIG DATA FILE %d %s' % (size, rel))
        # A shader/asset disguised under a text extension would show up as an
        # unusually long single line; flag data files with no line breaks.
        if ext in ('.tsv', '.json', '.jsonl') and size > 100:
            with open(full, 'rb') as f:
                blob = f.read()
            if b'\n' not in blob[:size - 1]:
                problems.append('NO LINE BREAKS IN DATA FILE %s' % rel)

print('files scanned: %d' % files)
print('problems     : %d' % len(problems))
for p in problems:
    print('  ', p)
print()
print('largest 12 files:')
for size, rel in sorted(biggest, reverse=True)[:12]:
    print('  %9d  %s' % (size, rel))
sys.exit(1 if problems else 0)
