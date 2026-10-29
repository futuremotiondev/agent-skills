#!/usr/bin/env python3
"""Merge the five research TSVs, dedupe, and classify each candidate into the
skill's tiers (core / proper / review) using the same rules as the curation
report, strengthened with a Hunspell English dictionary:

  core    casing differs from ReNamer's Capitalize Every Word and the lowercase
          form is not an ordinary English word / common name
  proper  plain capitalized name (a no-op under Capitalize Every Word)
  review  collides with an ordinary word or name, 2-letter token, unverified
          casing, or agent-flagged COLLISION. Opt-in only; never auto-applied.

Writes classified.tsv (term, tier, pack, source, note, reason, conf, file) and
conflicts.tsv (case-insensitive duplicates with different casing).
"""
import csv, re, sys
from pathlib import Path
from collections import defaultdict
from wordfreq import zipf_frequency
from spylls.hunspell import Dictionary

HERE = Path(__file__).resolve().parent
HUN = Dictionary.from_files(str(HERE.parent / 'hun' / 'package' / 'index'))
FILES = ['acronyms', 'ai', 'dev', 'creative', 'brands']      # precedence on exact dupes
ILLEGAL = set('\\/:*?"<>|,')

# ── Hand decisions (from the agents' "unsure casing" lists and my review) ─────
FORCE_REVIEW = {  # term -> reason (casing unverified / ambiguous / collision)
    'TRAE': 'casing unverified (TRAE vs Trae)', 'Trae': 'casing unverified (TRAE vs Trae)',
    'OLMo': 'Ai2 switched to Olmo from v3', 'GPT-Image-1': 'API id is gpt-image-1', 'GPT-Image-2': 'API id is gpt-image-2',
    'PydanticAI': 'docs now say Pydantic AI', 'SigLIP2': 'official SigLIP 2', 'UMT5': 'also umT5', 'CodeLlama': 'official Code Llama',
    'SANA': 'Sana vs SANA', 'Instant-NGP': 'repo instant-ngp', 'LLaMA-Factory': 'now LlamaFactory', 'FluxGym': 'repo fluxgym',
    'ProducerAI': 'casing unverified', 'Jan.ai': 'official Jan', 'Hy3': 'low confidence', 'Mythos': 'low confidence',
    'Dia': 'low confidence', 'Canary': 'common word', 'Marker': 'common word', 'ReAct': 'collides with React', 'mAP': 'recases the word map',
    'OpenCode': 'repo is lowercase opencode', 'sourcehut': 'SourceHut also common', 'Mamba': 'common word (snake)',
    'kitty': 'common word; KiTTY collision', 'HardOps': 'official Hard Ops', 'mLUT': 'unverified', 'mTitle': 'unverified',
    'mTransition': 'unverified', 'CinePacks': 'unverified', 'CLO3D': 'unverified', 'Unfold3D': 'unverified', 'SubTool': 'unverified',
    'SubTools': 'unverified', 'DDPi': 'unverified', 'FX2': 'unverified product name', 'XP-PEN': 'rebranded to XPPen',
    'MicroLED': 'Samsung writes Micro LED', 'NAVI': 'Navi (name); rebranded 2023', 'BYOME': 'unverified', 'NOVO': 'unverified',
    'Apple TV+': 'renamed Apple TV (Oct 2025)', 'JioCinema': 'merged into JioHotstar',
}
# Parameter sizes 1B-9B are too generic (Chapter 2b, Part 3b)
for n in range(1, 10):
    FORCE_REVIEW[f'{n}B'] = 'generic short token (Part 3b)'
