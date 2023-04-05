#!/bin/sh

# Run this AFTER running ApexDox so all your files are set up properly.
npm run prettier:docs

branch=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
if [ $branch == "main" ]
then
		cd docs
		git add .
		git commit -m "docs(ApexDox): update ApexDox"
fi