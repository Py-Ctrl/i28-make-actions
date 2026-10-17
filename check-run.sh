#!/bin/bash
# 查询最近一次 Actions 构建进度（本机无需 gh，用 git 缓存的凭证）
# 用法: bash check-run.sh [run_id]
set -e
REPO="Py-Ctrl/i28-make-actions"

CRED=$(printf "protocol=https\nhost=github.com\n\n" | git credential fill 2>/dev/null)
U=$(echo "$CRED" | grep -i '^username=' | head -1 | cut -d= -f2-)
P=$(echo "$CRED" | grep -i '^password=' | head -1 | cut -d= -f2-)

API="https://api.github.com/repos/$REPO/actions/runs"
if [ -n "$1" ]; then
    URL="$API/$1"
else
    URL="$API?per_page=1"
fi

curl -s -u "$U:$P" -H "Accept: application/vnd.github+json" "$URL" \
  | python3 -c '
import json,sys
d=json.load(sys.stdin)
runs = d.get("workflow_runs",[d])
for r in runs:
    print("run      :", r["id"], r["html_url"])
    print("status   :", r["status"], r.get("conclusion") or "")
    print("branch   :", r["head_branch"], "|", r["display_title"])
    print("started  :", r["run_started_at"], "| updated:", r["updated_at"])
    for j in r.get("jobs", []) if "jobs" in r else []:
        print("  job:", j["name"], j["status"], j.get("conclusion") or "")
'
