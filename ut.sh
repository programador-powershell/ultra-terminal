#!/usr/bin/env bash
# ============================================================
#  Ultra Terminal (ut) — Linux / macOS
#  Detecta linguagem, baixa runtimes portateis, descobre stacks
#  desconhecidas via Gemini. Paridade com a versao Windows (ut.ps1).
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIMES_DIR="$SCRIPT_DIR/runtimes"
CACHE_DIR="$SCRIPT_DIR/cache"
CONFIG_PATH="$SCRIPT_DIR/runtimes.json"
LEARNED_CONFIG_PATH="$SCRIPT_DIR/runtimes-learned.json"
USER_CFG="$SCRIPT_DIR/.ut_config.json"
HISTORY_FILE="$SCRIPT_DIR/.ut_history"

mkdir -p "$RUNTIMES_DIR" "$CACHE_DIR"

# ---------- OS / Arch ----------
detect_os() {
    case "$OSTYPE" in
        darwin*) echo "mac" ;;
        linux*)  echo "linux" ;;
        msys*|cygwin*|mingw*) echo "win" ;;
        *) echo "linux" ;;
    esac
}
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "x64" ;;
        arm64|aarch64) echo "arm64" ;;
        *) echo "x64" ;;
    esac
}
OS=$(detect_os)
ARCH=$(detect_arch)
OS_KEY="${OS}_${ARCH}"

# ---------- ANSI ----------
ESC=$'\033'
A_RESET="${ESC}[0m"
A_BOLD="${ESC}[1m"
A_DIM="${ESC}[2m"
A_RED="${ESC}[31m";    A_BRED="${ESC}[91m"
A_GRN="${ESC}[32m";    A_BGRN="${ESC}[92m"
A_YEL="${ESC}[33m";    A_BYEL="${ESC}[93m"
A_BLU="${ESC}[34m";    A_BBLU="${ESC}[94m"
A_MAG="${ESC}[35m";    A_BMAG="${ESC}[95m"
A_CYN="${ESC}[36m";    A_BCYN="${ESC}[96m"
A_WHT="${ESC}[37m";    A_BWHT="${ESC}[97m"
A_GRY="${ESC}[90m"

# ---------- Profiles por linguagem ----------
declare -A LANG_NAME=(
    [node]="Node.js"   [claude]="Claude" [python]="Python" [go]="Go"
    [rust]="Rust"      [java]="Java"     [dotnet]=".NET"   [deno]="Deno"
    [bun]="Bun"        [php]="PHP"       [git]="Git"       [ruby]="Ruby"
    [typescript]="TypeScript" [cpp]="C++" [vsbuild]="VS Build"
)
declare -A LANG_COLOR=(
    [node]="$A_BGRN"   [claude]="$A_BMAG" [python]="$A_BYEL" [go]="$A_BCYN"
    [rust]="$A_BRED"   [java]="$A_BYEL"   [dotnet]="$A_BMAG" [deno]="$A_BWHT"
    [bun]="$A_YEL"     [php]="$A_MAG"     [git]="$A_BRED"    [ruby]="$A_BRED"
    [typescript]="$A_BBLU" [cpp]="$A_BBLU" [vsbuild]="$A_BBLU"
)
DEFAULT_NAME="Path"
DEFAULT_COLOR="$A_BCYN"

CURRENT_LANG=""
declare -A DISCOVERY_FAILED_CACHE=()

profile_color() {
    local lang="$1"
    [[ -n "$lang" && -n "${LANG_COLOR[$lang]:-}" ]] && echo "${LANG_COLOR[$lang]}" || echo "$DEFAULT_COLOR"
}
profile_name() {
    local lang="$1"
    [[ -n "$lang" && -n "${LANG_NAME[$lang]:-}" ]] && echo "${LANG_NAME[$lang]}" || echo "$DEFAULT_NAME"
}
get_prompt_prefix() {
    [[ -z "$CURRENT_LANG" ]] && echo "ut" || echo "$CURRENT_LANG"
}

