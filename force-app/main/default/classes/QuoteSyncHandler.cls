/**
 * @description QuoteSyncHandler class that contains all the logic that uses the
 * QuoteSyncUtil. This class exposes methods to sync the Opportunity, Quote,
 * OpportunityLineItem and QuoteLineItem objects and should ideally be called
 * from each object's TriggerHandler
 *
 * @author {@link [Salesforce Labs](https://github.com/SalesforceLabs)}
 * @since  2014 Original Author
 *
 * @author {@link [David Schach](https://github.com/dschach)}
 * @since 2022-08 New trigger handler framework
 * @since 2022-10 Converted to Custom Metadata
 * @since 2023-04 Refine Quote Sync with new Quote fields
 * @since 2023-04 Remove trigger framework
 *
 * @group OppQuoteSync
 * @see QuoteSyncUtil
 */
@SuppressWarnings('PMD.AvoidGLobalModifier')
global without sharing class QuoteSyncHandler {
	/**
	 * If true, exit OppLineItem trigger handler
	 */
	global static Boolean stopOppLine = false;
	/**
	 * If true, exit Opp trigger handler
	 */
	global static Boolean stopOpp = false;
	/**
	 * If true, exit QuoteLineItem trigger handler
	 */
	global static Boolean stopQuoteLine = false;
	/**
	 * If true, exit Quote trigger handler
	 */
	global static Boolean stopQuote = false;

	/**
	 * @description Deactivate all QuoteSync triggers
	 */
	public static void bypassAll() {
		stopOpp = true;
		stopOppLine = true;
		stopQuote = true;
		stopQuoteLine = true;
	}

	/**
	 * @description Reactivate all QuoteSync triggers
	 */
	public static void clearAllBypasses() {
		stopOpp = false;
		stopOppLine = false;
		stopQuote = false;
		stopQuoteLine = false;
	}
}