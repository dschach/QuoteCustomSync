trigger OppSyncTrigger on Opportunity(after update) {
	new QuoteSyncHandler().syncOpportunities(Trigger.new, Trigger.oldMap);
}