# claude-code-statusline

A PowerShell statusline script for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that displays real-time session metrics and subscription plan usage monitoring.

## Screenshot

```
Opus 4.6 | #####----- 53% | $16.35 | 118.3k out 52.5t/s | 103m58s | Pro ##### 118.3k/19.0k 622%
```

## What It Shows

**Session metrics** (left side):
- Model name (e.g., `Opus 4.6`, `Haiku 4.5`)
- Context window usage bar + percentage
- Session cost in USD
- Output tokens + generation speed (tokens/sec)
- Session duration

**Subscription monitoring** (right side):
- Plan type (`Pro` / `Max5` / `Max20`)
- Daily usage progress bar
- Today's output tokens vs plan limit
- Usage percentage with warnings at 70% `(*)` and 90% `(!)`

## Installation

### 1. Copy the script

```powershell
# Copy statusline.ps1 to your .claude directory
Copy-Item statusline.ps1 "$env:USERPROFILE\.claude\statusline.ps1"
```

### 2. Configure Claude Code

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -Command \"& 'C:/Users/YOUR_USERNAME/.claude/statusline.ps1'\""
  }
}
```

> **Important**: Replace `YOUR_USERNAME` with your actual Windows username.

> **Note**: Use `-Command "& '...'"` instead of `-File` to ensure stdin piping works correctly.

### 3. Set your plan (optional)

Create `~/.claude/plan-config.json`:

```json
{
  "plan": "pro"
}
```

Available plans: `pro`, `max5`, `max20`. Default is `pro` if no config file exists.

## Plan Limits

These are community-estimated values from [Claude Code Usage Monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor):

| Plan | Output Token Limit | Cost Limit | Message Limit |
|------|-------------------|------------|---------------|
| Pro | 19,000 | $18 | 250 |
| Max5 | 88,000 | $35 | 1,000 |
| Max20 | 220,000 | $140 | 2,000 |

> **Disclaimer**: These are not official Anthropic numbers. Actual limits may differ.

## How It Works

1. Claude Code pipes session JSON data to the script via stdin
2. The script reads the current session's tokens, cost, and context usage
3. It also reads `~/.claude/stats-cache.json` for today's historical usage across all sessions
4. Combines current session + historical data to show daily totals against plan limits

### Data Sources

| Data | Source |
|------|--------|
| Current session metrics | Claude Code statusline API (stdin JSON) |
| Daily historical usage | `~/.claude/stats-cache.json` |
| Plan configuration | `~/.claude/plan-config.json` |

### Limitations

- `stats-cache.json` is only updated when sessions end, so historical daily data may lag behind
- Current session tokens are added on top to compensate for this delay
- Plan limits are per 5-hour session window in Anthropic's system, but displayed here as daily totals for simplicity

## Requirements

- Windows with PowerShell 5.1+
- Claude Code CLI

## License

MIT
