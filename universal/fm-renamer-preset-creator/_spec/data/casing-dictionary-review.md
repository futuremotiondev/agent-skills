# Casing dictionary — curation report

`casing-dictionary.tsv` is the **single source of truth** for special casing. It replaces the comma list embedded in the old
spec and in the "Main Case" rule of Jay's `00 Clean Up Filename` presets. The builder turns a selection of it into
`FRAGMENTSTEXT` at build time, so nobody ever hand-maintains a 2,000-word comma string again.

## Sources

| source | origin | trust |
|---|---|---|
| `base` | Jay's live "Main Case" fragment list (2,171 entries = the old spec's list + `and`) | reviewed by Jay over time |
| `added` | New entries curated for this spec: acronym plurals, AI/ML, dev, design, audio, media/codec, file-format, Apple | hand-checked official casings |
| `legacy` | The 8 fragment lists in the 9 Case rules of the disabled `Presets Disabled\00 Cleanup Presets\00 SMART Clean Up.rnp` (last saved 2024-12-14; its SMART siblings carry copies of the same lists): tech/Windows, audio plug-ins, media/LUT/camera, design sites, brands, Roman numerals. 3,699 raw entries became 3,103 rows after removing terms already in `base`/`added`, duplicates and invalid characters | tiers assigned by script rules (below), **not checked by hand** |

Precedence on case-insensitive conflicts: `base` > `added` > `legacy` (all 45 conflicts are listed below).

**How the `legacy` rows were classified** (script rules, no human review): ALL-CAPS and CamelCase terms → `core`, unless they have at most 2 letters (`VA`, `XP` → `review`) or their lowercase form is a common English word (wordfreq zipf ≥ 3.0 → `review`). Plain Capitalized terms → `proper`, or `review` when they are common English words (zipf ≥ 3.5). All-lowercase entries → `review`. Roman numerals → `review`, pack `roman`. Packs were named from each list's content: rule 13 (65 vendor names) and rules 42/47 (media formats, LUT/camera terms) → `media`, rule 17 (2,247) → `legacy-tech`, rule 18 (1,238) → `audio`, rule 19 (12) → `design`, rule 20 (9) → `brand`, rule 29 (92) → `roman`. None of these rows are used by default.

## Tiers and default selection

| tier | meaning | when the builder includes it |
|---|---|---|
| `core` | Non-trivial casing that Capitalize Every Word can't produce (`GitHub`, `iOS`, `HTML`, `npm`, `.NET`) and that doesn't collide with an ordinary English word | **Always**, in every casing-preserving pipeline (title, sentence, preserve) |
| `proper` | Plain capitalized names (`Google`, `Blender`, `Logic Pro`): a no-op under Capitalize Every Word | Only in **sentence-case** and **preserve-case** pipelines, where they actually change something |
| `review` | Collides with an ordinary word or name (`Apple`/apple, `Word`, `Spring`), generic code terms (`async`, `regex`), short ALL-CAPS legacy tokens (`ST`, `PM`), Roman numerals | **Never by default.** Only when a preset's domain clearly warrants it (e.g. `VOX` for a vocal-sample folder), named explicitly in the request or by the skill with a stated reason |

**Default selection** = `source in (base, added)` AND `tier in (core, proper)` for preserve and sentence modes, `tier = core` for title mode. Opt-in packs per request: `audio`, `media`, `design`, `legacy-tech`, `brand`, `roman`, `code`. The full, deterministic selection algorithm (opt-ins, review terms, dedupe, sort) is SPEC §7.2.

File format: tab-separated, UTF-8, one header row (`term tier pack source note`), no comment lines.

## Counts

After the 2026-09-28 expansion and Jay's casing decisions (both sections at the end; the original v2.1 counts were
5,646 rows: base 1631/452/84, added 261/100/15, legacy 2470/117/516; straight after the expansion: base 1627/456/84,
added 6564/2646/1049, legacy 2465/121/516):

