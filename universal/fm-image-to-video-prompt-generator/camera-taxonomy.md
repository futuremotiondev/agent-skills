# Camera Movement Reliability Taxonomy

## Usage Rule

**SLOW BEATS FAST.** Movements at 15% speed or less of what feels natural dramatically outperform faster alternatives. Always default to slow unless the Dynamic archetype demands energy — and even then, "controlled fast" beats "chaotic fast."

**ONE MOVEMENT PER PROMPT.** Compound movements (pan + zoom + track simultaneously) create unstable footage on all current platforms. If the user wants compound motion, decompose it into timestamp-segmented beats with one camera action each.

---

## Tier 1 — Production-Ready

Use freely in any archetype. These succeed 90%+ of the time across all major platforms.

### Static / Locked-Off
- **Reliability:** Highest possible. Rock-solid on all platforms.
- **Best for:** Subtle/Cinemagraph archetype. Any scene where subject motion is the star.
- **Prompt pattern:** `"Camera entirely motionless. [subject motion]. [environmental motion]. [everything else frozen]."`
- **Platform notes:** Universal. Minimax performs best with static camera + micro-expression focus.

### Slow Push-In / Dolly Forward
- **Reliability:** The single most reliable camera motion across every platform tested.
- **Best for:** Cinematic archetype. Portraits. Scenes requiring intimacy or revelation.
- **Prompt pattern:** `"Slow dolly forward toward [subject]. [subject action]. [atmospheric detail]."`
- **Modifiers that help:** "gentle," "almost imperceptible," "gradual"
- **Platform notes:** Veo 3.1 handles this best. Runway Gen-4 also excellent. Universal safe choice.

### Slow Pan (Horizontal)
- **Reliability:** High at slow speeds (15% or less). Degrades above 30 degrees of arc.
- **Best for:** Cinematic archetype. Landscapes. Revealing scene elements.
- **Prompt pattern:** `"Camera pans slowly [left/right], [following subject / revealing element]. [atmospheric motion]."`
- **Constraints:** Keep arc under 45 degrees. Always specify direction. Faster pans → Tier 3.
- **Platform notes:** Kling AI handles this best with its camera control system.

### Crane / Jib (Vertical Ascent or Descent)
- **Reliability:** Ascending crane is more reliable than descending. Both are Tier 1.
- **Best for:** Cinematic archetype. Environments. Scale reveals. Establishing context.
- **Prompt pattern:** `"Camera cranes [upward/downward], revealing [broader scene / subject detail]. [environmental motion]."`
- **Modifiers that help:** "smooth vertical movement," "steady ascent"
- **Platform notes:** Google's own Veo examples prominently feature crane shots. Veo 3.1 excels here.

### Tilt (Vertical Pan)
- **Reliability:** High for slow tilts along a subject or structure.
- **Best for:** Cinematic archetype. Tall subjects. Reveals along vertical axis.
- **Prompt pattern:** `"Camera slowly tilts [up/down] along [subject/structure], revealing [element]. [ambient motion]."`
- **Constraints:** Same speed rules as horizontal pan. Keep the tilt under 45 degrees.

---

## Tier 2 — Reliable With Constraints

These work well with the right stabilizing modifiers. Without modifiers, expect ~60-70% success. With modifiers, ~80-85%.

### Tracking / Following Shot
- **Reliability:** Good against simple backgrounds. Loses tracking when subjects pass behind objects or move through complex environments.
- **Best for:** Dynamic archetype. Subjects in motion. Walking/running scenes.
- **Prompt pattern:** `"Camera tracks [laterally/alongside] as [subject] moves [direction]. [simple background descriptor]. [atmospheric motion]."`
- **Stabilizing modifiers:** "steady tracking," "smooth lateral movement," "clean background," "consistent distance"
- **Failure mode:** Subject occlusion by foreground objects. Complex parallax from detailed backgrounds.
- **Platform notes:** Runway Gen-4 handles tracking best. Minimax worst.

### Aerial / Drone Shot
- **Reliability:** Good with explicit slow forward motion and a clear subject/landscape below.
- **Best for:** Cinematic archetype. Landscapes. Establishing shots. Scale/context.
- **Prompt pattern:** `"Aerial shot glides slowly forward over [landscape]. [atmospheric particles]. [environmental motion below]."`
- **Stabilizing modifiers:** "slow forward glide," "gentle descent," "bird's-eye drift," "steady altitude"
- **Failure mode:** Rapid altitude changes. Complex terrain with detailed parallax. Attempting to track a moving ground-level subject from above.
- **Platform notes:** Veo 3.1 and Kling handle aerials best.

