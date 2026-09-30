{{ config(materialized='table') }}

-- A2 matching rules, in priority order (a record uses the first that applies):
--
--   Tier 1 — id_document_number (ims) = id_number (cbs), normalized
--            (uppercased, punctuation stripped). Government/refugee ID
--            numbers are meant to be unique per person and are the strongest
--            signal we have across the two systems. Auto-merged.
--
--   Tier 2 — normalized full name (order-invariant) + date_of_birth + country
--            match exactly. No two unrelated people in this population are
--            expected to share all three; still weaker than an ID match
--            because of transliteration/typo risk, so tracked separately in
--            the report. Auto-merged.
--
--   Unmatched — neither key available (or matched nothing on the other
--            side): the record becomes its own singleton enterprise
--            identity. Not merged with anything. A same-phone-and-country
--            record that didn't clear tier 1/2 is not merged either — it is
--            surfaced to the review queue instead (int_review_queue), never
--            auto-merged on phone alone, since a phone number can belong to
--            a household rather than one person.
--
-- This intentionally under-matches rather than over-matches: a person whose
-- ID was mistyped differently in each system and whose name also doesn't
-- line up exactly will not be auto-linked. That is a conscious trade-off
-- (see DECISIONS.md) — such cases should show up as look-alike singletons
-- and/or land in the review queue via the phone/name-proximity check.

select
    *,
    case
        when id_key is not null then 'ID:' || id_key
        when name_key is not null and date_of_birth is not null and country is not null
            then 'NDC:' || name_key || '|' || date_of_birth || '|' || country
        else 'SINGLETON:' || source_system || ':' || source_id
    end as match_key,
    case
        when id_key is not null then 'id_number'
        when name_key is not null and date_of_birth is not null and country is not null
            then 'name_dob_country'
        else 'unmatched'
    end as match_tier
from {{ ref('int_party_all') }}
