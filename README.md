# Ultra Terminal

Portable terminal with **automatic language detection**, **on-demand downloadable runtimes** from official repositories (Node, Python, Go, Rust, .NET, Java, Deno, Bun, PHP, Git, VS Build Tools) and integrated **Claude Code**.

- 🎨 **Dynamic Theme** — frame color changes depending on the language you use
- 🤖 **Autocomplete Tab** — local + AI via Gemini 2.5 Flash Lite (optional)
- 🖥️ **Monitor status** — CPU/RAM/SWAP
- 🌐 **Multilingual** — `en` (default) / `pt`
- ⚡ **Persistent History ↑/↓**

![](https://github.com/programador-powershell/images/blob/main/exemplo.png)
---

## Installation

### Clone

```bash
git clone https://github.com/<your-username>/ultra-terminal.git
cd ultra-terminal
windows.exe

```

## Usage

### Interactive Mode (REPL)

```bash
ut.exe # Windows
```

### Single Command

```bash
ut npm install express
ut python script.py
ut claude login
ut go build
```

The **first time** you use a command of In a given language, the runtime is automatically downloaded from the official website (~30 MB for Node, ~10 MB for Python, etc.). Next time it will go directly.

---

## Claude Code

```bash
ut claude login # OAuth via browser (once)
ut claude logout # remove credentials (instantaneous, does not install anything)
ut claude '<prompt>' # send prompt
ut claude # Claude's interactive REPL

```
---
## Monitor
```
  CPU[||||||||||||||||||||          45.2%]   
  Mem[|||||||||||||          1.42G/7.70G]    
  Swp[|                      120M/2.00G]  
```
![](https://github.com/programador-powershell/images/blob/main/logo.png)

## Autocomplete with AI (Gemini)

Tab autocompletes locally (built-ins, runtimes, folder files).

For smart suggestions via Gemini 2.5 Flash Lite (free):

1. Get a key at **https://aistudio.google.com/apikey**
2. In the REPL: `mcp google <your_key>`
3. Check: `mcp status`

The key is saved in `.ut_config.json` in the `ut` folder.

```bash
mcp google <api_key> # registers key
mcp status # shows current status
mcp clear # removes key
```

---

## Supported Languages

| Runtime | Commands | Source |
|---|---|---|
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

`cd` in a project folder → theme changes automatically:

| Present File | Detected Language |
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

## Internal Commands

| Command | Description | 
|---|---|
| `list` | List runtimes and status |
| `where <name>` | Runtime path on disk |
| `remove <name>` | Uninstall runtime |
| `history` | Command history |
| `language <en\|pt>` | Interface language |
| `mcp google <api_key>` | Configure Gemini key |
| `mcp status` | MCP/AI status |
| `clear` | Clear screen |
| `cd`, `pwd`, `exit` | Navigation |
| `help` | Help |

---

## REPL Shortcuts

| Key | Action |
|---|---|
| ↑ / ↓ | History |
| ← / → | Move cursor |
| Home / End | Home / End |
| **Tab** | Autocomplete (local + AI) |
| Esc | Clear line |
| Enter | Run |

---

## Repo Structure

```
ultra-terminal/
├── windows.exe
└── README.md
```

---

## Compatibility

| OS | Architectures |
|---|---|
| Windows 10 / 11 | x64 |
