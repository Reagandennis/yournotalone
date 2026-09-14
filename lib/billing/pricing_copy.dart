/// Every offer claim in one place.
///
/// The store is the only source of prices — RevenueCat returns them
/// localised, and the paywall shows those whenever it can reach the store.
/// Nothing here quotes a price: a hard-coded one went stale the moment the
/// Play Console prices changed, and was in the wrong currency for most
/// users anyway (Play charges in Ksh in Kenya).
///
/// This wording used to be written out in ten different files, so changing
/// the offer meant leaving nine stale claims behind. Keep it here, and
/// update it when the offer itself changes.
library;

/// How the offer is described where no store data is shown.
///
/// Both plans start with a free trial, but not the same length (monthly 7
/// days, yearly 1 month), so this never names a length. If the trials are
/// ever removed in Play Console, this becomes a false claim — change it.
const introOffer = 'you can try it free first';

/// Sentence-ending version, capitalised for the start of a line.
const introOfferSentence = 'Every plan starts with a free trial.';
