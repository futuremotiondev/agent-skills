#!/usr/bin/env python3
"""Build the updated casing-dictionary.tsv:
  1. existing rows, with verified casing corrections applied (tier recomputed unless the
     row was already 'review'; the note records the old casing),
  2. + the classified research rows as source 'added',
then validate (no case-insensitive duplicates, no illegal characters, no commas, no
APA minor words) and write in the file's own order: tier (core, proper, review),
then pack, then term (case-insensitive). UTF-8, no BOM, LF, trailing newline.
"""
import csv, sys
from pathlib import Path
from collections import Counter

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from classify import classify, cap_every_word          # same tier rules as the new rows

SKILL = Path('/mnt/skills/plugins/fm-renamer-preset-creator')
OUT = Path('/mnt/user-data/outputs/dict-update')
DATE = '2026-09-28'

# Verified corrections to existing entries (old -> new). Sources: official sites, per the research reports.
CORRECTIONS = {
    'IMDB': 'IMDb', '4Chan': '4chan', '9Gag': '9GAG', 'PCloud': 'pCloud', 'FreeCodeCamp': 'freeCodeCamp',
    'JAMstack': 'Jamstack', 'SourceTree': 'Sourcetree', 'XFCE': 'Xfce', 'BTRFS': 'Btrfs', 'RClone': 'rclone',
    'JSDelivr': 'jsDelivr', 'nmap': 'Nmap', 'CryEngine': 'CRYENGINE', 'AIOHTTP': 'aiohttp', 'cURL': 'curl',
    'VCard': 'vCard', 'ZigBee': 'Zigbee', 'u-He': 'u-he', 'SoundToys': 'Soundtoys', 'DECALMachine': 'DECALmachine',
    'MESHmashine': 'MESHmachine', 'LaunchPad': 'Launchpad', 'HDRi': 'HDRI', 'Sci-FI': 'Sci-Fi',
    'Kitbash3D': 'KitBash3D', 'Soothe2': 'soothe2', 'Aescripts': 'aescripts', 'C-LOG': 'C-Log', 'DNB': 'DnB',
    'FlyDubai': 'flydubai', 'DirecTV': 'DIRECTV', 'MII': 'Mii',
}
TIER_ORDER = {'core': 0, 'proper': 1, 'review': 2}
ILLEGAL = set('\\/:*?"<>|,\t')

def short(note, n=110):
    note = ' '.join(note.split())
    return note if len(note) <= n else note[:n - 1].rstrip() + '…'

def main():
    fields = ['term', 'tier', 'pack', 'source', 'note']
    rows = list(csv.DictReader(open(SKILL / 'data/casing-dictionary.tsv', encoding='utf-8'), delimiter='\t'))
    # 1. corrections
    fixed = []
    for r in rows:
        new = CORRECTIONS.get(r['term'])
        if new:
            old = r['term']
            r['term'] = new
            if r['tier'] != 'review':
                t, _ = classify(new, 'high', '')
                r['tier'] = 'proper' if t == 'proper' else ('core' if t == 'core' else r['tier'])
            r['note'] = (r['note'] + '; ' if r['note'] else '') + f'casing corrected from {old} ({DATE})'
            fixed.append((old, new, r['tier'], r['source']))
    assert len(fixed) == len(CORRECTIONS), set(CORRECTIONS) - {f[0] for f in fixed}
    # 2. new rows
    added = []
    for c in csv.DictReader(open(HERE / 'classified.tsv', encoding='utf-8'), delimiter='\t'):
        note = c['reason'] if c['tier'] == 'review' else c['note']
        if c['term'] == 'PS':
            note = "user-requested: Photoshop / PlayStation / PostScript; almost always capitalized"
        added.append({'term': c['term'], 'tier': c['tier'], 'pack': c['pack'], 'source': 'added', 'note': short(note)})
    # A corrected legacy typo that the research already added as a clean 'added' row: keep the added row
    added_keys = {a['term'].casefold() for a in added}
    superseded = [r for r in rows if 'casing corrected' in r['note'] and r['term'].casefold() in added_keys]
    rows = [r for r in rows if r not in superseded]
    for r in superseded:
        print(f"  superseded by the new added row: {r['term']} ({r['source']}, {r['note']})")
    allrows = rows + added
    # 3. validation (new rows that are APA minor words would be dropped by the builder anyway: drop them here)
    minor = {l.strip() for l in open(SKILL / 'data/apa-minor-words.txt', encoding='utf-8') if l.strip() and not l.startswith('#')}
    dropped_minor = [a['term'] for a in added if a['term'].lower() in minor]
    added = [a for a in added if a['term'].lower() not in minor]
    allrows = rows + added
    print('  dropped (APA minor words):', dropped_minor)
    dup = [k for k, v in Counter(r['term'].casefold() for r in allrows).items() if v > 1]
    bad = [r['term'] for r in added if not r['term'] or any(c in ILLEGAL for c in r['term'])
           or r['term'] != r['term'].strip()]
    badtier = [r['term'] for r in allrows if r['tier'] not in TIER_ORDER]
    assert not dup, f'case-insensitive duplicates: {dup[:20]}'
    assert not bad, f'invalid terms: {bad[:20]}'
    assert not badtier, badtier[:20]
    # 4. write in the file's order
    allrows.sort(key=lambda r: (TIER_ORDER[r['tier']], r['pack'], r['term'].casefold()))
    OUT.mkdir(parents=True, exist_ok=True)
    with open(OUT / 'casing-dictionary.tsv', 'w', encoding='utf-8', newline='') as o:
        o.write('\t'.join(fields) + '\n')
        for r in allrows:
            o.write('\t'.join(r[f] for f in fields) + '\n')
    with open(OUT / 'corrections.tsv', 'w', encoding='utf-8', newline='') as o:
        o.write('old\tnew\ttier\tsource\n' + ''.join('\t'.join(f) + '\n' for f in fixed))
    c = Counter((r['source'], r['tier']) for r in allrows)
    print('rows', len(allrows), 'added', len(added), 'corrected', len(fixed))
    for s in ('base', 'added', 'legacy'):
        print(f"  {s:7} core {c[(s,'core')]:5}  proper {c[(s,'proper')]:5}  review {c[(s,'review')]:5}")
    print('  packs (added):', dict(Counter(r['pack'] for r in added).most_common()))

if __name__ == '__main__':
    main()