# ---------- Mensagens ----------
info() { local c; c=$(profile_color "$CURRENT_LANG"); printf "%b[ut]%b %s\n" "$c" "$A_RESET" "$*"; }
ok()   { printf "%b[ut]%b %s\n" "$A_GRN" "$A_RESET" "$*"; }
warn() { printf "%b[ut]%b %s\n" "$A_YEL" "$A_RESET" "$*"; }
err()  { printf "%b[ut]%b %s\n" "$A_RED" "$A_RESET" "$*" >&2; }

# ---------- Python helper ----------
PY=""
if command -v python3 &>/dev/null; then PY=python3
elif command -v python &>/dev/null; then PY=python
fi
require_python() {
    [[ -z "$PY" ]] && { err "python3 nao encontrado — necessario para parsing JSON."; return 1; }
    return 0
}

# ---------- Registry (merge runtimes.json + runtimes-learned.json) ----------
get_registry() {
    require_python || return 1
    "$PY" - "$CONFIG_PATH" "$LEARNED_CONFIG_PATH" <<'EOF'
import json, os, sys
base_path, learned_path = sys.argv[1], sys.argv[2]
data = {}
try:
    with open(base_path) as f: data = json.load(f)
except Exception:
    pass
if os.path.exists(learned_path):
    try:
        with open(learned_path) as f:
            for k, v in json.load(f).items():
                data[k] = v
    except Exception:
        pass
print(json.dumps(data))
EOF
}

# Comando -> linguagem (com merge)
declare -A CMD_MAP
_cmd_map_loaded=0
load_cmd_map() {
    [[ $_cmd_map_loaded -eq 1 ]] && return
    _cmd_map_loaded=1
    require_python || return
    local data
    data=$(get_registry) || return
    while IFS='=' read -r cmd lang; do
        [[ -n "$cmd" ]] && CMD_MAP["$cmd"]="$lang"
    done < <("$PY" -c "
import json, sys
d = json.loads(sys.argv[1])
for lang, info in d.items():
    for cmd in info.get('commands', []):
        print(cmd + '=' + lang)
" "$data" 2>/dev/null)
}
invalidate_cmd_map() { _cmd_map_loaded=0; CMD_MAP=(); }

resolve_language() {
    load_cmd_map
    echo "${CMD_MAP[$1]:-}"
}

ri_field() {
    require_python || return
    local lang="$1" field="$2"
    local data
    data=$(get_registry) || return
    "$PY" -c "
import json, sys
d = json.loads(sys.argv[1])
lang, field, os_key = sys.argv[2], sys.argv[3], sys.argv[4]
if lang not in d: sys.exit(0)
info = d[lang]
plat = info.get(os_key) or info.get(os_key.split('_')[0]) or {}
if field in plat:    print(plat[field]); sys.exit(0)
if field in info:
    v = info[field]
    print(','.join(v) if isinstance(v, list) else v)
" "$data" "$lang" "$field" "$OS_KEY" 2>/dev/null
}

# ---------- Folder language detection ----------
get_folder_language() {
    local d="$PWD"
    [[ -f "$d/tsconfig.json"   ]] && { echo typescript; return; }
    [[ -f "$d/package.json"    ]] && { echo node;       return; }
    [[ -f "$d/Cargo.toml"      ]] && { echo rust;       return; }
    [[ -f "$d/go.mod"          ]] && { echo go;         return; }
    [[ -f "$d/pom.xml" || -f "$d/build.gradle" ]] && { echo java; return; }
    [[ -f "$d/pyproject.toml" || -f "$d/requirements.txt" || -f "$d/setup.py" ]] && { echo python; return; }
    [[ -f "$d/CMakeLists.txt"  ]] && { echo cpp;        return; }
    [[ -f "$d/deno.json" || -f "$d/deno.jsonc" ]] && { echo deno; return; }
    [[ -f "$d/bun.lockb"       ]] && { echo bun;        return; }
    [[ -f "$d/composer.json"   ]] && { echo php;        return; }
    [[ -f "$d/Gemfile"         ]] && { echo ruby;       return; }
    echo ""
}

# ---------- Gemini key (config) ----------
get_gemini_key() {
    [[ -n "${GEMINI_API_KEY:-}" ]] && { echo "$GEMINI_API_KEY"; return; }
    [[ ! -f "$USER_CFG" ]] && return
    require_python || return
    "$PY" -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(d.get('gemini_api_key', ''))
except: pass
" "$USER_CFG" 2>/dev/null
}

save_gemini_key() {
    require_python || return
    local key="$1"
    "$PY" -c "
import json, os, sys
p = sys.argv[1]
d = {}
if os.path.exists(p):
    try: d = json.load(open(p))
    except: d = {}
d['gemini_api_key'] = sys.argv[2]
with open(p, 'w') as f: json.dump(d, f, indent=2)
" "$USER_CFG" "$key"
}

mcp_status() {
    [[ -n "$(get_gemini_key)" ]] && echo "ON" || echo "OFF"
}

# ---------- Clipboard / Browser ----------
read_clipboard() {
    if   command -v pbpaste  &>/dev/null; then pbpaste 2>/dev/null
    elif command -v wl-paste &>/dev/null; then wl-paste --no-newline 2>/dev/null
    elif command -v xclip    &>/dev/null; then xclip -selection clipboard -o 2>/dev/null
    elif command -v xsel     &>/dev/null; then xsel -b 2>/dev/null
    else echo ""
    fi
}
open_browser() {
    local url="$1"
    case "$OS" in
        mac)   open "$url" >/dev/null 2>&1 || true ;;
        linux) xdg-open "$url" >/dev/null 2>&1 || sensible-browser "$url" >/dev/null 2>&1 || true ;;
    esac
}