| source \ tier | core | proper | review | total |
|---|---|---|---|---|
| base | 1631 | 454 | 82 | 2167 |
| added | 6568 | 2646 | 1048 | 10262 |
| legacy | 2465 | 121 | 513 | 3099 |
| **total** | 10664 | 3221 | 1643 | **15528** |

## What changed versus the old list
- **Removed `and`** from the brand dictionary. Minor words belong to the title-case pipeline, which handles the first- and last-word exceptions. As a plain fragment, `and` also lowercased a leading "And".
- **Removed 3 exact duplicates:** TailwindCSS, FSharp, AirAsia.
- **Moved 84 base entries to `review`** (full list below). Examples: `RAM`, `WAN`, `RAG`, `TED`, `DOM`, `NAT`, `SAP`, `MAUI`, `ReFS`, `DoS`, `SF`, generic code words (`async`, `regex`, `stdin`, `localhost`), and common-word brands (`Apple`, `Word`, `Box`, `Spring`, `Windows`, `Excel`, `Outlook`, `Slack`, `Python`). In a preserve-case pipeline these would change ordinary words ("a ram skull" → "a RAM skull"; "async" in a normal title stays lowercase instead of capitalizing).
- **Added 376 reviewed entries.** Acronym plurals were the biggest gap: `API` never matches `APIs` (verified), and neither `iPhone` nor `MacBook` was present at all.
- **Dropped 5 entries containing characters that can't occur in filenames** (TCP/IP (legacy), S/PDIF (legacy), I/O (legacy), D/A (legacy), Mid/Side (legacy)) and 9 fragments with leading or trailing punctuation (com. (legacy), de. (legacy), dev. (legacy), im. (legacy), io. (legacy), net. (legacy), org. (legacy), SEQ- (legacy), A.O.M. (legacy)).

## Decisions for Jay
1. **Legacy packs:** 2470 legacy entries auto-classified as `core` (plug-in names, Windows tools, audio gear) are available as opt-in packs, not the default. Promote the packs you trust by changing their `source` to `base`.
2. **Review tier:** skim the 84 base items below. Anything you want auto-applied again, set `tier` to `core` (or `proper`).
3. **Brand styling calls** worth confirming: `REAPER`, `KORG` (official all-caps styling), `Valhalla DSP`, `3ds Max` (base also has `3dsMax`), `IMDB` (official `IMDb`, legacy), `cURL` (now officially `curl`, legacy), `EPUB` (was `EPub` in legacy).

