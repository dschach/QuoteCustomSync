[![On Push](https://github.com/dschach/QuoteCustomSync/actions/workflows/ci.yml/badge.svg)](https://github.com/dschach/QuoteCustomSync/actions/workflows/ci.yml)
[![PR Validation](https://github.com/dschach/QuoteCustomSync/actions/workflows/pr.yml/badge.svg)](https://github.com/dschach/QuoteCustomSync/actions/workflows/pr.yml)
[![Release Workflow](https://github.com/dschach/QuoteCustomSync/actions/workflows/release-please.yml/badge.svg)](https://github.com/dschach/QuoteCustomSync/actions/workflows/release-please.yml)

# Custom Quote Sync

Metadata-driven Quote-Opportunity custom field synchronization

(based on Salesforce Labs[Custom Quote Sync](https://appexchange.salesforce.com/listingDetail?listingId=a0N30000003Iop5EAC))

## [Changelog](./CHANGELOG.md)

## ToDo items

1. Look at the permission set granted - you'll probably want to fix that
1. Update API version to the latest and greatest

## General Description

This app allows you to configure custom fields mapping between Opportunity and Quote, and custom fields on OpportunityLineItem and QuoteLineItem. The mapped fields will be synchronized automatically similar to the standard Quote Sync process.

## Configuration

### What's Included

This package comes with some code (and installs a base trigger handler package) to sync custom fields between Opportunities and Quotes (and their Line Items), but it needs to know which fields to map between the proper objects.

This is achieved via Custom Metadata Types. Indicate the Opportunity and Quote (or Line Item) field names on the correct CMT and the package will do the rest.