# ---------- Auto-setup do MCP Gemini ----------
auto_setup_gemini() {
    [[ -n "$(get_gemini_key)" ]] && return

    echo
    printf "  %bUltra Terminal — primeiro uso%b\n" "$A_BCYN" "$A_RESET"
    echo  "  Vou abrir o Google AI Studio. Faca login, clique em 'Create API key' e em 'Copy'."
    echo  "  A chave eh detectada do clipboard. Pressione qualquer tecla para pular."
    echo

    if read -t 3 -n 1 -s _; then
        warn "Setup pulado. Use 'mcp google <chave>' depois."
        return
    fi

    open_browser "https://aistudio.google.com/apikey"

    local initial
    initial=$(read_clipboard)
    info "Aguardando voce copiar a chave (qualquer tecla cancela)..."

    local deadline=$(( $(date +%s) + 300 ))
    while (( $(date +%s) < deadline )); do
        if read -t 0.4 -n 1 -s _; then warn "Cancelado."; return; fi
        local cb
        cb=$(read_clipboard)
        if [[ -n "$cb" && "$cb" != "$initial" ]] && [[ "$cb" =~ ^AIza[0-9A-Za-z_-]{35}$ ]]; then
            save_gemini_key "$cb"
            ok "Chave Gemini detectada e salva. MCP ativo."
            draw_frame
            return
        fi
    done
    warn "Timeout. Use 'mcp google <chave>' depois."
}

