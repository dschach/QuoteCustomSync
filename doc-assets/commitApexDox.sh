#!/bin/sh

# Run this AFTER running ApexDox so all your files are set up properly.
npm run prettier:docs

cd docs
git add .
git commit -m "docs(ApexDox): update ApexDox"