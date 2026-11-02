# Access and delivery

How to reach the code with the tools you actually have, and where the finished report
goes. Decide both before reading any code.

## Contents

- [Take stock of your tools](#take-stock-of-your-tools)
- [Access modes](#access-modes)
- [What each mode can measure](#what-each-mode-can-measure)
- [Delivery modes](#delivery-modes)
- [Writing files](#writing-files)
- [Multi-part chat delivery](#multi-part-chat-delivery)
- [Single-reply runs](#single-reply-runs)

## Take stock of your tools

Check which of these you can do. The tool names vary by platform; the capability is
what matters.

| Capability | Typical tools |
| --- | --- |
| List a directory tree, with file sizes | File-system or MCP "list"/"tree" tools, GitHub/GitLab "list files" |
| Read a file | File-system "read", GitHub "get file", HTTP GET of a raw file URL |
| Search file contents | grep/ripgrep tools, code search, GitHub code search |
| Run shell commands | A terminal, shell, or command tool |
| Run code you write | A code or sandbox tool (for counting and arithmetic, not for running the target) |
| Call a hosting API | GitHub, GitLab, or Bitbucket tools, or HTTP requests to their REST APIs |
| Write the report | File write, repository commit, docs, cloud storage, or chat only |
| Delegate | Sub-agents or agent-to-agent tools |

## Access modes

Use the first mode that fits. Modes combine: a local checkout plus the GitHub API is
the strongest setup.

**Local:** you can list and read files on disk, perhaps with search and a shell.

- Everything is available. With a shell, use git for the snapshot and history.
- Without a shell, git metadata comes from files: `.git/HEAD`,
  `.git/refs/heads/<branch>`, and `.git/logs/HEAD`. The last line of `logs/HEAD` holds
  the latest commit hash, the author, the Unix timestamp, and the message. It's
  approximate but real (see metadata-sources.md).

**Hosted repository:** you can reach GitHub, GitLab, or Bitbucket through tools or HTTP.

- List the full file tree in one call (GitHub: `GET /repos/{owner}/{repo}/git/trees/{branch}?recursive=1`
  returns every path and file size).
- Read files through the contents API or raw URLs
  (`https://raw.githubusercontent.com/{owner}/{repo}/{ref}/{path}`).
- Metadata, languages, commits, tags, releases, and contributors come from API
  endpoints (see metadata-sources.md). Language percentages come straight from the
  languages endpoint.
- The **default branch** is summarized unless the user names another ref. Record the
  commit SHA you read at, so the report describes one fixed snapshot, and read files at
  that SHA (`?ref={sha}`, or the SHA in the raw URL) rather than at the moving branch.
- **Fetch tools can damage code.** Some collapse newlines, which loses every line
  number. Some turn `[...](...)` fragments in regexes into links, or refuse to
  reproduce code and summarize it instead. After the first fetch, check that the text
  has its line breaks and looks exactly like source. If not, try these in order:
  1. The raw URL through a different tool.
  2. The contents API with the header `Accept: application/vnd.github.raw`.
  3. The contents API with `Accept: application/vnd.github.html`, which returns the
     file as an HTML code listing with its lines intact.

  If none preserves lines, say "line numbers unavailable (fetch tool)" in the entries
  and in Appendix A, and cite locations by function name instead.
- **Rate limits.** Unauthenticated `api.github.com` allows 60 requests per hour;
  authenticated tools allow 5,000. `raw.githubusercontent.com` isn't counted against
  the API limit. Budget: 1 request for the tree, 1 for languages, about 6 for metadata,
  then 1 per file. Unauthenticated, read files through raw URLs, and above about 40
  files ask the user for an authenticated tool, or read the files in several sessions.
- A snapshot doesn't change, so re-checking an entry against a copy you already fetched
  at the same SHA counts as re-reading the code.

**Provided files:** the code arrives as uploads, pasted text, a knowledge base, or an
extracted archive.

- There is no git history. Snapshot fields read "Not available (files provided without
  version control)" unless the user supplies them.
- If a knowledge base only supports searching, not listing, ask the user for the file
  list or an archive manifest. You can't guarantee completeness without one, and the
  report must say so.

**No access:** ask for a repository URL (with a connected tool), a local path the tools
can reach, or uploaded files. Don't summarize from memory or from the README alone.

## What each mode can measure

| Item | Local + shell | Local, no shell | Hosted API | Provided files |
| --- | --- | --- | --- | --- |
| File list | Exact | Exact | Exact (tree) | As provided |
| Language % | Exact (count command) | Exact lines via search count mode; or bytes from listed sizes | Exact (languages API, bytes), plus tree sizes as a cross-check | Lines of files read |
| Function inventory | Search + reading | Search or reading | Code search (limited) + reading | Reading |
| Latest commit, branch | Exact (git) | From `.git` files | Exact (commits API) | Not available |
| Commit count, contributors | Exact (git) | Not available | Exact (API pagination) | Not available |
| Uncommitted changes | Exact (`git status`) | Not available | Not applicable | Not applicable |
| Tags, releases | Exact (git) | From `.git/refs/tags`, `packed-refs` | Exact (API) | CHANGELOG only |

Say in Appendix A which mode you used. Keep "Not available" rows in the metadata table
rather than dropping them, so the reader knows what wasn't checked.

## Delivery modes

| You can… | Deliver as |
| --- | --- |
| Write files | `CODEBASE_SUMMARY.md` at the root of the target (or the user's chosen path). Above about 250 callables, put the reference in `codebase-summary/reference/{module}.md` pages and link them from section 4. See [Writing files](#writing-files) for tools that can only overwrite. |
| Create or edit documents (Google Docs, Notion, Confluence, SharePoint, Drive) | One document for sections 1–3 plus one per large module for section 4, or a single document if it fits. Keep the markdown structure: headings, tables, code blocks. |
| Commit to a repository | Only with the user's explicit permission, on a branch they name. Otherwise use another mode. |
| Only reply in chat | [Multi-part chat delivery](#multi-part-chat-delivery). |

Never write into the target repository without being asked, and never overwrite an
existing `CODEBASE_SUMMARY.md` without confirmation. Offer a dated name instead.

### Writing files

- **Append or edit tools available:** create the file with the finished parts and
  append as you go. Fix problems with targeted edits.
- **Overwrite-only tools** (each write replaces the whole file): plan the files so each
  is written once, complete.
  - Above about 60 callables, put section 4 in one page per module
    (`codebase-summary/reference/{module}.md`), whatever the tier. Each page is written
    when its module is done.
  - Write the main file (sections 1–3, the index, the appendices) **last**, after
    running the verification checks on your drafts. Put the verification result in
    the delivery message rather than rewriting the file to add it.
  - Keep any single write under about 15,000 words; split a large module's page into
    parts if needed.
- **The platform shows the reply to the user as the deliverable:** use chat delivery,
  below.

## Multi-part chat delivery

A single reply can't hold a detailed summary of more than about 40 callables. Split the
report and say so up front.

1. **Plan.** After building the inventory, tell the user the number of parts, what each
   holds, and that they'll arrive one per turn. For example: "Part 1: sections 1–3.
   Parts 2–5: reference, F001–F120 by file. Part 6: appendices."
2. **Order.** Deliver reference parts as you finish reading each file group. Deliver
   sections 1–3 (which depend on having read everything) as the final part, headed
   "Part 1 of N: place first". Every part starts with a one-line header naming the
   report, the part number, and the ID range it covers.
3. **Ledger.** End every part with a progress ledger, so you or another run can resume
   exactly:

   ```text
   Progress: F001–F120 done (4 of 9 modules) · next: module `src/api`, file `src/api/routes.py`, F121
   Inventory total: 388 · withdrawn: F057 · parts remaining: 3
   ```

4. **Continue on "continue."** If the platform ends your turn, the next user message
   (or a scheduled or chained run) picks up from the ledger. Re-read the inventory from
   your earlier part rather than rebuilding it.
5. **Assemble.** At the end, tell the user the order to paste the parts in. If a write
   tool becomes available, offer to write the assembled file.

### Single-reply runs

Some runs get exactly one reply: a scheduled agent, a workflow step, or a
non-interactive call. With more than about 40 callables and no write tool, deliver in
this priority order until the reply is full:

1. Section 1 complete, **including the index with every callable's Summary line**. The
   one-liners are short, so every function gets at least its description.
2. Sections 2 and 3, condensed where necessary.
3. Section 4 entries in ID order, as many as fit.
4. A closing ledger that states exactly which IDs have full entries, and how to get
   the rest: reply "continue", re-run with a write tool attached, or run with a
   narrower scope.

State at the top of the reply that it is partial, and why.