# ---------- Discovery via Gemini ----------
try_discover_runtime() {
    local cmd="$1"
    [[ -z "$cmd" ]] && return 1
    [[ ${#cmd} -lt 2 || ${#cmd} -gt 25 ]] && return 1
    [[ ! "$cmd" =~ ^[a-zA-Z][a-zA-Z0-9_+.-]*$ ]] && return 1
    [[ -n "${DISCOVERY_FAILED_CACHE[$cmd]:-}" ]] && return 1
    require_python || return 1
    command -v curl &>/dev/null || return 1

    local key
    key=$(get_gemini_key)
    [[ -z "$key" ]] && { DISCOVERY_FAILED_CACHE[$cmd]=1; return 1; }

    info "Consultando Gemini sobre '$cmd'..."

    local prompt
    prompt=$(cat <<EOF
You are a runtime discovery oracle. The user typed the shell command "$cmd" but it is not in any local registry. Identify the language/SDK that owns this command and return JSON describing where to download an OFFICIAL portable archive (zip/tar.gz/tar.xz) for the platform "$OS_KEY".

Reply with ONLY a single JSON object, no markdown fences. Schema:
{
  "language": "<short lowercase identifier, e.g. swift, kotlin, zig, dart>",
  "description": "<one short sentence>",
  "commands": ["<all CLI commands shipped by this runtime, including '$cmd'>"],
  "platform": {
    "url": "<direct download URL of the OFFICIAL portable archive for $OS_KEY>",
    "archive": "<filename of the archive>",
    "extract_root": "<top-level folder when extracted, or empty>",
    "bin_subpath": "<relative path to executables, or empty>"
  },
  "confidence": "high|medium|low"
}

If you don't know an OFFICIAL portable archive URL with high confidence for $OS_KEY, set confidence to "low" and leave url empty. Never invent URLs.
EOF
)
    local body
    body=$("$PY" -c "
import json, sys
print(json.dumps({
    'contents': [{'parts':[{'text': sys.argv[1]}]}],
    'generationConfig': {'maxOutputTokens':400,'temperature':0,'response_mime_type':'application/json'}
}))" "$prompt" 2>/dev/null)

    local resp
    resp=$(curl -sS --max-time 10 -H 'Content-Type: application/json' \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$key" \
        -d "$body" 2>/dev/null) || { warn "Gemini sem resposta."; DISCOVERY_FAILED_CACHE[$cmd]=1; return 1; }

    local lang_name
    lang_name=$("$PY" - "$resp" "$cmd" "$OS_KEY" "$LEARNED_CONFIG_PATH" <<'EOF'
import json, os, sys, datetime, re
resp_str, cmd, os_key, learned_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
try:
    r = json.loads(resp_str)
    txt = r['candidates'][0]['content']['parts'][0]['text']
    p = json.loads(txt)
except Exception:
    sys.exit(0)
if not p.get('language') or not p.get('platform') or not p['platform'].get('url') or p.get('confidence') == 'low':
    sys.exit(0)
lang = re.sub(r'[^a-z0-9_-]', '', str(p['language']).lower())
if not lang: sys.exit(0)
cmds = [c for c in (p.get('commands') or []) if isinstance(c, str) and re.match(r'^[a-zA-Z][a-zA-Z0-9_+.-]*$', c)]
if cmd.lower() not in [c.lower() for c in cmds]: cmds.append(cmd.lower())
if not cmds: cmds = [cmd.lower()]
plat = p['platform']
entry = {
    'description': str(p.get('description', '')),
    'commands': cmds,
    'learned_via': 'gemini',
    'learned_at': datetime.datetime.now().isoformat(timespec='seconds'),
    os_key: {
        'url': str(plat['url']),
        'archive': str(plat.get('archive') or os.path.basename(plat['url'])),
        'extract_root': str(plat.get('extract_root') or ''),
        'bin_subpath': str(plat.get('bin_subpath') or '')
    }
}
existing = {}
if os.path.exists(learned_path):
    try: existing = json.load(open(learned_path))
    except: existing = {}
existing[lang] = entry
with open(learned_path, 'w') as f: json.dump(existing, f, indent=2)
print(lang)
EOF
)
    if [[ -z "$lang_name" ]]; then
        warn "Gemini nao identificou runtime confiavel para '$cmd'."
        DISCOVERY_FAILED_CACHE[$cmd]=1
        return 1
    fi
    invalidate_cmd_map
    ok "Stack '$lang_name' aprendida via Gemini."
    echo "$lang_name"
    return 0
}

# ---------- Download / Extract ----------
download_file() {
    local url="$1" dest="$2"
    info "Baixando $(basename "$url")..."
    if command -v curl &>/dev/null; then
        curl -L -# -o "$dest" "$url" || return 1
    elif command -v wget &>/dev/null; then
        wget -q --show-progress -O "$dest" "$url" || return 1
    else
        err "Necessario curl ou wget."; return 1
    fi
}
extract_archive() {
    local archive="$1" dest="$2"
    mkdir -p "$dest"
    case "$archive" in
        *.zip)            unzip -q "$archive" -d "$dest" ;;
        *.tar.gz|*.tgz)   tar -xzf "$archive" -C "$dest" ;;
        *.tar.xz)         tar -xJf "$archive" -C "$dest" ;;
        *.tar.bz2)        tar -xjf "$archive" -C "$dest" ;;
        *)                err "Formato nao suportado: $archive"; return 1 ;;
    esac
}

