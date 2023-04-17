trigger OppLineSyncTrigger on OpportunityLineItem(before insert, after insert, after update) {
	new QuoteSyncHandler().syncOppLines(Trigger.new, Trigger.oldMap);
	return;
}