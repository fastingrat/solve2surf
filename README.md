# Solve2Surf

Solve2Surf is a lightweight captive portal extension for OpenWrt. It requires users to solve educational or logical puzzles to gain internet access. The problems are fetched dynamically from an external JSON file hosted on any object storage service (like Cloudflare R2 or AWS S3).

## Features

- Integrates natively with OpenNDS for firewall and routing abstraction.
- Supports both static (deterministic) and dynamic (API-graded) questions.
- No flash wear: Problem sets are synced to a RAM disk (`/tmp`).
- Web configuration interface via LuCI.
- Multi-architecture support (x86_64, aarch64, ramips, mediatek, ath79).

## Installation

This repository automatically builds `.apk` packages for OpenWrt 25.12+ via GitHub Actions.

1. SSH into your OpenWrt router.
2. Add the custom package repository to your router's package manager.

```bash
echo "https://fastingrat.github.io/solve2surf" >> /etc/apk/repositories.d/custom.list
```

3. Update the package list and install:

```bash
apk update
apk add --allow-untrusted solve2surf luci-app-solve2surf
```

## Configuration

1. Log into your router's web interface (LuCI).
2. Navigate to **Services > Solve2Surf**.
3. Select the network interface your guests use (e.g., `br-guest`).
4. Enter the URL to your `problems.json` file.
5. Set the access duration.
6. Check **Enable Solve2Surf** and click **Save & Apply**.

The router will download your problem set and automatically configure the captive portal on the selected interface.

## Problem Set JSON Format

The backend expects an array of JSON objects. Problem sets must be hosted publicly (or accessible via a signed URL) and conform to the following schema:

```json
[
  {
    "id": "q1",
    "type": "local",
    "question": "What is 10 + 5?",
    "expected_answer": "15",
    "duration_minutes": 30
  },
  {
    "id": "q2",
    "type": "public",
    "question": "Evaluate this logic gate: (A AND B) OR C where A=1, B=0, C=1",
    "grading_endpoint": "https://your-public-api.com/grade",
    "min_passing_score": 1,
    "duration_minutes": 120
  }
]
```

## Architecture

- **solve2surf**: The core backend executing as a standard `/etc/init.d/` service. It configures OpenNDS, manages the `cron` sync job, and provides the CGI validation script (`/www/cgi-bin/fas.sh`) via `uhttpd`.
- **luci-app-solve2surf**: The client-side Javascript view that generates the UCI configuration interface in LuCI.