# ---------- Ensure runtime ----------
ensure_runtime() {
    local lang="$1"
    local install_dir="$RUNTIMES_DIR/$lang"
    local marker="$install_dir/.installed"

    local dep
    dep=$(ri_field "$lang" "depends_on")
    [[ -n "$dep" ]] && { ensure_runtime "$dep" >/dev/null || return 1; }

    if [[ "$lang" == "claude" ]]; then
        local bin_dir="$install_dir/node_modules/.bin"
        if [[ -f "$marker" ]]; then echo "$bin_dir"; return 0; fi
        info "Instalando Claude Code via npm..."
        mkdir -p "$install_dir"
        local node_bin
        node_bin=$(ensure_runtime "node") || return 1
        export PATH="$node_bin:$PATH"
        "$node_bin/npm" install --prefix "$install_dir" @anthropic-ai/claude-code || return 1
        date '+%Y-%m-%d %H:%M:%S' > "$marker"
        ok "Claude Code instalado."
        echo "$bin_dir"; return 0
    fi

    local url archive extract_root bin_subpath post_install
    url=$(ri_field "$lang" "url")
    archive=$(ri_field "$lang" "archive")
    extract_root=$(ri_field "$lang" "extract_root")
    bin_subpath=$(ri_field "$lang" "bin_subpath")
    post_install=$(ri_field "$lang" "post_install")

    [[ "$url" == "system" || -z "$url" ]] && { warn "$lang: instalacao pelo sistema."; echo ""; return 0; }

    local extract_dir="$install_dir"
    [[ -n "$extract_root" ]] && extract_dir="$install_dir/$extract_root"
    local bin_dir="$extract_dir"
    [[ -n "$bin_subpath" ]] && bin_dir="$extract_dir/$bin_subpath"

    if [[ -f "$marker" ]]; then echo "$bin_dir"; return 0; fi

    info "Primeira vez usando '$lang' — baixando portatil..."
    mkdir -p "$install_dir"

    [[ -z "$archive" ]] && archive=$(basename "$url")
    local archive_path="$CACHE_DIR/$archive"
    if [[ ! -f "$archive_path" ]]; then
        download_file "$url" "$archive_path" || { err "download falhou."; return 1; }
    fi
    extract_archive "$archive_path" "$install_dir" || return 1

    [[ -d "$bin_dir" ]] && { chmod -R +x "$bin_dir" 2>/dev/null || true; }

    case "$post_install" in
        install_rust)
            local ri="$install_dir/rustup-init"
            [[ -f "$ri" ]] && {
                chmod +x "$ri"
                export CARGO_HOME="$install_dir/.cargo" RUSTUP_HOME="$install_dir/.rustup"
                "$ri" -y --no-modify-path --default-toolchain stable
            } ;;
    esac

    date '+%Y-%m-%d %H:%M:%S' > "$marker"
    ok "$lang pronto."
    echo "$bin_dir"; return 0
}