## Base entries moved to review
| term | reason |
|---|---|
| `Amino` | ordinary English word (zipf 3.7) |
| `Apple` | ordinary English word (zipf 4.8) |
| `async` | generic code term; forcing lowercase breaks normal titles |
| `BIOS` | bios (plural of bio) |
| `Box` | ordinary English word (zipf 5.0) |
| `Brackets` | ordinary English word (zipf 3.6) |
| `Brave` | ordinary English word (zipf 4.3) |
| `Brother` | ordinary English word (zipf 5.1) |
| `Chase` | ordinary English word (zipf 4.4) |
| `China` | ordinary English word (zipf 5.1) |
| `cmdlet` | generic code term; forcing lowercase breaks normal titles |
| `Cockpit` | ordinary English word (zipf 3.6) |
| `Composer` | ordinary English word (zipf 3.9) |
| `Consul` | ordinary English word (zipf 3.6) |
| `Crystal` | ordinary English word (zipf 4.4) |
| `Discourse` | ordinary English word (zipf 3.8) |
| `Doctrine` | ordinary English word (zipf 4.0) |
| `DOM` | Dom (name) — back to `core` on 2026-09-28 (Jay's decision) |
| `DoS` | DOS (MS-DOS) vs DoS (attack) |
| `dotfiles` | generic code term; forcing lowercase breaks normal titles |
| `Drip` | ordinary English word (zipf 3.6) |
| `Excel` | ordinary English word (zipf 3.7) |
| `FAG` | offensive lowercase collision |
| `falsy` | generic code term; forcing lowercase breaks normal titles |
| `Fidelity` | ordinary English word (zipf 3.5) |
| `Ford` | ordinary English word (zipf 4.5) |
| `Giant` | ordinary English word (zipf 4.6) |
| `gitignore` | generic code term; forcing lowercase breaks normal titles |
| `goroutine` | generic code term; forcing lowercase breaks normal titles |
| `Guardian` | ordinary English word (zipf 4.3) |
| `Intel` | ordinary English word (zipf 4.1) |
| `Kick` | ordinary English word (zipf 4.7) |
| `libc` | generic code term; forcing lowercase breaks normal titles |
| `localhost` | generic code term; forcing lowercase breaks normal titles |
| `Marvel` | ordinary English word (zipf 4.2) |
| `MAUI` | Maui (island) |
| `Maze` | ordinary English word (zipf 3.6) |
| `Meta` | ordinary English word (zipf 3.7) |
| `NAT` | Nat (name) |
| `Notion` | ordinary English word (zipf 4.2) |
| `Opera` | ordinary English word (zipf 4.3) |
| `Oracle` | ordinary English word (zipf 3.7) |
| `Outlook` | ordinary English word (zipf 4.1) |
| `PAX` | pax (Latin) |
| `Pioneer` | ordinary English word (zipf 3.9) |
| `Python` | ordinary English word (zipf 3.8) |
| `RAG` | rag (cloth) |
| `Rails` | ordinary English word (zipf 3.8) |
| `RAM` | ram (animal/verb) — back to `core` on 2026-09-28 (Jay's decision) |
| `ReFS` | refs (English) |
| `regex` | generic code term; forcing lowercase breaks normal titles |
| `regexp` | generic code term; forcing lowercase breaks normal titles |
| `Replicate` | ordinary English word (zipf 3.5) |
| `Ring` | ordinary English word (zipf 4.8) |
| `SAP` | sap (noun) |
| `SES` | Spanish word; rare as AWS SES |
| `SF` | ambiguous (San Francisco / sci-fi / SF Symbols) |
| `Sharp` | ordinary English word (zipf 4.5) |
| `Sketch` | ordinary English word (zipf 4.0) |
| `Slack` | ordinary English word (zipf 3.7) |
| `snake_case` | generic code term; forcing lowercase breaks normal titles |
| `Spring` | ordinary English word (zipf 4.9) |
| `Stash` | ordinary English word (zipf 3.5) |
| `stderr` | generic code term; forcing lowercase breaks normal titles |
| `stdin` | generic code term; forcing lowercase breaks normal titles |
| `stdlib` | generic code term; forcing lowercase breaks normal titles |
| `stdout` | generic code term; forcing lowercase breaks normal titles |
| `Steam` | ordinary English word (zipf 4.5) |
| `Stripe` | ordinary English word (zipf 3.5) |
| `Surge` | ordinary English word (zipf 3.8) |
| `Sway` | ordinary English word (zipf 3.6) |
| `TED` | Ted (name) |
| `Telegram` | ordinary English word (zipf 3.5) |
| `truthy` | generic code term; forcing lowercase breaks normal titles |
| `Twitch` | ordinary English word (zipf 3.8) |
| `Valve` | ordinary English word (zipf 4.1) |
| `Vans` | ordinary English word (zipf 3.6) |
| `Vault` | ordinary English word (zipf 3.9) |
| `venv` | generic code term; forcing lowercase breaks normal titles |
| `Visa` | ordinary English word (zipf 4.1) |
| `Vogue` | ordinary English word (zipf 3.7) |
| `WAN` | wan (pale) |
| `Windows` | ordinary English word (zipf 4.7) |
| `Word` | ordinary English word (zipf 5.3) |

## Added entries that start in review
| term | reason |
|---|---|
| `Biome` | ordinary English word (zipf 2.7) |
| `DOC` | doc (English) |
| `Drizzle` | ordinary English word (zipf 3.1) |
| `Glyphs` | ordinary English word (zipf 2.7) |
| `Illustrator` | ordinary English word (zipf 3.5) |
| `MD` | md is also a common abbreviation |
| `Neon` | ordinary English word (zipf 3.6) |
| `Neutron` | ordinary English word (zipf 3.4) |
| `Ozone` | ordinary English word (zipf 3.4) |
| `RAW` | raw (English) |
| `Serum` | ordinary English word (zipf 3.7) |
| `Splice` | ordinary English word (zipf 2.9) |
| `TAR` | tar (English) |
| `Topaz` | ordinary English word (zipf 2.9) |
| `ZIP` | zip (English) |

## Added entries by pack
- **ai** (41): `A2A`, `AlphaFold`, `AlphaGo`, `AnimateDiff`, `AutoGen`, `DALL-E`, `DeepMind`, `DSPy`, `ElevenLabs`, `FastMCP`, `GGML`, `GGUF`, `GitHub Copilot`, `GPT-4`, `GPT-4o`, `GPT-5`, `HeyGen`, `IP-Adapter`, `JAX`, `LangGraph`, `LangSmith`, `llama.cpp`, `LM Studio`, `MCP`, `Mixtral`, `MLflow`, `NotebookLM`, `NPU`, `OpenRouter`, `OpenVINO`, `QLoRA`, `RoBERTa`, `safetensors`, `scikit-learn`, `SDXL`, `TensorBoard`, `TensorRT`, `TorchScript`, `UNet`, `VAE`, `vLLM`
- **apple** (15): `AirPods`, `AirTag`, `FaceTime`, `Final Cut Pro`, `GarageBand`, `iCloud`, `iMac`, `iMessage`, `iMovie`, `iPhone`, `iPod`, `iWork`, `MacBook`, `MacBook Air`, `MacBook Pro`
- **audio** (64): `AAC`, `Ableton Live`, `Antares`, `Arturia`, `Auto-Tune`, `Bandcamp`, `Beatport`, `Bitwig`, `Brainworx`, `Celemony`, `Cubase`, `Cymatics`, `dBFS`, `dBTP`, `Discogs`, `Eventide`, `FL Studio`, `FMOD`, `Keyscape`, `Komplete`, `Kontakt`, `KORG`, `LANDR`, `Logic Pro`, `LUFS`, `Maschine`, `Max for Live`, `Melodyne`, `Mixcloud`, `MPE`, `Native Instruments`, `Neutron`, `Neve`, `Nuendo`, `oeksound`, `Omnisphere`, `Ozone`, `Plugin Alliance`, `Pro Tools`, `Pro-C`, `Pro-L`, `Pro-Q`, `Pro-R`, `REAPER`, `Roland`, `Serum`, `Slate Digital`, `Soothe2`, `SoundCloud`, `Soundiron`, `Spectrasonics`, `Spitfire Audio`, `Splice`, `Studio One`, `TB-303`, `TR-808`, `TR-909`, `Traxsource`, `UAD`, `Universal Audio`, `Valhalla DSP`, `WaveLab`, `Wwise`, `Xfer`
- **design** (60): `3DOcean`, `3ds Max`, `Adobe Firefly`, `Adobe XD`, `Affinity Designer`, `Affinity Photo`, `Affinity Publisher`, `After Effects`, `ArtStation`, `AudioJungle`, `Awwwards`, `Behance`, `C4D`, `Cinema 4D`, `CodeCanyon`, `Codrops`, `Creative Market`, `DeviantArt`, `Dribbble`, `Eagle.cool`, `Elementor`, `Envato Elements`, `FigJam`, `Font Awesome`, `FontAwesome`, `FontBase`, `Glyphs`, `GraphicRiver`, `Heroicons`, `Iconify`, `IconScout`, `Illustrator`, `iStock`, `KeyShot`, `Ko-fi`, `Krea`, `Krita`, `Lightroom Classic`, `LottieFiles`, `Magnific`, `Mobbin`, `MyFonts`, `OctaneRender`, `OFL`, `Pexels`, `PhotoDune`, `Pixabay`, `Premiere Pro`, `Procreate`, `PureRef`, `Recraft`, `Squarespace`, `ThemeForest`, `Typekit`, `UE5`, `Unreal Engine`, `Unsplash`, `VideoHive`, `Webflow`, `ZBrush`
- **dev** (53): `.NET`, `ASP.NET`, `Astro`, `Biome`, `C#`, `C++`, `Chart.js`, `Cloudflare Workers`, `D3.js`, `Drizzle`, `Eleventy`, `Express.js`, `EXR`, `F#`, `FBX`, `Framer Motion`, `GitHub Actions`, `GitHub Pages`, `GitLab CI`, `GLB`, `glTF`, `GSAP`, `Headless UI`, `Hugo`, `Jekyll`, `MS-DOS`, `Neon`, `Netlify`, `Next.js`, `Node.js`, `Nuxt.js`, `Objective-C`, `OpenEXR`, `OpenXR`, `PBR`, `Qwik`, `R2`, `Radix UI`, `S3`, `shadcn`, `Socket.IO`, `SQL Server`, `T-SQL`, `TanStack`, `Three.js`, `Turborepo`, `USDZ`, `Vitest`, `VS Code`, `Vue.js`, `WebGL2`, `WebXR`, `Zod`
- **formats** (55): `2D`, `3D`, `AIFF`, `ARW`, `AVI`, `AZW3`, `CBR`, `CBZ`, `CR2`, `CR3`, `DIY`, `DJ`, `DMG`, `DNG`, `DOC`, `DOCX`, `EPS`, `EPUB`, `EQ`, `EXE`, `FAQ`, `FLAC`, `HD`, `HEIC`, `ICO`, `IPA`, `ISO`, `M4A`, `MD`, `MKV`, `MOBI`, `MOV`, `MP3`, `MP4`, `NEF`, `OBJ`, `OGG`, `PC`, `PDF`, `PPT`, `PPTX`, `PSD`, `RAR`, `RAW`, `RTF`, `STL`, `TAR`, `TV`, `TXT`, `UHD`, `WAV`, `WMV`, `XLS`, `XLSX`, `ZIP`
- **media** (42): `1080p`, `2160p`, `4K`, `720p`, `8K`, `ACES`, `ARRI`, `AV1`, `AVC`, `Blackmagic`, `BRAW`, `DaVinci Resolve`, `DCI-P3`, `DNxHD`, `DNxHR`, `H.264`, `H.265`, `HandBrake`, `HDR10`, `HEVC`, `HLG`, `IINA`, `LUT`, `MediaInfo`, `MKVToolNix`, `mpv`, `OBS Studio`, `OCIO`, `OpenColorIO`, `ProRes`, `Rec.2020`, `Rec.709`, `S-Log3`, `Streamlabs`, `Topaz`, `Topaz Video AI`, `V-Log`, `Vimeo`, `VP9`, `x264`, `x265`, `yt-dlp`
- **plural** (46): `APIs`, `APKs`, `CLIs`, `CPUs`, `CSVs`, `CVEs`, `DAWs`, `DBs`, `DLLs`, `EXEs`, `FAQs`, `GIFs`, `GPUs`, `GUIs`, `HDDs`, `HDRIs`, `IDEs`, `IPs`, `ISOs`, `JPEGs`, `JPGs`, `KPIs`, `LEDs`, `LLMs`, `LUTs`, `MCPs`, `MCUs`, `NFTs`, `NPUs`, `OSes`, `PDFs`, `PNGs`, `PRs`, `PSDs`, `RPCs`, `SDKs`, `SLAs`, `SoCs`, `SSDs`, `SVGs`, `UIs`, `URIs`, `URLs`, `VMs`, `VPNs`, `VSTs`

## Legacy entries in review, by pack
audio: 136, brand: 5, design: 2, legacy-tech: 273, media: 8, roman: 92. Filter the TSV on `tier=review, source=legacy` to inspect them. Typical reasons: 1–2 letter ALL-CAPS tokens (`ST`, `PM`, `IM`, `MS`) or ALL-CAPS English words (`POST`, `WIN`, `POP`, `SNAP`, `SLIP`).

## Casing conflicts resolved (winner kept over loser)
- regex (base) kept over RegEx (legacy)
- SaaS (base) kept over SAAS (legacy)
- AMD64 (base) kept over Amd64 (legacy)
- VMware (base) kept over VMWare (legacy)
- S-Log2 (legacy) kept over S-LOG2 (legacy)
- V-Log (added) kept over V-LOG (legacy)
- glTF (added) kept over GLTF (legacy)
- Sass (base) kept over SASS (legacy)
- Malwarebytes (base) kept over MalwareBytes (legacy)
- npm (base) kept over NPM (legacy)
- Visa (base) kept over VISA (legacy)
- 3dsMax (base) kept over 3DSMax (legacy)
- regexp (base) kept over RegExp (legacy)
- dotnet (base) kept over DotNet (legacy)
- virtualenv (base) kept over VirtualEnv (legacy)
- EPUB (added) kept over EPub (legacy)
- regedit (base) kept over RegEdit (legacy)
- Git (base) kept over GIT (legacy)
- vCenter (base) kept over VCenter (legacy)
- Qt (base) kept over QT (legacy)
- Acer (base) kept over ACER (legacy)
- SFTP (base) kept over sFTP (legacy)
- BlackBerry (base) kept over Blackberry (legacy)
- cPanel (base) kept over CPanel (legacy)
- QBitTorrent (legacy) kept over qBitTorrent (legacy)
- FreeCodeCamp (base) kept over freeCodeCamp (legacy)
- pytest (base) kept over PyTest (legacy)
- Bitdefender (base) kept over BitDefender (legacy)
- IPs (added) kept over IPS (legacy)
- Docusign (base) kept over DocuSign (legacy)
- Consensys (base) kept over ConsenSys (legacy)
- QBitTorrent (legacy) kept over qBittorrent (legacy)
- UGet (legacy) kept over uGet (legacy)
- PCloud (legacy) kept over pCloud (legacy)
- camelCase (base) kept over CamelCase (legacy)
- Xbox (base) kept over XBOX (legacy)
- DB (legacy) kept over dB (legacy)
- kbps (legacy) kept over KBPS (legacy)
- Akai (base) kept over AKAI (legacy)
- MAMP (base) kept over MAmp (legacy)
- WIN (legacy) kept over Win (legacy)
- IoT (base) kept over IOT (legacy)
- ASP.NET (added) kept over ASP.net (legacy)
- Log (legacy) kept over LOG (legacy)
- FFmpeg (base) kept over FFMPEG (legacy)

## 2026-09-28 expansion (+9,883 rows)

Requested by Jay: expand the dictionary as far as possible (brands, technologies, AI, acronyms) and add `PS`
(Photoshop / PlayStation / PostScript), which is now a `core` row. Full audit trail — every candidate with its tier and
reason, the auditors' flags, conflicts, corrections and the tiering scripts — is in `expansion-2026-09-28\`.

**Result:** 9,883 new `added` rows = 6,303 `core` (auto-applied in every casing-preserving pipeline), 2,546 `proper`
(preserve and sentence modes) and 1,034 `review` (opt-in by name, never automatic). New packs: `3d`, `business`,
`cloud`, `education`, `gaming`, `geo`, `hardware`, `internet`, `mobile`, `network`, `org`, `os`, `security`, `units`,
`web` (topic labels only; `added` rows are selected by source, not pack). Title default 1,892 → 8,191 terms; preserve
default 2,444 → 11,293; CamelCase rejoin 1,264 → 3,770 pairs (1,129 brand).

**How the rows were made**
1. **Research:** five agents, one per domain (AI; dev/cloud/OS/security; creative software and gear; acronyms and
   abbreviations; consumer tech/gaming/internet/brands), each verifying official casing on the web and skipping existing
   terms. 10,818 candidates → 9,886 unique after dedupe.
2. **Tiering (script, same rules as above, strengthened):** ReNamer's Capitalize Every Word is emulated to split `core`
   from `proper`; a term goes to `review` when its lowercase form is an ordinary English word (Hunspell en_US lookup +
   wordfreq zipf ≥ 2.0), a common given name, a 2-letter token without digits/`&`/`+` (hand allowlist: `PS AR VR XR XT
   HF KV VL Ti UV GB UK CV DL HQ GQ MV OC RL UE AE EF FY QC CX`), unverified or low-confidence casing, an agent-flagged
   collision, a generic concept that must not force lowercase (`cron`, `sudo`, `nano`…), an ordinary phrase or an
   all-caps logo styling (`Hot Chocolate`, `FINAL FANTASY`), or a kebab concept phrase (`Text-to-Image`). Hunspell also
   lists abbreviations as words, so safe acronyms were rescued by hand (`QR`, `DDS`, `VHF`, `kg`, `KB`, `SCAD`…).
3. **Independent audit:** three fresh agents checked all core terms (11 casing fixes, e.g. `CS224N`, `bunny.net`,
   `BattleTech`, `Lofi`; ~120 collisions moved to `review`, mostly common words in German/Spanish/French/Italian/
   Portuguese — `DER`, `SIE`, `POR`, `TODO`, `CI` — given names, and `VOX` (audio: vocals)).
4. **Differential test in ReNamer:** 8,613 titles (the 25,000 most common English words plus six other languages, and
   600 new terms in lowercase) through title presets built from the old and the new dictionary. All 600 new terms came
   out with exact casing; the 244 changed words in ordinary titles were almost all correct acronym fixes (`Fbi` → `FBI`,
   `Phd` → `PhD`, `Mclaren` → `McLaren`); the 7 false positives (`MEng`, `WAI`, `UVA`, `CAS`, `MPS`, `PPL`, `ABD`) moved
   to `review`.
5. **Regression:** acceptance suite (15) and examples (6) all PASS; the `00 Clean Up Filename` preset rebuilt with the
   new dictionary passes its 80 fixtures.

**Cross-domain casing conflicts** (one row per spelling; winner kept): `Swift` over SWIFT, `IRs` over IRS (impulse
responses), `UV` over uv (3D), `Moq` over MOQ, `SoX` over SOX (then moved to review), `SSMS` over SSMs, `Yarn` over
YaRN, `React` over ReAct, `KV` over kV, `IdP`, `IoU`, `IoC`, `GPOs`, `SOPs`, `PENTAX`, `Bluesky`, `Apple silicon`,
`A-roll`/`B-roll` — full list in `expansion-2026-09-28\conflicts.tsv`.

**Corrections to existing rows (32)** — official casings, note column records the old form: 26 `legacy` rows
(`IMDb`, `4chan`, `9GAG`, `pCloud`, `Xfce`, `Btrfs`, `rclone`, `jsDelivr`, `CRYENGINE`, `aiohttp`, `curl`, `vCard`,
`u-he`, `Soundtoys`, `DECALmachine`, `Launchpad`, `HDRI`, `Sci-Fi`, `KitBash3D`, `aescripts`, `C-Log`, `DnB`,
`DIRECTV`, `Mii`; the typo `MESHmashine` was superseded by a new `MESHmachine` row), 1 `added` row (`soothe2`) and
**6 `base` rows (Jay's list):** `FreeCodeCamp` → `freeCodeCamp`, `JAMstack` → `Jamstack`, `SourceTree` → `Sourcetree`,
`nmap` → `Nmap`, `ZigBee` → `Zigbee`, `FlyDubai` → `flydubai`. Revert any of these by editing the row.

**Decisions for Jay** (items marked ✓ were decided on 2026-09-28, see the next section)
1. Base rows whose official casing differs: ✓ `Puma`, ✓ `Gigabyte`, ✓ `NX`, ✓ `WinGet`, ✓ `WASM`; still open:
   `actix`/`tokio` (docs: Actix/Tokio), `stylelint` (Stylelint), `fail2ban` (Fail2Ban), `clang` (Clang).
2. Spellings blocked by an existing row with other casing: ✓ `SOC`, ✓ `LoRA`, ✓ `GaN`, ✓ `DB`, ✓ `README`; still open:
   `IPs`/IPS, `EPS`/EPs, `PRs`/PRS, `LMMS`/LMMs, `DIT`/DiT, `WAN`/Wan (video model), `Wix`/WiX, `UIKit`/UIkit.
3. Rebrands: `ProtonVPN`/`ProtonMail` are now written `Proton VPN`/`Proton Mail`; `RayBan` stays, `Ray-Ban` was added.
4. Speed: the Case rule costs ≈ 16 ms/file (title) / 19 ms/file (preserve) with the full default, versus ≈ 4 ms before.
   For batches of thousands, use `sources: ["base"]` plus the needed `optInPacks` (`casing.md` §2).

## 2026-09-28 Jay's casing decisions (12 rows)

Jay settled items 1 and 2 above, and chose four review-tier words to auto-apply. Applied by
`expansion-2026-09-28\apply_decisions.py`; every row change is in `expansion-2026-09-28\jay-decisions.tsv`.

| Jay's casing | Row change |
|---|---|
| `Puma`, `Gigabyte` | Already this casing. `proper` → `core`, so title mode (which keeps words that arrive in capitals) also turns `PUMA`/`GIGABYTE` into `Puma`/`Gigabyte`. |
| `WinGet` | `winget` → `WinGet` (`base`). New rejoin pair `Win Get` → `WinGet`, `brand` (added to the hand list in `classify-rejoin.py`). |
| `WASM`, `LoRA`, `README` | Already this casing; unchanged. |
| `NX`, `DB`, `JS` | `legacy` `review` rows → `added` `core` (packs `general`, `general`, `dev`), so they apply by default. `DB` wins over `dB`: decibel values written apart (`-6 dB`) become `-6 DB`. |
| `SOC` | `SoC` → `SOC` (`base`); the plural `SoCs` → `SOCs` to match. |
| `GaN` | `GAN` → `GaN` (`base`); the plural `GANs` stays. |
| `RAM`, `DOM`, `CI` | `review` → `core`, applied by default despite the collisions (ram, the name Dom, Portuguese/Dutch `dom`, Italian/French `ci`). |

**Effect:** title default 8,191 → 8,199 terms; preserve 11,293 → 11,299; `<LC>` guard 763 → 762 (`winget` left it);
CamelCase rejoin 3,770 → 3,771 pairs (1,131 brand, 2,640 review: `+Ga N`, `+SO Cs`, `+Win Get`, `−So C`, `−So Cs`).

**Differential test** (same 8,613 titles as the expansion, title mode, pre-decision skill vs this one): 10 names changed,
all the chosen collisions and nothing else: `ram` → `RAM`, `dom`/`Dom` → `DOM` (3), `ci` → `CI` (3: en, fr, it),
`db` → `DB`, `js` → `JS`, `SoC` → `SOC`. Speed unchanged (134.8 s vs 134.7 s for 8,613 files).