FORCE_REVIEW.update({'4X': 'multiplier (4x zoom)', 'EP': 'Ep = episode abbreviation', 'VW': 'CSS vw unit'})
# Generic concepts/commands: forcing lowercase breaks normal titles (same policy as async/regex)
for t in ['cron', 'crontab', 'sudo', 'nano', 'chroot', 'cgroups', 'coreutils', 'epoll', 'kqueue', 'dylib', 'cmdlets',
          'conhost', 'kubeconfig', 'devcontainer', 'gitattributes', 'gitconfig', 'gitmodules', 'node_modules',
          'pacman', 'sforzando', 'mise', 'spiff', 'exa', 'tox']:
    FORCE_REVIEW[t] = 'generic term; forcing lowercase breaks normal titles'
# Multi-word names that are also ordinary phrases, or all-caps logo stylings of titles
for t in ['The Pile', 'Zero Trust', 'Secure Boot', 'Server Core', 'Front Door', 'Hot Chocolate', 'Lip Gloss',
          'Bubble Tea', 'Night Owl', 'Red Hat', 'Check Point', 'Carbon Black', 'Home Assistant', 'Common Voice',
          'Dream Machine', 'Draw Things', 'Error Prone', 'Cloud Storage', 'SHIFT UP', 'DARK SOULS', 'ARMORED CORE',
          'FINAL FANTASY', 'DRAGON QUEST', 'THE FINALS', 'Muse Spark', 'Material You']:
    FORCE_REVIEW[t] = 'ordinary phrase or logo styling'
# Hunspell lists these abbreviations/brands as words or names, but they are safe acronyms/brands
RESCUE = {'VHF', 'UHF', 'EMF', 'MPG', 'CPL', 'PKG', 'INF', 'DDS', 'QR', 'ECU', 'EdS', 'NUS', 'SCAD', 'SWOT', 'CTR',
          'MYS', 'kW', 'kN', 'kg', 'km', 'mg', 'mph', 'kph', 'SOPs', 'COOs', 'ZIPs', 'MTG', 'HF', 'CG', 'AKA', 'DC',
          'CT', 'EA', 'PR', 'RF', 'ATS', 'EUR', 'JPN', 'MEX', 'GER', 'KB', 'MB', 'PB', 'PENTAX', 'LEGO', 'adidas'}
# Unambiguous official casings where I overrule an agent's choice, plus the fixes
# from the independent verification pass (3 auditor agents)
RENAME = {'Kimi-K2': 'Kimi K2', 'DVDScr': 'DVDSCR', 'LoFi': 'Lofi', 'CS224n': 'CS224N', 'ATProto': 'atproto',
          'Base64URL': 'base64url', 'Bunny.net': 'bunny.net', 'NETELLER': 'Neteller', 'VideoBlocks': 'Videoblocks',
          'AudioBlocks': 'Audioblocks', 'Ingress-NGINX': 'ingress-nginx', 'FOGRA': 'Fogra', 'BATTLETECH': 'BattleTech'}
# Collisions the auditors found (foreign function words, given names, lowercase dev tokens, audio 'vox')
for t in ['SSHD', 'LOL', 'NAV', 'TSX', 'WWW', 'ToS', 'iLO', 'THA', 'ARS', 'CAO', 'GAO', 'HOA', 'LoRo', 'ESO', 'ESA',
          'ILS', 'FRA', 'SOM', 'CERO', 'GERD', 'DAO', 'EIS', 'TEM', 'BOM', 'GBR', 'PTE', 'ACH', 'NUMA', 'VoLTE', 'LOI',
          'CET', 'CEST', 'COPPA', 'DELE', 'MENA', 'ONS', 'ROC', 'PKG', 'IMG', 'ITIN', 'ABR', 'AKA', 'hPa', 'NeMo',
          'SRI', 'TODO', 'TODOs', 'AMO', 'UNO', 'NIM', 'BLEU', 'AIME', 'WER', 'LoRAX', 'YuE', 'GRU', 'MyST',
          'LoopBack', 'NeRFs', 'HuMo', 'SIE', 'DER', 'ELLE', 'CELINE', 'ALEXA', 'TCL', 'VOX', 'POCO', 'POCOs', 'REI',
          'vivo', 'VIVE', 'HITMAN', 'WorkSpaces', 'EVO', 'SoX', 'REQ', 'CSH', 'OPA', 'MITRE', 'AIX', 'WEBTOON',
          'PlayMaker', 'UltraFine', 'AMI', 'AMIs', 'SAI', 'KOMODO', 'AMIRA', 'BURANO', 'RAVENNA', 'BlackHole',
          'KRONOS', 'MainStage', 'YARA', 'NYX', 'ATEM', 'MAPPA', 'FILA', 'beIN', 'MONSTRO', 'DUPLO', 'KEV', 'DiDi',
          'DeX', 'reface', 'RND', 'CI', 'CAPA', 'ATO', 'DEU', 'paru', 'ASI', 'CRI', 'EET', 'ENIG', 'ToF', 'DACH',
          'SAU', 'KANs', 'BEM', 'AUS', 'POR', 'IST', 'DEI',
          'ABD', 'CAS', 'MEng', 'MPS', 'PPL', 'WAI', 'UVA']:   # + differential test (8,613 real-word titles)
    FORCE_REVIEW.setdefault(t, 'collision found in verification (foreign word, given name or common token)')
