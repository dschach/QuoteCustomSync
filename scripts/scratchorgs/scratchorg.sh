#!/bin/bash

echo "Clearing namespace"
sed -i "" "s|\"namespace\": \"\"|\"namespace\": \"\"|" sfdx-project.json

echo "Cleaning previous scratch org..."
sf org delete scratch --no-prompt --target-org QuoteSyncOrg

echo "Creating new scratch org"
sf org create scratch --definition-file config/project-scratch-def.json --duration-days 10 --alias QuoteSyncOrg --no-namespace --set-default

echo "Pushing metadata"
sf project deploy start --source-dir sfdx-source/QuoteCustomSync
sf project deploy start --source-dir sfdx-source/unpackaged

#echo "Assigning Permissions"
sf org assign permset --name QuoteSyncTester

echo "Adding sample data"
sf data import tree --plan ./data/data-plan.json

echo "opening org"
sf org open

echo "Org is set up"