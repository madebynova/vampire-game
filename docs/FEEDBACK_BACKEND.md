# Feedback backend (Supabase)

The website's **Player Feedback** and **Community Reports** sections need somewhere to keep what players send.
GitHub Pages only serves static files, so a normal HTML form cannot store anything. Instead the page talks to a
small hosted database, [Supabase](https://supabase.com) (free tier is enough for a playtest).

> **Status:** the website code and the database schema are finished, and the website was tested against a
> stand-in server that behaves like Supabase. **It has not been tested against a real Supabase project yet**,
> because none exists. Follow the setup below, then run the "Check it is locked down" tests.

## How it fits together

```
 player's browser                         Supabase project (yours)
 ┌──────────────────────┐   public key    ┌─────────────────────────────────────┐
 │ website (GitHub Pages)│ ─────────────► │ table  feedback  (Row Level Security) │
 │ feedback.js           │ ◄───────────── │ bucket feedback-attachments (private) │
 └──────────────────────┘  only allowed    └─────────────────────────────────────┘
                           rows/columns              ▲
                                                     │ admin rights
                                      you, in the Supabase dashboard
```

- The website only ever holds the project's **public key** (the "anon" or "publishable" key). Anyone can read it
  from the page source, so it is designed to be public. What it is *allowed to do* is decided by the database.
- **Row Level Security (RLS)** is the database's own bouncer. `supabase/feedback_schema.sql` switches it on and says:

| The public can… | The public can NOT… |
|---|---|
| add a new report (bug or idea) | change or delete any report |
| read reports that are `visible` | set a status, or make a hidden report visible |
| upload one screenshot/video (≤10 MB) to a private bucket | read, list or delete uploads |
| | read `admin_notes`, `attachment_path` (columns are not granted) |

- **You** manage everything in the Supabase dashboard. It uses admin rights, so it is not limited by those rules.

## What gets stored

Table `public.feedback` (full definition in [`supabase/feedback_schema.sql`](../supabase/feedback_schema.sql)):

| Column | Meaning | Who sets it |
|---|---|---|
| `id`, `created_at` | automatic | database |
| `type` | `bug` or `idea` | player |
| `title`, `description` | the report | player |
| `context`, `reproduction_steps`, `expected_behavior` | bug details | player |
| `idea_benefit` | "why would this improve the game?" | player |
| `submitter_name`, `anonymous` | `anonymous = true` means the name is never stored and the site shows **Anonymous Player** | player |
| `attachment_path` | which uploaded file belongs to the report | website (after upload) |
| `status` | `new` → `investigating` → `planned` → `in_progress` → `fixed` / `closed` | **you** (always starts as `new`) |
| `visible` | untick to hide a report from the public list | **you** |
| `admin_notes` | private notes, never sent to the public site | **you** |

## One-time setup

You need a free Supabase account. Dashboard labels move around occasionally; the ideas are stable.

1. **Create a project.** supabase.com → *New project*. Pick any name and region, and a strong database password
   (store it in a password manager; you will not need it for the website).
2. **Create the table and rules.** Dashboard → **SQL Editor** → *New query* → paste the whole of
   [`supabase/feedback_schema.sql`](../supabase/feedback_schema.sql) → **Run**. It should finish with "Success".
   (It is safe to run again later.)
3. **Copy the two public values.** Dashboard → **Project Settings → API** (newer dashboards: *API Keys*, or the
   *Connect* button):
   - **Project URL**, like `https://abcdxyz.supabase.co`
   - the **anon / publishable** key (`eyJ…` or `sb_publishable_…`)

   > **Never** use the `service_role` or `secret` key. It bypasses every protection. Do not paste it into any file,
   > chat or issue. If you ever do, rotate it in the dashboard straight away.
4. **Put them in the website.** Edit [`website/assets/js/config.js`](../website/assets/js/config.js):
   ```js
   window.VG_CONFIG = {
     supabaseUrl: "https://abcdxyz.supabase.co",
     supabaseAnonKey: "eyJ…your public anon key…",
     attachmentsBucket: "feedback-attachments"
   };
   ```
5. **Check, commit, deploy.** `python tools/check_repo.py` refuses to pass if a secret key slipped in. Commit and push
   `config.js`, then re-run the *Deploy website to GitHub Pages* workflow (or let it auto-run, see the README).

Until step 4 is done the site shows **"Feedback is temporarily unavailable"** and the forms are disabled. Nothing breaks.

## Check it is locked down

Do this once after setup (PowerShell; replace the two values). Every "should fail" test must **fail** or change nothing.

```powershell
$u = "https://abcdxyz.supabase.co"; $k = "YOUR_PUBLIC_KEY"
$h = @("-H", "apikey: $k", "-H", "Content-Type: application/json")

# 1) should WORK: read visible reports
curl.exe -s "$u/rest/v1/feedback?select=id,title,status&limit=3" @h

# 2) should WORK: submit a report
curl.exe -s -X POST "$u/rest/v1/feedback" @h -H "Prefer: return=minimal" -d '{"type":"bug","title":"Setup test","description":"Testing the feedback setup works."}'

# 3) should FAIL: read admin-only columns
curl.exe -s "$u/rest/v1/feedback?select=admin_notes,attachment_path" @h

# 4) should FAIL: set my own status / visibility
curl.exe -s -X POST "$u/rest/v1/feedback" @h -d '{"type":"bug","title":"Sneaky","description":"Trying to set a status.","status":"fixed"}'

# 5) should change NOTHING (permission error or empty result): edit and delete
curl.exe -s -X PATCH  "$u/rest/v1/feedback?title=eq.Setup%20test" @h -d '{"status":"fixed"}'
curl.exe -s -X DELETE "$u/rest/v1/feedback?title=eq.Setup%20test" @h
```

Then open the dashboard **Table Editor → feedback** and confirm the "Setup test" row exists with `status = new`.
Delete it there. Also check **Authentication → Policies** shows RLS *enabled* on `feedback`, and run the dashboard's
**Security Advisor** for warnings.

## Managing reports (admin)

For now the Supabase dashboard **is** the admin panel; there is deliberately no public admin page.

- **Change a status:** *Table Editor → feedback →* click the `status` cell → pick a value. It shows on the site immediately.
  Allowed values: `new`, `investigating`, `planned`, `in_progress`, `fixed`, `closed`.
- **Hide / show a report:** untick or tick `visible`. Hidden rows disappear from the public list at once.
- **Delete spam:** delete the row (and the file under *Storage → feedback-attachments* if it has one).
- **See an upload:** the row's `attachment_path` is the file's path inside *Storage → feedback-attachments*.
- **Approve before publishing:** by default new reports are public immediately. To review first, run
  `alter table public.feedback alter column visible set default false;` in the SQL editor, then tick `visible`
  on the ones you approve.
- **Later:** a custom admin page would need real authentication (a logged-in admin role and its own RLS policy).
  Not built, on purpose.

## Limits you should know about

- **Spam:** there is no rate limiting at the database. The form has a hidden honeypot field and a 45-second cooldown
  per browser, which stops casual abuse but not a determined script. Hide or delete junk in the dashboard. If it becomes
  a problem, put an Edge Function with CAPTCHA in front of inserts.
- **Everything is public text.** The site shows user text as plain text (never HTML), but players are told not to post
  personal information. You are responsible for hiding anything inappropriate.
- **Free tier:** projects can be paused after a stretch of inactivity, and storage/bandwidth are limited. A paused
  project makes the site show "feedback temporarily unavailable" until you resume it in the dashboard.
- **Upvotes / likes** are not built yet. They would need a second table and a once-per-person rule.
