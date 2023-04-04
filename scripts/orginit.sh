#!/bin/bash

echo "Clearing namespace"
sed -i "" "s|\"namespace\": \"\"|\"namespace\": \"\"|" sfdx-project.json

echo "Cleaning previous scratch org..."
sfdx force:org:delete -p -u ChangeMe

echo "Creating new scratch org"
sfdx force:org:create -f config/project-scratch-def.json --durationdays 10 -a ChangeMe -s

echo "Pushing metadata"
sfdx force:source:push

#echo "Assigning Permissions"
#sfdx force:user:permset:assign -n PermSetName

echo "Adding sample data"
sfdx force:data:tree:import -p ./data/data-plan.json

echo "Opening org"
sfdx force:org:open

echo "Org is set up"