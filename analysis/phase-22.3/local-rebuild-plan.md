# Phase 22.3 — Local Rebuild Plan (T1)

**Status (updated 2026-09-20): Docker Desktop 4.91 and WSL 2 are installed (by the owner). The full CLI stack is BLOCKED — `storage-api:v1.72.1` exits 139 (segfault) reproducibly, even on a freshly booted host with over 5 GB free, while Postgres and Realtime run fine. The database reproducibility gate was therefore completed by running `supabase/postgres:17.6.1.167` directly: PASS on two clean rebuilds. See `baseline-verification-record.md`. The procedure below remains the plan for when the Storage runtime works.**

## 1. Availability check (2026-09-19)

| Item | Result |
|---|---|
| `docker` CLI | **not on PATH** |
| Docker Desktop | **not installed** (default path absent) |
| `wsl.exe` | present; WSL / VirtualMachinePlatform feature state not readable without elevation |
| CPU firmware virtualization (`Win32_Processor.VirtualizationFirmwareEnabled`) | reports **False**. This can be a false negative when a hypervisor is already active; otherwise virtualization must be enabled in UEFI/BIOS |
| RAM | 15.7 GB (sufficient; the local Supabase stack needs roughly 4–7 GB) |
| Supabase CLI | 2.117.0 installed |
| Repository link state | not linked to any project (`supabase/.temp/cli-latest` only) |

## 2. Prerequisites (owner action; installs need owner approval)

1. **Virtualization:**
   - Task Manager → Performance → CPU → "Virtualization: Enabled".
   - If it shows Disabled, enable Intel VT-x / AMD-V (SVM) in UEFI/BIOS setup.
2. **WSL 2** (admin PowerShell): `wsl --install`, then reboot, then `wsl --status` should show default version 2.
3. **Docker Desktop for Windows** with the WSL 2 backend:
   - install from docker.com;
   - start it;
   - `docker version` must show both Client and Server.
   
   Licence note: Docker Desktop is free for personal use and small businesses; larger organisations need a paid subscription. That is for the owner to confirm.
4. **Disk:** about 5–8 GB for the Supabase images.

## 3. Rebuild procedure (to run after the prerequisites; local only)

Every value here is local-only. **No production secret, key or data is used.**

```powershell
# 1. Scratch copy for the gate, so the working tree does not get a config.toml yet
#    (keeps the repo free of anything auto-applicable until B1 promotion)
$work = "$env:TEMP\stagerz-t1"; Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $work | Out-Null; Set-Location $work
supabase init                     # local config.toml only in the scratch dir

# 2. Place the baseline as the only migration, and the seeds
New-Item -ItemType Directory supabase\migrations -Force | Out-Null
Copy-Item <repo>\supabase\migrations\20260919120000_stagerz_baseline.sql supabase\migrations\
Get-Content <repo>\supabase\seed\showcase.sql, <repo>\supabase\seed\fixtures.sql | Set-Content supabase\seed.sql -Encoding utf8

# 3. Start the stack and apply migrations + seed
supabase start                    # prints the local API URL (http://127.0.0.1:54321) and local keys
supabase db reset                 # applies 20260919120000 then seed.sql

# 4. Reproducibility gate
#    Run <repo>\supabase\verify\fingerprint.sql in the local Studio SQL editor
#    (http://127.0.0.1:54323), or via psql on port 54322, and compare its
#    "exact" block with <repo>\supabase\verify\expected-production.json.
#    Every key must match. The "environment" block is informational.

# 5. Edge Functions (local)
Copy-Item <repo>\supabase\functions supabase\ -Recurse
supabase functions serve --no-verify-jwt --env-file .\local.env
#    local.env holds LOCAL-ONLY values, e.g.
#    STAGERZ_MAINTENANCE_SECRET=<random local string>, STAGERZ_ALLOWED_ORIGIN=http://localhost:8080

# 6. Frontend against the local stack
#    Serve the repository root on http://localhost:8080 (any static server),
#    then once in the browser console:
#      localStorage.setItem('stagerz:local-supabase-key', '<publishable/anon key printed by supabase start>')
#    Reload. Sign in with fixture-owner@stagerz.test; the magic link arrives
#    in the local mail catcher (the Inbucket/Mailpit URL printed by supabase start).
```

**The gate is PASS when:**
1. `supabase db reset` completes without error;
2. every `exact` fingerprint key matches production;
3. the seeds load;
4. a fixture account can sign in locally and see the fixture collaboration.

**If a key mismatches:** fix the **generator** (`gen-baseline` logic), never hand-edit the output. Then regenerate, re-check determinism, and re-run.

**Expected sensitive points** (see `reproducibility-design.md` §2):
- the platform default grants on a fresh local stack (`relation_grants`, `function_grants`, `default_privileges` keys);
- the `auth.users` trigger;
- the `storage.objects` policies.

## 4. After PASS

- Promote the baseline, following `supabase/MIGRATIONS.md` steps 2–3; each step needs approval.
- Record the result in `analysis/phase-22.3/`.
- Only then consider a cloud T2 environment and the project rename.