# User-requested additions (always core)
USER_CORE = {'PS': 'user-requested: Photoshop / PlayStation / PostScript; almost always capitalized'}
# 2-letter tokens (no digits, no & or +) that are still safe to auto-apply:
# their lowercase form is not a word and they are almost always written in caps
SHORT_OK = {'PS', 'AR', 'VR', 'XR', 'XT', 'HF', 'KV', 'VL', 'Ti', 'UV', 'GB', 'UK', 'CV', 'DL', 'HQ', 'GQ',
            'MV', 'OC', 'RL', 'UE', 'AE', 'EF', 'FY', 'QC', 'CX'}
# Cross-file casing conflicts (same letters, different casing): the casing that wins
CONFLICT_WINNER = {w.lower(): w for w in [
    'A-roll', 'B-roll', 'Apex', 'Apple silicon', 'ARCTIC', 'ASICs', 'AUTOMATIC1111', 'Bluesky', 'Bria', 'COD', 'Corp',
    'DBA', 'Elysia', 'Expo', 'FLOPS', 'GPOs', 'Helm', 'hPa', 'IdP', 'IndyCar', 'IoC', 'IoU', 'IRs', 'KV', 'Lit', 'LOL',
    'mg', 'MIMO', 'Moq', 'MPa', 'NeRF', 'Nerfstudio', 'NIM', 'NYC', 'PENTAX', 'Pest', 'PiP', 'PKL', 'PoE', 'React',
    'ROC', 'SOPs', 'SoX', 'SSHD', 'SSMS', 'Swift', 'TLDR', 'TRAE', 'UV', 'Yarn']}

def cap_every_word(s):
    """Emulate ReNamer Case WHAT=3 on a lowercased string: a word starts after
    space _ - . ( [ ; digit-led tokens are not capitalized; apostrophe is not a start."""
    out, start = [], True
    for ch in s:
        if start and ch.isalpha():
            out.append(ch.upper()); start = False
        else:
            out.append(ch)
            if ch in ' _-.([':
                start = True
            elif ch.isalnum():
                start = False
    return ''.join(out)

def is_word(w):   # ordinary lowercase English word (Hunspell accepts the lowercase form)
    return w.isalpha() and HUN.lookup(w)

def is_name(w):   # capitalized proper noun (Nat, Ted, Claude) but not an ordinary word
    return w.isalpha() and not HUN.lookup(w) and HUN.lookup(w.capitalize())

