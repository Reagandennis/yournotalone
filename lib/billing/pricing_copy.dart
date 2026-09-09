/// Every price and offer claim in one place.
///
/// The store is the real source of prices — RevenueCat returns them
/// localised, and the paywall shows those whenever it can reach the store.
/// These strings are the fallback shown when it can't, plus the offer
/// wording used by the upgrade sheets, which have no store data at all.
///
/// They used to be written out in ten different files, so changing a price
/// meant leaving nine stale claims behind. Keep them here.
library;

/// Introductory price for the first month.
const introPrice = '\$2.59';

/// What it costs from month two.
const monthlyPrice = '\$5.99';

/// The yearly plan.
const yearlyPrice = '\$60';

/// How the intro offer is described where no price is shown.
///
/// Deliberately not a percentage: the discount changes whenever a price
/// does, and store prices are localised per country, so a hard number is a
/// claim that goes stale or is simply wrong somewhere. $introPrice against
/// $monthlyPrice is 57% off — "less than half price" stays true.
const introOffer = 'your first month is less than half price';

/// Sentence-ending version, capitalised for the start of a line.
const introOfferSentence = 'Your first month is less than half price.';
