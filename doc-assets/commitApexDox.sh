#!/bin/sh

# Run this AFTER running ApexDox so all your files are set up properly.
npm run prettier:docs

git add --all
git commit -a -m "docs(ApexDox): update ApexDox" -m "Update ApexDox"