# ---------- Frame fixo (logo + navbar) ----------
draw_frame() {
    local lang="${CURRENT_LANG:-}"
    local color name mcp
    color=$(profile_color "$lang")
    name=$(profile_name "$lang")
    mcp=$(mcp_status)

    local cols
    cols=$(tput cols 2>/dev/null || echo 80)

    # logo simples ASCII baseado na lang
    local logo
    case "$lang" in
        node|typescript|deno|bun) logo="◆" ;;
        python)                    logo="🐍" ;;
        rust)                      logo="🦀" ;;
        go)                        logo="🐹" ;;
        java)                      logo="☕" ;;
        ruby)                      logo="💎" ;;
        php)                       logo="🐘" ;;
        cpp)                       logo="◀▶" ;;
        dotnet)                    logo="◇" ;;
        git)                       logo="⎇" ;;
        claude)                    logo="✦" ;;
        *)                         logo="●" ;;
    esac

    clear
    local sep
    sep=$(printf '%*s' "$cols" '' | tr ' ' '─')
    local pwd_short="$PWD"
    [[ ${#pwd_short} -gt $((cols - 30)) ]] && pwd_short="...${pwd_short: -$((cols - 33))}"

    printf "  %b%s  %s%b   %bMCP: %s%b   %b%s%b\n" \
        "$color" "$logo" "$name" "$A_RESET" \
        "$A_CYN" "$mcp" "$A_RESET" \
        "$A_GRY" "$pwd_short" "$A_RESET"
    printf "%b%s%b\n" "$color" "$sep" "$A_RESET"
}

# ---------- History ----------
load_history() {
    [[ -f "$HISTORY_FILE" ]] && history -r "$HISTORY_FILE" 2>/dev/null || true
}
save_history_item() {
    [[ -z "$1" ]] && return
    history -s -- "$1" 2>/dev/null || true
    printf '%s\n' "$1" >> "$HISTORY_FILE"
}

# ---------- Built-ins ----------
show_list() {
    require_python || return
    local data
    data=$(get_registry) || return
    "$PY" - "$data" "$RUNTIMES_DIR" <<'EOF'
import json, os, sys
data = json.loads(sys.argv[1]); rdir = sys.argv[2]
GREEN='\033[32m'; GRAY='\033[90m'; CYAN='\033[36m'; RESET='\033[0m'
print()
print(CYAN + '  {:<14} {:<14} {}'.format('Linguagem','Status','Comandos') + RESET)
print('  ' + '-'*60)
for lang, info in data.items():
    marker = os.path.join(rdir, lang, '.installed')
    st = 'instalado' if os.path.exists(marker) else 'pendente'
    cmds = ', '.join(info.get('commands', []))
    color = GREEN if st == 'instalado' else GRAY
    print(color + '  {:<14} {:<14} {}'.format(lang, st, cmds) + RESET)
print()
EOF
}
remove_runtime() {
    local lang="${1:-}"
    [[ -z "$lang" ]] && { err "uso: remove <linguagem>"; return; }
    local d="$RUNTIMES_DIR/$lang"
    [[ ! -d "$d" ]] && { warn "$lang nao instalado"; return; }
    rm -rf "$d"; ok "$lang removido."
}
show_where() {
    local name="${1:-}"
    [[ -z "$name" ]] && { err "uso: where <linguagem|comando>"; return; }
    local lang
    lang=$(resolve_language "$name")
    [[ -z "$lang" ]] && lang="$name"
    local d="$RUNTIMES_DIR/$lang"
    [[ -d "$d" ]] && echo "$d" || warn "$lang nao instalado"
}
show_help() {
cat <<EOF

  ${A_BCYN}Ultra Terminal${A_RESET}

  Linguagens detectadas automaticamente. O prompt e a UI mudam pra refletir a stack.
  Stacks fora do catalogo sao descobertas via Gemini se voce configurar a chave.

  Built-ins:
    list                    linguagens registradas e status
    where <nome>            caminho do runtime instalado
    remove <nome>           desinstala runtime
    mcp status              estado da chave Gemini
    mcp google <api_key>    define a chave manualmente
    mcp clear               apaga a chave
    cd / pwd / clear / exit
    help                    esta ajuda

EOF
}
invoke_mcp() {
    local sub="${1:-}"
    case "$sub" in
        ""|status)
            local k; k=$(get_gemini_key)
            if [[ -n "$k" ]]; then ok "MCP Gemini: configurado (${k:0:6}...)"; else warn "MCP Gemini: nao configurado. Use 'mcp google <chave>'"; fi ;;
        google)
            [[ -z "${2:-}" ]] && { err "uso: mcp google <api_key>"; return; }
            save_gemini_key "$2"; ok "Chave salva. MCP ativo."; draw_frame ;;
        clear)
            require_python && "$PY" -c "
import json, os, sys
p = sys.argv[1]
if os.path.exists(p):
    try:
        d = json.load(open(p))
        d.pop('gemini_api_key', None)
        json.dump(d, open(p,'w'), indent=2)
    except: pass
" "$USER_CFG"
            ok "Chave removida."; draw_frame ;;
        *) err "subcomando mcp desconhecido: $sub" ;;
    esac
}

