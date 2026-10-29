# Function and method entries

How to fill the reference entry every callable gets (section 4, or a reference page).
Each entry has two slots: a `**Summary:**` one-liner and a detailed description.
`sync_report.py` copies each Summary into the function index (section 1.6 or
`function-index.md`) and recomputes every count, so you never edit the index or the
count tables by hand.

## Contents

- [Reading discipline](#reading-discipline)
- [Index one-liners](#index-one-liners)
- [Reference entries](#reference-entries)
- [Compact entries](#compact-entries)
- [Special cases](#special-cases)
- [Worked example](#worked-example)
- [Corrections](#corrections)

## Reading discipline

- Read the **whole file** before writing any of its entries. Module-level state,
  imports, constants, and sibling helpers change what a function means.
- For each callable, read its body top to bottom and follow calls into this codebase
  when the name alone doesn't settle what they do. The pre-filled *Calls* / *Called by*
  lines are heuristic hints (unique-name matching); confirm them before relying on them.
- Treat the pre-filled *Doc comment* as a claim to verify. If the code disagrees, the
  entry says what the code does and notes the discrepancy.
- Write the entry right after reading the function, while it is in front of you.

## Index one-liners

The `**Summary:**` line: one line, ≤ 15 words, verb first, present tense, no trailing
period. It answers "what does calling this accomplish?" and must add information beyond
the name.

| Function | Bad (restates the name) | Good |
| --- | --- | --- |
| `get_user(id)` | Gets the user | Loads a user by id from the cache, falling back to the database |
| `validate_preset()` | Validates the preset | Checks a preset against plugin import rules; returns errors and lint warnings |
| `Canvas.draw(in:)` | Draws the canvas | Renders every queued item into the given rect in insertion order |
| `test_parse` | Tests parse | Asserts comma-separated input splits into trimmed fields |

The checker flags summaries whose words are all contained in the function name.

## Reference entries

The scaffold writes the heading, the kind/visibility/extent line, the signature, and any
doc comment, decorators, calls, and callers. Fill the Summary line, then replace the
description `[[FILL]]` with prose that covers, in this order and **omitting what doesn't
apply**:

1. **Purpose.** One sentence: what the function is for and when it is used.
2. **Behavior.** The steps it takes, in order, at the level a reviewer would need:
   branches, loops, early returns, what it delegates to.
3. **Parameters.** Each one's meaning, expected shape, and defaults that matter.
   Skip `self`/`this`.
4. **Returns.** What comes back and in which cases (including `None`/`null`, sentinel
   values, and shapes of dicts or tuples).
5. **Side effects.** File, network, or database I/O, mutation of arguments, object or
   global state, caches, logging, spawned processes, UI updates.
6. **Errors.** What it raises or throws, what it catches and swallows, and how failures
   surface to callers.
7. **Notes.** Concurrency (async, locks, thread-safety), performance characteristics,
   edge cases, TODOs, and any disagreement with its docstring or name.

Aim for 40–150 words. Use a short bullet list for parameters when there are more than
three. Refer to other callables as `Name` in backticks so readers can search for them.

`check_report.py` warns when a description is under 25 words (6 for compact entries).
It counts everything after the pre-filled lines. The kind line, the signature block,
the facts line (`Doc comment: …`, `Calls: …`, `Called by: …`, with a colon), and the
Summary line don't count; prose that happens to start with "Calls" does.

## Compact entries

The scaffold marks callables with at most five code lines (comments and blank lines
excluded) and abstract declarations as compact (`<!-- sym:… compact -->`). One or two
sentences are enough:

- Trivial accessor: "Returns the configured base URL (`self._url`) unchanged."
- Abstract, interface, or trait declaration: state the **contract**, meaning what
  implementers must do and return, and name the implementations when the inventory
  shows them.
- Delegating wrapper: name the target and anything the wrapper adds or changes.

## Special cases

| Case | How to write it |
| --- | --- |
| Overloads / same name twice | Each entry describes its own parameter list and how it differs from its siblings |
| Constructors | What state is initialized, what is validated, what is acquired (connections, handles, threads) |
| Destructors / `Dispose` / `__del__` | What is released and in what order |
| Decorated handlers (routes, MCP tools, CLI commands, event listeners) | Lead with the external trigger: "MCP tool `navigate`: …", "`GET /users/{id}`: …", "Click command `build`: …" |
| Test functions | The behavior asserted and the scenario set up; mention fixtures and mocks. One or two sentences |
| Generated-looking or vendored code that slipped through | Describe briefly and note it in Appendix B, or drop it there if it shouldn't count |
| IIFE, PowerShell script (`kind: script`), Pascal main block | The file-level program: its parameters, what runs, in what order, and what it produces or writes. This is often the most important entry in the file; describe it fully |
| PowerShell script blocks (`$name = { … }`), named lambdas | What the block computes for its enclosing scope, its `param()` inputs, and where it's invoked |
| Local (nested) functions | What they do *for the enclosing function*, and what they capture from it |
| Language without an extractor | Add entries by hand as manual entries (see Corrections) |

## Worked example

The code being described (fictional):

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

Its reference entry:

````markdown
#### `ResponseCache.get_or_fetch` <!-- sym:src/cache.py::ResponseCache.get_or_fetch -->

method · public · lines 41–56

```python
async def get_or_fetch(self, url: str, ttl: float | None = None) -> bytes
```

Doc comment: “Return cached bytes for url.” · Calls: `ResponseCache._key`, `ResponseCache._evict_over_budget`

**Summary:** Returns cached bytes for a URL, downloading and caching them with a TTL on a miss

Returns the body for `url` from the in-memory cache, downloading and caching it on a
miss. Under `self._lock` it looks up the normalized key (`_key`) and returns the stored
body if the entry has no expiry or hasn't expired, counting the hit. Otherwise it
releases the lock, fetches through `self._client`, stores the result with an expiry of
`ttl` seconds (`default_ttl` when `None`; `ttl <= 0` means never expires), and evicts
entries over the memory budget.

- `url`: absolute URL; normalized by `_key`, so query-parameter order doesn't matter.
- `ttl`: seconds until expiry for this entry only.

Returns the raw response bytes. Side effects: network request on a miss; mutates
`_entries` and `hits`; may evict other entries. Errors: `FetchError` from the client
propagates and nothing is cached. Note: the lock is released during the fetch, so two
concurrent misses for the same URL both download it (last write wins). The docstring
doesn't mention the fetch.
````

After `sync_report.py`, its index row reads:

```markdown
| <!-- idx:src/cache.py::ResponseCache.get_or_fetch -->`ResponseCache.get_or_fetch` | method | 41–56 | Returns cached bytes for a URL, downloading and caching them with a TTL on a miss |
```

## Corrections

The inventory is exact for Python and heuristic elsewhere. Keep the counts auditable.
Edit only reference entries and Appendix B; `sync_report.py` updates the index and
every count.

- **False positive** (a "callable" that isn't one): delete its reference entry and add
  `<!-- drop:ID reason -->` under Appendix B.
- **Missed callable:** add a reference entry in its file's group. If the file has no
  group yet, add one: a `` ### `path/to/file` `` heading and the file-role sentence.
  Use the same shape as the generated entries:

  ```markdown
  #### `Name` <!-- sym:manual:path/to/file::Name -->

  function · lines 40–58

  **Summary:** One line, verb first

  Detailed description.
  ```

  The first line after the heading must start with the kind and include `line N` or
  `lines A–B`: the index and the counts are built from it. List the addition in
  Appendix B.
- **Wrong kind, container, extent, or visibility:** fix the text of the entry; the ID
  stays.

Then run `sync_report.py`. `check_report.py` expects a total of inventory − drops +
manual entries, and requires an index row for every manual entry.
