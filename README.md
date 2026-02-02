# devlog

Daily struggles and occasional wins. This repository contains a collection of daily logs and a detailed hardware inventory for the H15 Beast server, which is automatically compiled into a static microsite.

## 🚀 Quick Start

### Create a Log Entry
To create a new daily log, use the **AI Assistant** with the `create_log_entry` skill.

1. Tell the assistant: `"Create a log entry for today"`
2. Provide a title, summary, tags, and content when prompted.
3. The assistant will:
   - Determine the correct date.
   - Check for existing logs.
   - Reference and update the hardware inventory if applicable.
   - Format everything with consistent frontmatter.

### Manual Logs
If creating manually, place markdown files in `content/log/YYYY-MM-DD.md`. Use the following frontmatter:

```yaml
---
title: My Log Title
date: 2026-02-02T13:45:00Z
summary: A brief overview
tags: [setup, hardware]
---
```

## 🖥️ Hardware Inventory
Hardware details are stored in `content/hardware/`. 
- Use `[[slug|Display Text]]` to link to hardware components from logs.
- The inventory tracks status (Ordered, Received, Installed) and price.

## 🛠️ Microsite Build

### Local Build
Ensure you have the [Dart SDK](https://dart.dev/get-dart) installed.

1. Install dependencies: `dart pub get`
2. Run the build script: `dart scripts/build_site.dart`
3. The output will be in the `build/` directory.

### Deployment
Deployment is automated via GitHub Actions (`.github/workflows/deploy.yml`). Pushing to the `main` branch will automatically build and deploy the site to GitHub Pages.

## 📁 Structure
- `.agent/skills/`: Custom AI automation skills.
- `content/log/`: Daily log entries.
- `content/hardware/`: Individual hardware component details.
- `scripts/`: Build scripts and templates for the microsite.
