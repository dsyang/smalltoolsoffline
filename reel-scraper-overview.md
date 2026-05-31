# Reel Scraper - Project Overview

## Goal

Build a tool where I paste an Instagram Reel URL, it extracts the caption/description via the Apify API, and displays it. Eventually this will save to Notion, but right now we're just focused on getting the Apify extraction working.

## Architecture

Single-file HTML app (`reel-scraper.html`). Two inputs, one output:

- **Input 1:** Apify API token (`apify_api_...`)
- **Input 2:** Instagram Reel URL
- **Output:** Extracted text (caption, author, hashtags, metrics)

No backend. Runs client-side in the browser.

## Apify Actor

We're using `apify/instagram-reel-scraper` (actor ID: `apify~instagram-reel-scraper`).

This actor accepts reel URLs. Here is the exact JSON input that works when run from the Apify Console:

```json
{
  "includeDownloadedVideo": false,
  "includeSharesCount": false,
  "includeTranscript": false,
  "resultsLimit": 27,
  "skipPinnedPosts": false,
  "username": [
    "https://www.instagram.com/reel/DVDTbdrjGqv/?igsh=NTc4MTIwNjQ2YQ=="
  ]
}
```

Note: the input field is called `username` despite accepting reel URLs.

## Current API Call

The app POSTs to the Apify sync endpoint:

```
POST https://api.apify.com/v2/acts/apify~instagram-reel-scraper/run-sync-get-dataset-items
Authorization: Bearer <token>
Content-Type: application/json
```

This endpoint starts the actor, waits for it to finish (up to 300s), and returns the dataset items directly. Docs: https://docs.apify.com/api/v2

## Current Problem

The API call fails. The app has a debug log panel (click "▸ debug log" at the bottom) that shows request/response details. The most likely issue is **CORS** — the browser may be blocked from calling `api.apify.com` directly. Other possibilities:

- The `cleanUrl()` function strips query params from the IG URL (removes `?igsh=...`). The working console input included the full URL with the query string. This may matter.
- The actor ID format `apify~instagram-reel-scraper` might need to be the internal ID (`xMc5Ga1oCONPmWJIa`) instead.
- Timeout — reel scraping takes 30-90 seconds.

## What to Do

1. Run the app, trigger a scrape, and read the debug log to identify the actual error.
2. Fix whatever is blocking the API call.
3. If CORS is the issue, the options are: use a lightweight proxy, or restructure as a local script. Pick whatever is simplest.
4. Test with this URL: `https://www.instagram.com/reel/DVDTbdrjGqv/?igsh=NTc4MTIwNjQ2YQ==`

## Future (not now)

Once extraction works, the next step is saving results to a Notion database. We have Notion MCP access and already started a "Saved Reels" database with fields: Name, URL, Caption, Platform, Author, Hashtags, Saved At. But don't build this yet — just get the Apify call working first.
