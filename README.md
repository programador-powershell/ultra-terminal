# Ultra Terminal

Portable terminal with **automatic language detection**, **on-demand downloadable runtimes** from official repositories (Node, Python, Go, Rust, .NET, Java, Deno, Bun, PHP, Git, VS Build Tools) and integrated **Claude Code**.

- 🎨 **Dynamic Theme** — frame color and prompt change with the active language
- 🤖 **Autocomplete (Tab)** — local + AI via Gemini 2.5 Flash Lite (optional)
- 🖥️ **Live monitor** — CPU / RAM / Swap bars (htop-style, color gradient)
- 🌐 **Multilingual UI** — `en` (default) / `pt`
- ⚡ **Persistent history** — `↑` / `↓`
- 📦 **Single-file installer** per OS — no extra dependencies needed

![](https://github.com/programador-powershell/images/blob/main/exemplo.png)

---

## Installation

The repo ships **3 installer scripts** — each one is fully self-contained (the app binary is embedded as base64). Just run the one for your OS:

### Windows

Double-click **`Windows.bat`**.

It extracts the embedded `setup.exe` to `%TEMP%`, runs it, then cleans up. The installer drops:

- `%LOCALAPPDATA%\UltraTerminal\app.exe`
- `%LOCALAPPDATA%\UltraTerminal\runtimes.json`
- `%LOCALAPPDATA%\UltraTerminal\Uninstall.exe`
- Start Menu shortcut → **Ultra Terminal**
- Add/Remove Programs entry

No admin needed (user-local install).

### macOS

```bash
chmod +x Mac.sh
./Mac.sh
```

Installs to `~/.local/share/UltraTerminal/` and creates `~/.local/bin/ut`.

### Linux

```bash
chmod +x Linux.sh
./Linux.sh
```

Same paths as macOS.

---

## Usage

### REPL (interactive)

```bash
ut          # Linux/macOS (or Start Menu → Ultra Terminal on Windows)
```

You'll see the fixed top frame with logo, path, tips and live CPU/RAM/Swap bars.
The prompt changes based on the language you type:

```
ut > npm install ...     →    npm > install ...
ut > python ...          →    py  > ...
ut > cargo build         →    cargo > build
```

### Single command

```bash
ut npm install express
ut python script.py
ut claude login
ut go build
```

The **first time** you use a command of a given language, the runtime is automatically downloaded from its official source (~30 MB for Node, ~10 MB for Python, etc.). Subsequent runs go straight through.

---

## Claude Code

```bash
ut claude login           # OAuth via browser (once)
ut claude logout          # remove credentials (instant, no install needed)
ut claude '<prompt>'      # send a prompt
ut claude                 # Claude's interactive REPL
```

---

## Monitor
```
  CPU[||||||||||||||||||||          45.2%]   
  Mem[|||||||||||||          1.42G/7.70G]    
  Swp[|                      120M/2.00G]  
```
![](https://github.com/programador-powershell/images/blob/main/logo.png)

---

## AI Autocomplete (Gemini)

`Tab` autocompletes locally (built-ins, runtimes, files in cwd).
For smart suggestions via **Gemini 2.5 Flash Lite** (free tier):

1. Get a key at <https://aistudio.google.com/apikey>
2. In the REPL: `mcp google <your_key>`
3. Verify: `mcp status`

The key is saved in `.ut_config.json` next to the app.

```bash
mcp google <api_key>      # register key
mcp status                # show current status
mcp clear                 # remove key
```

---

## Supported Languages

| Runtime | Commands | Source |
|---|---|---|
| Claude Code | `claude` | npm `@anthropic-ai/claude-code` |
| Node.js 22 | `node`, `npm`, `npx` | nodejs.org |
| TypeScript | (theme; runtime via Node) | — |
| Python 3.13 | `python`, `py`, `pip` | python.org |
| Go 1.23 | `go`, `gofmt` | go.dev |
| Rust | `cargo`, `rustc`, `rustup` | rust-lang.org |
| Deno | `deno` | deno.land |
| Bun | `bun`, `bunx` | bun.sh |
| OpenJDK 21 | `java`, `javac`, `jar` | adoptium.net |
| .NET 9 SDK | `dotnet` | dot.net |
| PHP 8.4 | `php` | php.net |
| Git | `git` | git-scm.com |
| VS Build Tools | `cl`, `link`, `nmake`, `msbuild` | aka.ms (Windows, requires admin) |

---

## Folder Detection

`cd` into a project folder → theme switches automatically:

| File present | Detected language |
|---|---|
| `package.json` | Node |
| `tsconfig.json` | TypeScript |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `pom.xml`, `build.gradle` | Java |
| `pyproject.toml`, `requirements.txt`, `setup.py` | Python |
| `CMakeLists.txt`, `*.cpp` | C/C++ |
| `*.csproj`, `*.sln` | .NET |
| `deno.json` | Deno |
| `bun.lockb` | Bun |

---

## Built-in Commands

| Command | Description |
|---|---|
| `list` | List runtimes and status |
| `where <name>` | Runtime path on disk |
| `remove <name>` | Uninstall a runtime |
| `history` | Command history |
| `language <en\|pt>` | UI language |
| `mcp google <api_key>` | Configure Gemini key |
| `mcp status` | MCP / AI status |
| `clear` | Clear screen below frame |
| `cd`, `pwd`, `exit` | Navigation |
| `help` | Show help |

---

## REPL Shortcuts

| Key | Action |
|---|---|
| ↑ / ↓ | History |
| ← / → | Move cursor |
| Home / End | Line start / end |
| **Tab** | Autocomplete (local + AI) |
| Esc | Clear current line |
| Enter | Run |

---

## How the installers work (for contributors)

Each installer script (Windows.bat / Mac.sh / Linux.sh) embeds its OS-specific payload as base64. To regenerate them after editing the source:

1. Edit `ut.ps1` (Windows source) or `ut.sh` (Unix source) and `runtimes.json`
2. Build Windows installer:
   ```powershell
   powershell -ExecutionPolicy Bypass -File build/windows.ps1
   powershell -ExecutionPolicy Bypass -File build/make-windows-bat.ps1
   ```
3. Build Mac/Linux installers:
   ```powershell
   powershell -ExecutionPolicy Bypass -File build/make-mac-linux.ps1
   ```
4. Commit `Windows.bat`, `Mac.sh`, `Linux.sh`

The shipped repo only needs:

```
ultra-terminal/
├── Windows.bat       # self-extracting installer (embeds setup.exe)
├── Mac.sh            # self-extracting installer (embeds ut.sh)
├── Linux.sh          # self-extracting installer (embeds ut.sh)
└──  logo.png

```

---

## Compatibility

| OS | Architectures |
|---|---|
| Windows 10 / 11 | x64 |
| Linux | x64, arm64 |
| macOS | x64 (Intel), arm64 (Apple Silicon) |