def classify(term, conf, note):
    low = term.lower()
    toks = term.split()
    letters = sum(c.isalpha() for c in term)
    trivial = cap_every_word(low) == term
    z = zipf_frequency(low, 'en')
    if term in USER_CORE:
        return 'core', ''
    if term in FORCE_REVIEW:
        return 'review', FORCE_REVIEW[term]
    if term in RESCUE:
        return ('proper' if trivial else 'core'), ''
    if conf == 'low':
        return 'review', 'low-confidence casing'
    if re.search(r'-(?:to|of|as|a|in|the|and|for)-', term) and not trivial:
        return 'review', 'concept phrase; would recase kebab-case slugs'
    if re.search(r'\bCOLLISION\b', note):
        return 'review', 'agent-flagged collision'
    if len(toks) == 1:
        if is_word(low) and z >= 2.0:
            return 'review', f'lowercase form is an ordinary word (zipf {z:.1f})'
        if not trivial and is_name(low) and z >= 2.5:
            return 'review', f'collides with a common name (zipf {z:.1f})'
        distinctive = any(c.isdigit() or c in '&+' for c in term)   # SM58, i7, P&L, HD+
        if letters <= 2 and not distinctive and term not in SHORT_OK:
            return 'review', 'short token (high collision risk)'
    # multi-word names: phrase-level collisions are rare; generic ones are in FORCE_REVIEW
    if not trivial and term[0].islower() and not term[-1].isalnum():
        return 'review', 'lowercase-start term ending in punctuation (breaks the title <LC> guard)'
    return ('proper' if trivial else 'core'), ''

def main():
    dict_path = '/mnt/skills/plugins/fm-renamer-preset-creator/data/casing-dictionary.tsv'
    existing = {r['term'].lower() for r in csv.DictReader(open(dict_path, encoding='utf-8'), delimiter='\t')}
    seen, conflicts, rows, dropped = {}, defaultdict(set), [], []
    for f in FILES:
        for r in csv.DictReader(open(HERE / f'{f}.tsv', encoding='utf-8'), delimiter='\t'):
            term = re.sub(r'\s+', ' ', r['term']).strip()
            term = RENAME.get(term, term)
            if (not term or any(c in ILLEGAL for c in term) or term.lower() in existing
                    or not any(c.isalpha() for c in term)):          # pure numbers: casing can't change them
                dropped.append((term, f)); continue
            key = term.lower()
            conflicts[key].add(term)
            if key in CONFLICT_WINNER and term != CONFLICT_WINNER[key]:
                continue                      # hand-picked winner of a casing conflict
            if key in seen:
                continue                      # first file wins on case-insensitive dupes
            seen[key] = term
            rows.append(dict(term=term, pack=r['pack'].strip(), conf=r['confidence'].strip(),
                             note=r['note'].strip(), file=f))
    for t, note in USER_CORE.items():                  # make sure user-requested terms exist
        if t.lower() not in seen and t.lower() not in existing:
            seen[t.lower()] = t
            rows.append(dict(term=t, pack='general', conf='high', note=note, file='user'))
    for row in rows:
        row['tier'], row['reason'] = classify(row['term'], row['conf'], row['note'])
    with open(HERE / 'classified.tsv', 'w', encoding='utf-8', newline='') as o:
        w = csv.writer(o, delimiter='\t', lineterminator='\n')
        w.writerow(['term', 'tier', 'pack', 'conf', 'file', 'reason', 'note'])
        for r in rows:
            w.writerow([r['term'], r['tier'], r['pack'], r['conf'], r['file'], r['reason'], r['note']])
    with open(HERE / 'conflicts.tsv', 'w', encoding='utf-8') as o:
        for k, v in sorted(conflicts.items()):
            if len(v) > 1:
                o.write(k + '\t' + ' | '.join(sorted(v)) + '\t kept: ' + seen[k] + '\n')
    from collections import Counter
    print('rows', len(rows), 'dropped', len(dropped))
    print(Counter(r['tier'] for r in rows))
    print(Counter((r['file'], r['tier']) for r in rows))
    print('conflicts', sum(len(v) > 1 for v in conflicts.values()))

if __name__ == '__main__':
    main()
