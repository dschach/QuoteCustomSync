trigger QuoteLineSyncTrigger on QuoteLineItem(before insert, after insert, after update) {
	new QuoteSyncHandler().syncQuoteLines(Trigger.new, Trigger.newMap);
}