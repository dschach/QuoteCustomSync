#!/bin/sh

# Run this AFTER running ApexDox so all your files are set up properly.

branch=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
if [ "$branch" == "main" ]
then
    npm run prettier:docs
		cd docs
		git add .
		git commit -m "docs(ApexDox): update ApexDox"
fi