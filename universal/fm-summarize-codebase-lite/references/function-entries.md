# Function and method entries

How to write the two things every callable gets: a **reference entry** (section 4) and
an **index row** (section 1.6). The index row reuses the entry's Summary line word for
word, so each one-liner is written once.

## Contents

- [Reading discipline](#reading-discipline)
- [Entry format](#entry-format)
- [Summary lines](#summary-lines)
- [Detailed descriptions](#detailed-descriptions)
- [Compact entries](#compact-entries)
- [Special cases](#special-cases)
- [Worked example](#worked-example)

## Reading discipline

- Read the **whole file** before writing any of its entries. Module-level state,
  imports, constants, and sibling helpers change what a function means.
- Read each callable's body top to bottom. When a call into this codebase matters and
  its name doesn't settle what it does, open the callee.
- A docstring or comment is a claim to verify. If the code disagrees, the entry says
  what the code does and notes the discrepancy.
- Write the entries while the file is in front of you, file by file. Never write an
  entry from memory of a file you read long ago; re-open it. Re-reading just the
  relevant line range is enough, and so is a copy of the file you already fetched at
  the same commit.

## Entry format

````markdown
#### F041 · `ResponseCache.get_or_fetch`

method · public · `src/cache.py` lines 41–56

```python
async def get_or_fetch(self, url: str, ttl: float | None = None) -> bytes
```

**Summary:** Returns cached bytes for a URL, downloading and caching them with a TTL on a miss

Detailed description…
````

- **Heading:** `#### {ID} · {qualified name in backticks}`.
- **Facts line:** the kind, then flags as they apply (abstract, test, public / private
  / local), then the file and the line or line range.
- **Signature:** in a fenced block tagged with the language. Copy it from the source;
  shorten very long parameter lists with `…`.
- **Optional facts:** the doc comment (quoted), decorators or attributes, and "Calls:" /
  "Called by:" for the relationships you verified while reading. Put them on one line.
- **Summary**, then the **description**.

Group entries under a `` ### `path/to/file` `` heading per file. Under that heading, one
sentence gives the file's role.

## Summary lines

One line, 15 words or fewer, verb first, present tense, no trailing period. It answers
"what does calling this accomplish?" and must add information beyond the name.

| Function | Bad (restates the name) | Good |
| --- | --- | --- |
| `get_user(id)` | Gets the user | Loads a user by id from the cache, falling back to the database |
| `validate_preset()` | Validates the preset | Checks a preset against import rules; returns errors and lint warnings |
| `Canvas.draw(in:)` | Draws the canvas | Renders every queued item into the given rect in insertion order |
| `test_parse` | Tests parse | Asserts comma-separated input splits into trimmed fields |

Test your summary: if you remove the words that appear in the function name and nothing
informative is left, rewrite it.

Because the Summary is copied into a table row, keep it table-safe: write a literal
pipe as `\|`, and put anything that looks like markup (`<Tag>`, `[x](y)`) in backticks.
Copy it into the index exactly, backticks included.

## Detailed descriptions

Cover these, in order, and **omit what doesn't apply**:

1. **Purpose.** One sentence: what it's for and when it's used.
2. **Behavior.** The steps it takes, in order: branches, loops, early returns, what it
   delegates to.
3. **Parameters.** Each one's meaning, expected shape, and defaults that matter. Skip
   `self`/`this`. Use a bullet list when there are more than three.
4. **Returns.** What comes back and in which cases (`None`/`null`, sentinels, the shape
   of dicts or tuples).
5. **Side effects.** File, network, or database I/O, mutation of arguments, object or
   global state, caches, logging, processes, UI.
6. **Errors.** What it raises or throws, what it catches or swallows, and how failures
   reach callers.
7. **Notes.** Concurrency, performance, edge cases, TODOs, and any disagreement with its
   docstring or name.

Aim for 40–150 words, and at least 25. Refer to other callables by name in backticks,
and add their ID when it helps (`_key` (F039)).

## Compact entries

Callables with at most about five lines of real code, and abstract declarations, get a
compact entry: the Summary plus one or two sentences.

- **Trivial accessor:** "Returns the configured base URL (`self._url`) unchanged."
- **Abstract, interface, or trait declaration:** state the **contract**, meaning what
  implementers must do and return, and name the implementations you found.
- **Delegating wrapper:** name the target and what the wrapper adds or changes.

**Declared twins.** When several files hold the same function with an identical or
near-identical body (copies of a routine in four variants of a script), write the full
description once, on the first copy. Every other copy gets a *twin* entry: its Summary,
then one or two sentences, "Identical to F045 (`nopad.pas`) except that it pads to
three digits", stating every difference, or "Byte-for-byte identical to F045". Twin
entries are exempt from the 25-word minimum. Verify the claim by comparing the bodies;
never assume two same-named functions match.

## Special cases

| Case | How to write it |
| --- | --- |
| Overloads / same name twice | Each entry covers its own parameter list and how it differs from its siblings |
| Constructors | The state initialized, what's validated, what's acquired (connections, handles, threads) |
| Destructors / `Dispose` / `__del__` | What's released, and in what order |
| Decorated handlers (routes, MCP tools, CLI commands, event listeners) | Lead with the trigger: "MCP tool `navigate`: …", "`GET /users/{id}`: …", "Click command `build`: …" |
| Test functions | The behavior asserted and the scenario set up, including fixtures and mocks. One or two sentences |
| IIFE, PowerShell script, Pascal main block | The file-level program: its parameters, what runs and in what order, and what it produces or writes. Often the most important entry in its file; describe it fully |
| Script blocks, named lambdas, local functions | What they compute for the enclosing function, their inputs, and what they capture |
| Code you couldn't fully read (very long generated-looking functions) | Describe the structure you did read, and say which parts you skimmed |

## Worked example

The code (a fictional example):

```python
class ResponseCache:
    async def get_or_fetch(self, url: str, ttl: float | None = None) -> bytes:
        """Return cached bytes for url."""
        key = self._key(url)
        async with self._lock:
            hit = self._entries.get(key)
            if hit and (hit.expires is None or hit.expires > time.monotonic()):
                self.hits += 1
                return hit.body
        body = await self._client.get(url)          # raises FetchError on non-2xx
        ttl = self.default_ttl if ttl is None else ttl
        async with self._lock:
            self._entries[key] = Entry(body, None if ttl <= 0 else time.monotonic() + ttl)
            self._evict_over_budget()
        return body
```

Its entry:

````markdown
#### F041 · `ResponseCache.get_or_fetch`

method · public · `src/cache.py` lines 41–56

```python
async def get_or_fetch(self, url: str, ttl: float | None = None) -> bytes
```

Doc comment: “Return cached bytes for url.” · Calls: `ResponseCache._key` (F039), `ResponseCache._evict_over_budget` (F043)

**Summary:** Returns cached bytes for a URL, downloading and caching them with a TTL on a miss

Returns the body for `url` from the in-memory cache, downloading and caching it on a
miss. Under `self._lock` it looks up the normalized key and returns the stored body if
the entry has no expiry or hasn't expired, counting the hit. Otherwise it releases the
lock, fetches through `self._client`, stores the result with an expiry of `ttl` seconds
(`default_ttl` when `None`; `ttl <= 0` means never expires), and evicts entries over the
memory budget.

- `url`: absolute URL; normalized by `_key`, so query-parameter order doesn't matter.
- `ttl`: seconds until expiry for this entry only.

Returns the raw response bytes. Side effects: a network request on a miss; mutates
`_entries` and `hits`; may evict other entries. Errors: `FetchError` from the client
propagates and nothing is cached. Note: the lock is released during the fetch, so two
concurrent misses for the same URL both download it (last write wins). The docstring
doesn't mention the fetch.
````

Its index row:

```markdown
| F041 | `ResponseCache.get_or_fetch` | method | 41–56 | Returns cached bytes for a URL, downloading and caching them with a TTL on a miss |
```