### Rack Focus / Pull Focus
- **Reliability:** Good when depth planes are clearly separated in the source image. Fails when the scene is flat or planes overlap.
- **Best for:** Cinematic archetype. Scenes with clear foreground/background separation. Narrative reveals.
- **Prompt pattern:** `"Focus slowly racks from [foreground element] to [background element]. [ambient motion in both planes]."`
- **Stabilizing modifiers:** "clear depth separation," "backlit rim separating planes," "distinct foreground and background," "smooth focus transition"
- **Success boost:** Adding "backlight rim" or "clear separation" improves success by approximately 25%.
- **Failure mode:** Flat scenes with no depth separation. More than two focal planes. Fast rack speed.

### Dolly Zoom (Vertigo Effect)
- **Reliability:** Can produce the classic perspective-warping effect but requires very explicit description. Unreliable on complex scenes.
- **Best for:** Narrative archetype (as a dramatic beat). Single subjects with visible background depth.
- **Prompt pattern:** `"Slow dolly zoom — camera pushes in while focal length widens, background stretching away from [subject]. [subject stays fixed in frame]."`
- **Constraints:** Only use on images with clear depth. Single subject preferred. Always specify slow speed.
- **Platform notes:** Veo 3.1 handles this best. Most other platforms struggle.

---

## Tier 3 — Use Carefully

Expect 40-60% success rates. Always warn the user about inconsistency. Suggest Tier 1-2 alternatives.

### Orbit / Arc Shot
- **Known issue:** Stutters when the model cannot predict background parallax behind the subject.
- **Mitigation:** Isolate subject on simple/blurred background. Specify shallow depth of field. Keep the arc under 90 degrees. Slow speed only.
- **Prompt pattern:** `"Camera arcs slowly [direction] around [subject]. [soft/blurred/simple background]. Shallow depth of field. [minimal additional motion]."`
- **Alternative suggestion:** A slow lateral tracking shot often achieves a similar reveal effect with Tier 2 reliability.

### Whip Pan
- **Known issue:** Creates synthetic, artificial-looking results. Speed exceeds what current models handle well.
- **Mitigation:** Very limited. Describe as "quick pan" at moderate speed rather than true whip for better results.
- **Alternative suggestion:** A motivated slow pan with a cut (in post) creates the same editorial effect more reliably.

### Fast Zoom / Crash Zoom
- **Known issue:** Looks artificial on every platform tested. Models cannot maintain subject coherence during rapid focal length changes.
- **Mitigation:** Only use for intentionally retro or comedic aesthetics where artificiality is the point.
- **Alternative suggestion:** Slow push-in (Tier 1) provides the same emotional effect of "approaching the subject" with dramatically better results.

### Compound Movements (Pan + Zoom + Track)
- **Known issue:** Unstable footage on all platforms. The model cannot handle multiple simultaneous camera transformations.
- **Alternative suggestion:** Decompose into sequential single movements using timestamp-segmented prompts. Each beat gets one camera action.

### Handheld / Shaky Cam
- **Known issue:** Unpredictable interpretation across platforms. Veo tends to overcorrect. Some platforms ignore the cue entirely.
- **Mitigation:** Use "subtle handheld sway" rather than "shaky cam." Runway handles this best of all platforms.
- **Alternative suggestion:** Static camera with subject-driven energy (Dynamic archetype) often produces more controlled kinetic results.

---

## Platform-Specific Camera Strengths

**Veo 3.1:** Best at dolly, crane, tilt, dolly zoom. Strongest overall camera adherence.
**Runway Gen-4:** Best at tracking shots and handheld. Strongest character consistency through motion.
**Kling AI:** Best camera control system overall. Handles the widest range of movements reliably. Supports negative prompts to exclude unwanted camera behavior.
**Pika:** Best at rapid iteration. Camera language treated as first-class. Good for testing multiple camera options quickly.
**Minimax:** Best with static or very minimal camera movement. Excels when camera stays still and subjects perform micro-expressions. Complex camera fails here.
