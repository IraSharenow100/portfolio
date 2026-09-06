# Setup Instructions

## What this is

A restructured version of your site using Quarto instead of plain HTML files. The finance content is now split into 6 separate, focused pages instead of one long page, all connected through a "Finance" dropdown menu in the navigation bar at the top of every page. Adding a future page means adding one file plus one line in `_quarto.yml` — the navigation updates everywhere automatically.

## 1. Install Quarto (one-time, on your own computer)

Go to: https://quarto.org/docs/get-started/

Download the installer for your operating system (Windows or Mac) and run it, same as installing any normal program. This gives your computer a `quarto` command.

## 2. Install R packages this site may use

Open R (or RStudio if you have it) and run:

```r
install.packages(c("tidyverse", "gt"))
```

## 3. Unzip this folder

Unzip the `quarto-site.zip` file I gave you. Keep the folder structure exactly as it is — don't move files around individually.

## 4. Preview the site locally

Open a terminal (Mac: Terminal app; Windows: Command Prompt or PowerShell). Navigate into the unzipped folder — for example:

```
cd Downloads/quarto-site
```

Then run:

```
quarto preview
```

This opens a live preview in your browser. Click through the Finance dropdown menu to see all six pages. Leave this running — if you edit any `.qmd` file and save it, the preview updates automatically.

## 5. Create the GitHub repository (or reuse your existing "portfolio" one)

Since you already have a `portfolio` repository with the old HTML files, the cleanest path is:

1. On your computer, delete the old files from your local copy of the repo (or start this Quarto folder as the new content).
2. We'll do this together step by step when you're ready — don't delete anything on GitHub itself yet.

## 6. Render and publish

```
quarto render
```

This creates a `docs` folder with the finished website. Then, using GitHub Desktop or the upload method you're used to, upload the entire contents of this folder (including the `docs` folder) to your `portfolio` repository.

In GitHub: repo → Settings → Pages → set source to "Deploy from branch" → branch `main`, folder `/docs`.

## Folder structure

```
quarto-site/
├── _quarto.yml              site config, navigation menu
├── index.qmd                About / landing page
├── styles.css
└── finance/
    ├── index.qmd             Finance overview page
    ├── credit-rating.qmd
    ├── going-concern.qmd
    ├── state-auditor.qmd
    ├── tran.qmd
    ├── tax-collections.qmd
    ├── credit-rating-chart.png
    ├── tran-chart.png
    └── rptt-chart.png
```

## Adding a new page later

1. Create a new `.qmd` file in the right folder (e.g. `finance/new-topic.qmd`).
2. Add one line to `_quarto.yml` under the Finance menu, pointing to it.
3. Run `quarto preview` to check it, then `quarto render` and re-upload the `docs` folder.

That's the whole process — no need to touch any other page's file.
