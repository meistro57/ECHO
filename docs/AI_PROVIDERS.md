# ECHO AI Provider Architecture

## 🛡️ Security Boundary & Production Proxy Plan

> [!CAUTION]
> **Client-Side API Key Warning**:
> Direct API access using API keys stored in environment variables or client configuration is designed **exclusively for local development and prototyping**.
> 
> Distributing a client build containing embedded API keys exposes those keys to extraction. In production, ECHO must connect to a **trusted server-side proxy** (e.g. Node.js, Python FastAPI, or Cloudflare Worker) that validates client authentication and securely proxies requests to OpenRouter or DeepSeek.

---

## 🏗️ Architecture Overview

Phase 5 introduces a provider-neutral AI connectivity layer (`client/scripts/ai/`). This layer operates asynchronously and is **100% decoupled from game locomotion and the deterministic APC Brain**.

```
AIService (Node)
├── HTTPRequest (Child Node)
├── OpenRouterProvider (AIProvider)
└── DeepSeekProvider (AIProvider)
```

```
User Action (F3) / UI Panel
       │
       ▼
   AIService ─────► Select Active AIProvider ─────► Build AIRequest
       │                                                   │
       ▼                                                   ▼
HTTPRequest (Async) ◄────────────────────────────── POST /chat/completions
       │
       ▼
  AIResponse ──────► Validate ECHO_ONLINE ──────► F1 Debug HUD Overlay
```

---

## ⚙️ Environment Variables & Configuration

Configuration is loaded from operating system environment variables via `OS.get_environment()`.

| Variable | Default Value | Description |
| --- | --- | --- |
| `ECHO_AI_ENABLED` | `false` | Master toggle enabling or disabling AI network connectivity. |
| `ECHO_AI_PROVIDER` | `openrouter` | Active provider selection (`openrouter`, `deepseek`, or `disabled`). |
| `ECHO_AI_TIMEOUT_SECONDS` | `20` | HTTP request timeout in seconds. |
| `OPENROUTER_API_KEY` | *(empty)* | OpenRouter Bearer API key. |
| `OPENROUTER_MODEL` | `deepseek/deepseek-v4-flash` | Model identifier for OpenRouter calls. |
| `OPENROUTER_BASE_URL` | `https://openrouter.ai/api/v1` | OpenRouter API base URL. |
| `OPENROUTER_SITE_URL` | `https://github.com/meistro57/ECHO` | Optional HTTP-Referer header for OpenRouter attribution. |
| `OPENROUTER_APP_NAME` | `ECHO` | Optional X-Title header for OpenRouter attribution. |
| `DEEPSEEK_API_KEY` | *(empty)* | Direct DeepSeek Bearer API key. |
| `DEEPSEEK_MODEL` | `deepseek-v4-flash` | Model identifier for direct DeepSeek calls. |
| `DEEPSEEK_BASE_URL` | `https://api.deepseek.com` | Direct DeepSeek API base URL. |

A template file (`.env.example`) is provided at the repository root. Copying `.env.example` to `.env` allows local development variable setting. `.env` and `.env.*` files are explicitly ignored by `.gitignore`.

---

## 🔌 Supported AI Providers

### 1. OpenRouter Provider (`OpenRouterProvider`)
- **Endpoint**: `{OPENROUTER_BASE_URL}/chat/completions` (Default: `https://openrouter.ai/api/v1/chat/completions`)
- **Headers**:
  - `Content-Type: application/json`
  - `Authorization: Bearer <OPENROUTER_API_KEY>`
  - `HTTP-Referer: <OPENROUTER_SITE_URL>`
  - `X-Title: <OPENROUTER_APP_NAME>`

### 2. Direct DeepSeek Provider (`DeepSeekProvider`)
- **Endpoint**: `{DEEPSEEK_BASE_URL}/chat/completions` (Default: `https://api.deepseek.com/chat/completions`)
- **Headers**:
  - `Content-Type: application/json`
  - `Authorization: Bearer <DEEPSEEK_API_KEY>`

---

## 🧪 Test Message Protocol

Connectivity validation executes a fixed, non-gameplay request:

- **System Prompt**: `"You are the connectivity test for ECHO. Reply with exactly ECHO_ONLINE."`
- **User Prompt**: `"Return the required test response."`
- **Validation**: The test succeeds (`ONLINE`) **only** if the trimmed assistant response content equals `"ECHO_ONLINE"`.

---

## 🛑 Failure Handling & Safety Rules

1. **No Game Interruption**: AI network calls run asynchronously via Godot's `HTTPRequest` node. The main game loop and physics never pause or block.
2. **Deterministic Brain Protection**: AI connectivity failures, timeouts, rate limits, or missing keys have **zero effect** on APC locomotion, state machine, or navigation.
3. **Secret Protection**: Authorization headers and raw API keys are created internally in memory and are **never logged**, printed, stored in scene resources, or exposed on the Debug HUD.
