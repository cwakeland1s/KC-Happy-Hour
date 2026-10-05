# KC Happy Hour

A static website cataloging happy hour deals across the Kansas City metro — sortable by city/neighborhood and cuisine, with a live "happening now" indicator.

## Running locally

No Node or Python required — everything is plain HTML/CSS/JS. There's a tiny PowerShell static file server included (needed because browsers block `fetch()` on `file://` URLs):

```powershell
powershell -ExecutionPolicy Bypass -File "serve.ps1"
```

Then open `http://localhost:8080/` in a browser.

## Project structure

- `index.html` — page markup
- `assets/css/styles.css` — design system (light/dark theme, responsive layout)
- `assets/js/app.js` — filtering, search, sorting, "happening now" logic, detail modal
- `data/venues.json` — the venue dataset the site reads (182 venues as of latest build)
- `data/raw/*.json` — raw research data by region, before normalization
- `normalize.ps1` — transforms `data/raw/*.json` into the final `data/venues.json` (maps cuisines to a controlled vocabulary, expands day ranges, parses time windows, assigns city/region)

## Updating the data

1. Add or edit entries in `data/raw/*.json` (or add a new raw file — any `.json` file in that folder gets picked up). Each entry needs: `name`, `address`, `neighborhood`, `cuisine`, `days`, `hours`, `deals`, `source`.
2. Re-run the normalizer:
   ```powershell
   powershell -ExecutionPolicy Bypass -File "normalize.ps1"
   ```
3. Refresh the browser — `data/venues.json` is fetched fresh on every load (no build step).

## Data notes

Deals and hours were compiled from restaurant websites, local happy-hour aggregators (HappyHourKC, KC's Daily Pour), and food-press roundups (Feast Magazine, CityLifestyle, Visit KC). Restaurant happy hours change often — treat this as a strong starting point, not a guarantee, and a periodic re-verification pass is worthwhile before relying on exact prices.

**Coverage:** Downtown & Midtown KC (Crossroads, River Market, Power & Light, Westport, Midtown, Plaza, Brookside, Waldo, West Bottoms, Columbus Park, 18th & Vine, Union Hill, Northeast KC) · Northland (North KC, Zona Rosa, Gladstone, Liberty, Parkville) · Wyandotte County & border (Village West/Legends, Strawberry Hill, Westwood) · Overland Park & Leawood (Prairie Village, Mission) · Southern & Eastern Suburbs (Lenexa, Olathe, Shawnee, Merriam, Gardner, Lee's Summit, Blue Springs, Independence, Raytown, Grandview, Martin City).

Known thin spots: Roeland Park and Argentine (KCK) turned up no venues with a published happy hour; Raytown, Grandview, Gardner, and a few others have only 1-2 confirmed venues even though more likely exist — worth a deeper pass later.

## Deploying to GitHub Pages

This repo is already git-initialized and committed locally. To publish it:

1. **Create an empty repo on GitHub** (no README/license — keep it empty): https://github.com/new — name it whatever you like, e.g. `kc-happy-hour`.
2. **Point this local repo at it and push** (run from this project folder):
   ```powershell
   git remote add origin https://github.com/<your-username>/<your-repo>.git
   git branch -M main
   git push -u origin main
   ```
3. **Turn on Pages**: on GitHub, go to your repo → **Settings → Pages** → under "Build and deployment", set **Source** to "Deploy from a branch" → branch **main**, folder **/ (root)** → Save.
4. GitHub will give you a live URL shortly (usually `https://<your-username>.github.io/<your-repo>/`) — it can take a minute or two on the first deploy.

To publish future changes (e.g. after re-running `normalize.ps1` with new venues), just:
```powershell
git add -A
git commit -m "Update venue data"
git push
```
GitHub Pages redeploys automatically on every push to `main`.
