#!/bin/bash

sfdx update
npm install
#npm update
#npm install --save-dev eslint-plugin-prettier
#npm install --save-dev prettier prettier-plugin-apex
#npm install --save-dev @salesforce/eslint-config-lwc@latest @lwc/eslint-plugin-lwc@latest @salesforce/eslint-plugin-lightning@latest eslint-plugin-import eslint-plugin-jest
#npm install --save-dev eslint-config-prettier

# upgrade all packages to latest versions
npm update
npm ci

# show outdated packages
npm outdated