trigger QuoteSyncTrigger on Quote(after insert, after update) {
	new QuoteSyncHandler().syncQuote(Trigger.new, Trigger.oldMap);
}