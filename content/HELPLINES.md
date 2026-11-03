# Crisis helplines: review checklist

Who to call depends on where someone is, not on their phone's language
(design §7a). The crisis screen picks a country from the phone's region.
"Change country" lets someone pick another one, and the choice is kept on
the device.

The list lives in `lib/support/helplines.dart`, not in the content
snapshot, on purpose:

- It's in the app the moment the crisis screen opens, with nothing to load
  or parse, so nothing can fail at that moment.
- A bad download can't break it or swap a number.
- Every change goes through code review and `test/helplines_test.dart`.

A corrected number therefore ships with an app release. If numbers ever
need to change faster than that, they can move into the snapshot later.

## How the gate works

Each country entry (`CrisisRegion`) has `verified` and records where each
number came from: `source` on every line, `emergencySource` for the
emergency number.

- **Every entry ships `verified: false`** until a person has worked
  through the checklist below.
- **Release builds** show only `verified: true` entries. For any other
  country they fall back to the older list in
  `lib/support/crisis_resources.dart` (`crisisRegions`: Kenya, Greece, UK,
  US), and failing that to the international list (Find a Helpline,
  Befrienders Worldwide).
- **Builds with drafts on** (debug, or `--dart-define=L10N_DRAFTS=true`)
  show every entry. Unchecked ones carry a red "Draft: these numbers
  haven't been checked yet" line, so testers can see them without taking
  them as checked.

## Checking a country

Do this for one country at a time, and only from the official source:
never from a search snippet, a blog or an AI answer.

1. Open each `source` URL. Confirm all of these:
   - The service exists and runs nationally (or in the area the `detail`
     says).
   - The number is exactly as written.
   - The hours and who it's for are as written.
   - Calls are free if the detail says so.
2. Check the emergency number against `emergencySource` or the
   government's own page.
3. **Ring the number**, or text it for SMS lines, from a phone in that
   country if possible. Hang up politely once it connects, or note what
   you heard.
4. Read `name` and `detail` as someone in crisis would. Are they short,
   plain and correct? The `detail` is in English for now. Translate it if
   the country's language is one the app has.
5. Set `verified: true` on the entry. In the pull request, write the date
   and who checked it.
6. Run `flutter test test/helplines_test.dart test/crisis_test.dart`.

Re-check every verified entry **every six months** and whenever a service
announces a change. Numbers move: several countries got new 3-digit
national lines between 2021 and 2024.

## What's listed, and what still needs deciding

| Country | Emergency | Lines (source) | Notes for the reviewer |
|---|---|---|---|
| Kenya (KE) | 999 | Befrienders Kenya +254 722 178 177 (befrienderskenya.org); Kenya Red Cross 1199 (redcross.or.ke) | The older list also has **Niskize +254 718 227 440**. I couldn't confirm that number, so it's left out of the new entry. 112 also works in Kenya. |
| Greece (GR) | 112 | 1018 Klimaka suicide line (klimaka.org.gr); 10306 Ministry of Health support line (moh.gov.gr); 1056 Smile of the Child SOS (hamogelo.gr) | **1056 is the Smile of the Child line for children, not a general suicide line.** The national suicide line is 1018. Confirm 10306 still runs (it started during COVID). The older list has 116 111, also run by Smile of the Child. |
| United Kingdom (GB) | 999 | Samaritans 116 123 (samaritans.org); Shout, text SHOUT to 85258 (giveusashout.org) | Consider NHS 111, option 2 (mental health, England only). |
| United States (US) | 911 | 988 Lifeline, call or text (988lifeline.org); Crisis Text Line, text HOME to 741741 (crisistextline.org) | |
| Ireland (IE) | 112 | Samaritans 116 123 (samaritans.org/ireland); Pieta 1800 247 247 (pieta.ie); text HELLO to 50808 (text50808.ie) | 999 also works. |
| France (FR) | 112 | 3114 (3114.fr) | 15 (SAMU) is the medical emergency number; consider showing it. SOS Amitié left out: confirm its current number first. |
| Germany (DE) | 112 | TelefonSeelsorge 0800 111 0 111 (also 0800 111 0 222, 116 123) (telefonseelsorge.de) | |
| Spain (ES) | 112 | 024 (sanidad.gob.es/linea024) | Teléfono de la Esperanza left out until checked. |
| Belgium (BE) | 112 | Zelfmoordlijn 1813, Dutch (zelfmoord1813.be); Centre de Prévention du Suicide 0800 32 123, French (preventionsuicide.be) | No German-language line listed. |
| Switzerland (CH) | 112 | 143 Die Dargebotene Hand / La Main Tendue (143.ch); 147 Pro Juventute, young people (147.ch) | 144 is the ambulance number. |
| Canada (CA) | 911 | 9-8-8, call or text (988.ca); Kids Help Phone 1-800-668-6868, text CONNECT to 686868 (kidshelpphone.ca) | |
| Mexico (MX) | 911 | Línea de la Vida 800 911 2000 (gob.mx/salud/conadic) | Check that the source page still names the line. |
| Argentina (AR) | 911 | Centro de Asistencia al Suicida 135, Buenos Aires; (011) 5275-1135 elsewhere (asistenciaalsuicida.org.ar) | Check the free national 0800 number on their site and add it if it's current. |
| Colombia (CO) | 123 | **none yet** | No national line I'm sure of. Candidates to check: Línea 192 option 4 (Ministry of Health) and Bogotá's Línea 106. Until then the screen shows 123 and the international list. |
| Singapore (SG) | 995 | Samaritans of Singapore 1767 (sos.org.sg) | 999 is the police. Check the national mindline 1771 and add it if confirmed. |
| Malaysia (MY) | 999 | Befrienders KL 03-7627 2929 (befrienders.org.my) | Check Talian HEAL 15555 (Ministry of Health) and add it if confirmed. |
| Taiwan (TW) | 119 | 1925 MOHW line (mohw.gov.tw); Lifeline 1995 (life1995.org.tw) | 110 is the police. |
| Hong Kong (HK) | 999 | Samaritan Befrienders 2389 2222 (sbhk.org.hk); The Samaritans 2896 0000 (samaritans.org.hk) | Check the government's 18111 mental-health line and add it if confirmed. |
| Australia (AU) | 000 | Lifeline 13 11 14 (lifeline.org.au); Beyond Blue 1300 22 4636 (beyondblue.org.au) | |

The `emergencySource` links go to the relevant government or service home
page. Replace each one with the exact page when you check it.

Countries not listed get the international list. To add one, append a
`CrisisRegion` to `countryHelplines` with `verified: false` and a `source`
for every number, then work through the checklist above.
