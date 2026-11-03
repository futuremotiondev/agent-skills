#!/usr/bin/env python3
"""Apply Futuremotion's 2026-09-28 casing decisions to casing-dictionary.tsv (the _spec copy).

Each change is keyed by the row's current (term, source) so nothing else can match.
Writes the dictionary back in the file's own order (tier, pack, term casefold),
UTF-8 without BOM, LF, and an audit TSV of every change. Refuses to write if a
key is missing, a term would duplicate case-insensitively, or unchanged rows move.
"""
import csv, sys
from pathlib import Path

SKILL = Path(r'D:\AI\Skills\futuremotion\fm-renamer-preset-creator')
DICT = SKILL / '_spec' / 'data' / 'casing-dictionary.tsv'
AUDIT = SKILL / '_spec' / 'data' / 'expansion-2026-09-28' / 'casing-decisions-2026-09-28.tsv'
D = "Futuremotion's decision 2026-09-28"
TIER_ORDER = {'core': 0, 'proper': 1, 'review': 2}
FIELDS = ['term', 'tier', 'pack', 'source', 'note']

# (current term, current source) -> fields to set
CHANGES = {
    ('Puma', 'base'):     dict(tier='core', note=f'{D}: exact casing forced in title mode too (PUMA -> Puma)'),
    ('Gigabyte', 'base'): dict(tier='core', note=f'{D}: exact casing forced in title mode too (GIGABYTE -> Gigabyte)'),
    ('winget', 'base'):   dict(term='WinGet', note=f'{D}: WinGet (was winget)'),
    ('NX', 'legacy'):     dict(tier='core', pack='general', source='added', note=f'{D}: NX over Nx; promoted from legacy review'),
    ('SoC', 'base'):      dict(term='SOC', note=f'{D}: SOC (was SoC)'),
    ('SoCs', 'added'):    dict(term='SOCs', note='plural of SOC (was SoCs; follows the SOC decision)'),
    ('GAN', 'base'):      dict(term='GaN', note=f'{D}: GaN (was GAN; the plural GANs is unchanged)'),
    ('DB', 'legacy'):     dict(tier='core', pack='general', source='added', note=f'{D}: DB over dB; promoted from legacy review'),
    ('JS', 'legacy'):     dict(tier='core', pack='dev', source='added', note=f'{D}: promoted from legacy review'),
    ('RAM', 'base'):      dict(tier='core', note=f'{D}: auto-applied despite ram (animal/verb)'),
    ('DOM', 'base'):      dict(tier='core', note=f'{D}: auto-applied despite Dom (name)'),
    ('CI', 'added'):      dict(tier='core', note=f'{D}: auto-applied despite Italian ci and initials'),
}
# Already in the casing chosen: verified, left untouched
UNCHANGED = ['WASM', 'LoRA', 'README']


def key(r):
    return (TIER_ORDER[r['tier']], r['pack'], r['term'].casefold())


def main():
    text = DICT.read_text(encoding='utf-8')
    assert not text.startswith('\ufeff') and '\r' not in text, 'expected LF without BOM'
    rows = list(csv.DictReader(text.splitlines(), delimiter='\t', quoting=csv.QUOTE_NONE))
    before_order = [r['term'] for r in rows]
    audit, seen = [], set()
    for r in rows:
        ch = CHANGES.get((r['term'], r['source']))
        if not ch:
            continue
        seen.add((r['term'], r['source']))
        old = dict(r)
        r.update(ch)
        audit.append([old['term'], r['term'], f"{old['tier']}->{r['tier']}", f"{old['pack']}->{r['pack']}",
                      f"{old['source']}->{r['source']}", r['note']])
    missing = set(CHANGES) - seen
    assert not missing, f'rows not found: {missing}'
    for t in UNCHANGED:
        assert any(r['term'] == t and r['tier'] == 'core' and r['source'] in ('base', 'added') for r in rows), t
    folded = [r['term'].casefold() for r in rows]
    assert len(folded) == len(set(folded)), 'case-insensitive duplicate'
    rows.sort(key=key)
    # Unchanged rows must keep their relative order (the file was already sorted this way)
    changed = {a[1] for a in audit}
    after_unchanged = [r['term'] for r in rows if r['term'] not in changed]
    before_unchanged = [t for t in before_order if t not in {a[0] for a in audit}]
    assert after_unchanged == before_unchanged, 'unchanged rows moved: sort key differs from the file order'
    with open(DICT, 'w', encoding='utf-8', newline='\n') as o:
        o.write('\t'.join(FIELDS) + '\n')
        for r in rows:
            o.write('\t'.join(r[f] for f in FIELDS) + '\n')
    with open(AUDIT, 'w', encoding='utf-8', newline='\n') as o:
        o.write('old\tnew\ttier\tpack\tsource\tnote\n')
        for a in audit:
            o.write('\t'.join(a) + '\n')
    print(f'rows {len(rows)} changed {len(audit)}')
    for a in audit:
        print('  ' + ' | '.join(a[:5]))


if __name__ == '__main__':
    sys.exit(main())
