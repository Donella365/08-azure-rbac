#!/usr/bin/env bash
# Publishes Lab 08 (Azure RBAC) to GitHub under Donella365, private first.
# Run this from inside the 08-rbac/ project folder.

set -e

echo "Switching to Donella365 GitHub account..."
gh auth switch -u Donella365

echo "Initializing git repo..."
git init
git add .
git commit -m "Initial commit: Lab 08 Azure RBAC on FS01"

echo "Creating private GitHub repo..."
gh repo create Donella365/08-azure-rbac --private --source=. --remote=origin

echo "Pushing to GitHub..."
git branch -M main
git push -u origin main

echo ""
echo "Done. Repo is private: https://github.com/Donella365/08-azure-rbac"
echo "Review it, confirm no secrets or personal screenshots leaked in,"
echo "then flip it public from the repo Settings page when ready."