# ---------- Run command ----------
run_command() {
    local tokens=("$@")
    [[ ${#tokens[@]} -eq 0 ]] && return
    local cmd="${tokens[0]}"
    local rest=("${tokens[@]:1}")

    case "$cmd" in
        exit|quit) info "Saindo..."; exit 0 ;;
        list)      show_list; return ;;
        remove)    remove_runtime "${rest[0]:-}"; return ;;
        where)     show_where "${rest[0]:-}"; return ;;
        help)      show_help; return ;;
        clear|cls) draw_frame; return ;;
        pwd)       pwd; return ;;
        cd)
            local target="${rest[0]:-$HOME}"
            cd "$target" 2>/dev/null || { err "cd: '$target' nao existe"; return; }
            local fl; fl=$(get_folder_language)
            if [[ "$fl" != "$CURRENT_LANG" ]]; then CURRENT_LANG="$fl"; draw_frame; fi
            return
            ;;
        mcp)       invoke_mcp "${rest[@]:-}"; return ;;
    esac

    local lang
    lang=$(resolve_language "$cmd")

    if [[ -n "$lang" ]]; then
        local prev="$CURRENT_LANG"
        CURRENT_LANG="$lang"
        [[ "$prev" != "$lang" ]] && draw_frame

        local bin_dir
        bin_dir=$(ensure_runtime "$lang") || { return 1; }

        local extra_paths=()
        [[ -n "$bin_dir" ]] && extra_paths+=("$bin_dir")
        case "$lang" in
            rust)   export CARGO_HOME="$RUNTIMES_DIR/rust/.cargo" RUSTUP_HOME="$RUNTIMES_DIR/rust/.rustup"
                    [[ -d "$CARGO_HOME/bin" ]] && extra_paths+=("$CARGO_HOME/bin") ;;
            java)   local jr; jr=$(ri_field java extract_root); [[ -n "$jr" ]] && export JAVA_HOME="$RUNTIMES_DIR/java/$jr" ;;
            go)     export GOROOT="$RUNTIMES_DIR/go/go" ;;
            python) [[ -d "$RUNTIMES_DIR/python/bin" ]] && extra_paths+=("$RUNTIMES_DIR/python/bin") ;;
            claude) local nb; nb=$(ensure_runtime node); [[ -n "$nb" ]] && extra_paths+=("$nb") ;;
        esac

        local old_path="$PATH"
        local joined=""; for p in "${extra_paths[@]}"; do joined+="$p:"; done
        export PATH="${joined}${PATH}"

        local exe=""
        for p in "${extra_paths[@]}"; do
            [[ -x "$p/$cmd" ]] && { exe="$p/$cmd"; break; }
        done
        [[ -z "$exe" ]] && exe=$(command -v "$cmd" 2>/dev/null || true)

        if [[ -z "$exe" ]]; then
            err "Executavel '$cmd' nao encontrado em ${extra_paths[*]}"
            export PATH="$old_path"
            return 1
        fi
        "$exe" "${rest[@]}"
        local rc=$?
        export PATH="$old_path"
        return $rc
    fi

    # comando desconhecido — tenta discovery via Gemini
    local discovered
    if discovered=$(try_discover_runtime "$cmd") && [[ -n "$discovered" ]]; then
        run_command "${tokens[@]}"
        return
    fi

    # fallback gracioso: shell nativo
    if command -v "$cmd" &>/dev/null; then
        "$cmd" "${rest[@]}"
    else
        err "Comando '$cmd' nao reconhecido. Digite 'help'."
    fi
}

# ---------- REPL ----------
start_repl() {
    load_history
    CURRENT_LANG=$(get_folder_language)
    draw_frame
    auto_setup_gemini

    while true; do
        local prefix color
        prefix=$(get_prompt_prefix)
        color=$(profile_color "$CURRENT_LANG")
        printf "%b%s > %b" "$color" "$prefix" "$A_RESET"

        local line
        if ! IFS= read -r -e line; then echo; info "Saindo..."; exit 0; fi
        [[ -z "$line" ]] && continue
        save_history_item "$line"

        # tokenize via shlex
        local tokens=()
        if [[ -n "$PY" ]]; then
            while IFS= read -r -d '' tok; do
                [[ -n "$tok" ]] && tokens+=("$tok")
            done < <("$PY" -c "
import sys, shlex
try:
    for t in shlex.split(sys.argv[1]):
        sys.stdout.write(t + '\0')
except Exception:
    sys.stdout.write(sys.argv[1] + '\0')
" "$line" 2>/dev/null)
        else
            read -r -a tokens <<< "$line"
        fi
        [[ ${#tokens[@]} -eq 0 ]] && continue

        run_command "${tokens[@]}" || true
    done
}

# ---------- Entry ----------
if [[ $# -gt 0 ]]; then
    CURRENT_LANG=$(get_folder_language)
    run_command "$@"
else
    start_repl
fi
