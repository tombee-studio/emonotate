#!/usr/bin/env bash
# --ensure reuses a valid secret or bootstraps a missing one during deployment.
set -euo pipefail
case "${ENV:-}" in dev|stg|prd) ;; *) echo "Set ENV to dev, stg or prd." >&2; exit 2 ;; esac
case "${1:-}" in ''|--ensure) ;; *) echo "Usage: $0 [--ensure]" >&2; exit 2 ;; esac

region="${AWS_REGION:-ap-northeast-1}"
name="emonotate-${ENV}-django"
aws_secret=(aws secretsmanager)
location=(--region "$region")
valid='(.DJANGO_SECRET_KEY | type == "string" and length > 0) and
       (.DATABASE_URL | type == "string" and test("^postgres(ql)?://[^/]+/.+"))'
errors=$(mktemp)
trap 'rm -f "$errors"' EXIT
read_secret() {
  "${aws_secret[@]}" get-secret-value "${location[@]}" --secret-id "$name" \
    --query SecretString --output text 2>"$errors"
}
existing=false
if current=$(read_secret); then
  existing=true
  if [[ "${1:-}" == --ensure ]]; then
    if jq -e "$valid" >/dev/null 2>&1 <<<"$current"; then exit 0; fi
    echo "$name ($region) の設定を確認してください。更新するには ENV=$ENV bash scripts/setup-secrets.sh を実行してください。" >&2
    exit 1
  fi
elif grep -Fq '(ResourceNotFoundException)' "$errors"; then
  current='{}'
else
  cat "$errors" >&2
  exit 1
fi

if [[ "${1:-}" == --ensure && ! -t 0 ]]; then
  echo "$name ($region) が見つかりません。端末で ENV=$ENV bash scripts/setup-secrets.sh を実行してください。" >&2
  exit 1
fi
echo "$name ($region) の設定を入力してください。" >&2
if "$existing"; then
  read -rs -p 'DJANGO_SECRET_KEY（Enterで現在の値を使用）: ' key
else
  read -rs -p 'DJANGO_SECRET_KEY（新規環境はEnterで生成、移行時は既存の鍵）: ' key
fi
echo >&2
if [[ -z "$key" ]]; then
  if "$existing"; then key=$(jq -er '.DJANGO_SECRET_KEY | strings | select(length > 0)' <<<"$current")
  else key=$(openssl rand -hex 48)
  fi
fi
# Resolve only a named project and the requested environment's branch.
neon_url() {
  local project branch aliases projects branches
  case "$ENV" in
    stg) project=${NEON_STG_PROJECT_ID:-}; branch=${NEON_STG_BRANCH:-}; aliases='["stg","staging"]' ;;
    prd) project=${NEON_PRD_PROJECT_ID:-}; branch=${NEON_PRD_BRANCH:-}; aliases='["prd","prod","production"]' ;;
    dev) project=${NEON_DEV_PROJECT_ID:-}; branch=${NEON_DEV_BRANCH:-}; aliases='["dev","develop","development"]' ;;
  esac
  project=${project:-${NEON_PROJECT_ID:-}}
  if [[ -z "$project" ]]; then
    local org_args=()
    if [[ -n "${NEON_ORG_ID:-}" ]]; then org_args=(--org-id "$NEON_ORG_ID"); fi
    projects=$(neon projects list ${org_args[@]+"${org_args[@]}"} --output json </dev/null) || return 1
    project=$(jq -er '
      (if type == "array" then . else .projects end) |
      map(select(.name == "emonotate")) |
      if length == 1 then .[0].id else empty end' <<<"$projects") || return 1
  fi
  if [[ -z "$branch" ]]; then
    branches=$(neon branches list --project-id "$project" --output json </dev/null) || return 1
    branch=$(jq -er --argjson aliases "$aliases" '
      (if type == "array" then . else .branches end) |
      map(select(.name as $name | $aliases | index($name) != null)) |
      if length == 1 then .[0].id else empty end' <<<"$branches") || return 1
  fi
  neon connection-string "$branch" --project-id "$project" --pooled --ssl require </dev/null
}

if command -v neon >/dev/null && db_url=$(neon_url) && [[ "$db_url" =~ ^postgres(ql)?://[^[:space:]]+$ ]]; then
  echo "$ENV 用の接続URLをNeonから取得しました。" >&2
else
  echo "Neonから $ENV の接続先を確定できませんでした。" >&2
  read -rs -p "$ENV 用のNeon接続URL（DATABASE_URL）: " db_url
  echo >&2
fi
# Pass credentials via stdin to the CLI, including when updating an existing secret.
payload=$(DJANGO_KEY_INPUT="$key" DB_URL_INPUT="$db_url" jq -c \
  '. + {DJANGO_SECRET_KEY: env.DJANGO_KEY_INPUT, DATABASE_URL: env.DB_URL_INPUT}' <<<"$current")
if ! jq -e "$valid" >/dev/null 2>&1 <<<"$payload"; then
  echo '有効なPostgreSQL接続URLとDjango秘密鍵が必要です。' >&2
  exit 1
fi

if "$existing"; then
  "${aws_secret[@]}" put-secret-value "${location[@]}" --secret-id "$name" \
    --secret-string file:///dev/stdin <<<"$payload" >/dev/null
elif ! "${aws_secret[@]}" create-secret "${location[@]}" --name "$name" \
    --secret-string file:///dev/stdin --tags "Key=Project,Value=emonotate" "Key=Env,Value=$ENV" \
    <<<"$payload" >/dev/null 2>"$errors"; then
  if [[ "${1:-}" == --ensure ]] && grep -Fq '(ResourceExistsException)' "$errors"; then
    if current=$(read_secret) && jq -e "$valid" >/dev/null 2>&1 <<<"$current"; then exit 0; fi
  fi
  cat "$errors" >&2
  echo "$name の登録を確認してください。" >&2
  exit 1
fi
echo "$name を保存しました。" >&2
