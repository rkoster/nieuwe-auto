#!/bin/bash
# Generate sharan-vergelijking.md from vw-sharan.json
# Usage: ./update-markdown.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_FILE="$SCRIPT_DIR/vw-sharan.json"
OUTPUT_FILE="$SCRIPT_DIR/sharan-vergelijking.md"

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: $INPUT_FILE not found. Run ./update-data.sh first."
    exit 1
fi

echo "Generating sharan-vergelijking.md from vw-sharan.json..."

# Get current date in Dutch format
DATE=$(date "+%-d %B %Y" | sed 's/January/januari/;s/February/februari/;s/March/maart/;s/April/april/;s/May/mei/;s/June/juni/;s/July/juli/;s/August/augustus/;s/September/september/;s/October/oktober/;s/November/november/;s/December/december/')

# Generate markdown using jq
jq -r --arg date "$DATE" '
def price_class:
  if . < 700000 then "€5k - €7k"
  elif . < 1000000 then "€7k - €10k"
  elif . < 1300000 then "€10k - €13k"
  elif . < 1500000 then "€13k - €15k"
  elif . < 1700000 then "€15k - €17k"
  else "€17k - €20k"
  end;

def format_price:
  (. / 100) | floor | tostring | 
  gsub("(?<a>[0-9])(?<b>[0-9]{3})$"; "\(.a).\(.b)") |
  "€" + .;

def format_mileage:
  if . then
    (. | tostring | gsub("(?<a>[0-9])(?<b>[0-9]{3})$"; "\(.a).\(.b)")) + " km"
  else "onbekend"
  end;

def transmission_short:
  if . then
    if (. | test("Automaat|DSG"; "i")) then "**Automaat (DSG)**"
    else "Handgeschakeld"
    end
  else "onbekend"
  end;

def is_dsg:
  if . then (. | test("Automaat|DSG"; "i")) else false end;

# Group listings by price class
(.listings | sort_by(.price)) as $sorted |

# Count by price class
($sorted | group_by(.price | price_class) | map({class: .[0].price | price_class, count: length})) as $counts |

# Header
"# Volkswagen Sharan Prijsvergelijking €5.000 - €20.000\n\nZoekdatum: \($date)\n\n## Samenvatting\n\n**Totaal gevonden:** \(.count) Sharans (alleen benzine, 7+ zits) in prijsklasse €5k-20k\n\n| Prijsklasse | Aantal | Typische Motor | Transmissie |\n|-------------|--------|----------------|-------------|\n" +

# Summary table
($sorted | group_by(.price | price_class) | map(
  "| " + (.[0].price | price_class) + " | " + (length | tostring) + " | " +
  (map(.cylinderCapacity // 1400) | (add / length) | if . > 1600 then "1.4/2.0 TSI" else "1.4 TSI" end) + " | " +
  (map(select(.vehicleTransmission | is_dsg)) | length | tostring) + "/" + (length | tostring) + " automaat |"
) | join("\n")) +

"\n\n---\n\n" +

# Group by price class and output each listing
($sorted | group_by(.price | price_class) | map(
  "## Prijsklasse " + (.[0].price | price_class | gsub("€"; "€ ") | gsub("k"; ".000")) + "\n\n" +
  (to_entries | map(
    "### " + (.key + 1 | tostring) + ". " + .value.title + " - " + (.value.price | format_price) + 
    (if .value.lastOwnerType == "Particulier" then " - **Particulier**" 
     elif .value.numberOfOwners == 1 then " - **1e Eigenaar**"
     else "" end) + "\n\n" +
    "| Kenmerk | Waarde |\n|---------|--------|\n" +
    "| **ID** | [" + .value.id + "](https://link.marktplaats.nl/" + .value.id + ") |\n" +
    "| **Zitplaatsen** | " + (.value.vehicleSeatingCapacity // "7") + " |\n" +
    "| **Motor** | " + (
      if .value.cylinderCapacity then
        ((.value.cylinderCapacity / 1000) | tostring) + " TSI " + ((.value.enginePower // 150) | tostring) + " PK"
      else "1.4 TSI"
      end
    ) + " |\n" +
    "| **Transmissie** | " + (.value.vehicleTransmission | transmission_short) + " |\n" +
    "| **Bouwjaar** | " + (.value.productionDate // "onbekend") + " |\n" +
    "| **Km-stand** | " + (.value.mileage | format_mileage) + " |\n" +
    (if .value.apkExpiry then "| **APK tot** | " + .value.apkExpiry + " |\n" else "" end) +
    (if .value.numberOfOwners then "| **Eigenaren** | " + (.value.numberOfOwners | tostring) + " |\n" else "" end) +
    "| **Kleur** | " + (.value.color // "onbekend") + " |\n" +
    (if (.value.options | length) > 0 then
      "| **Opties** | " + (.value.options[:8] | join(", ")) + 
      (if (.value.options | length) > 8 then " +" + ((.value.options | length) - 8 | tostring) + " meer" else "" end) + " |\n"
    else "" end) +
    "\n---\n\n"
  ) | join(""))
) | join("")) +

# Recommendations section
"## Aanbevelingen\n\n" +

# Find best in each category
"### Laagste Prijs\n" +
($sorted | first | "- [" + .title + "](" + .url + ") - " + (.price | format_price) + "\n\n") +

"### Beste Automaat onder €10k\n" +
($sorted | map(select(.price < 1000000 and (.vehicleTransmission | is_dsg))) | first // null |
  if . then "- [" + .title + "](" + .url + ") - " + (.price | format_price) + "\n\n"
  else "- Geen gevonden\n\n" end) +

"### Laagste Km-stand\n" +
($sorted | map(select(.mileage != null and .mileage > 0)) | sort_by(.mileage) | first // null |
  if . then "- [" + .title + "](" + .url + ") - " + (.mileage | format_mileage) + " - " + (.price | format_price) + "\n\n"
  else "- Onbekend\n\n" end) +

"### 1e Eigenaar\n" +
($sorted | map(select(.numberOfOwners == 1)) | 
  if length > 0 then
    map("- [" + .title + "](" + .url + ") - " + (.price | format_price)) | join("\n") + "\n\n"
  else "- Geen gevonden\n\n" end) +

"---\n\n## Belangrijke Aandachtspunten VW Sharan\n\n" +
"### Motor/Aandrijflijn\n" +
"- **1.4 TSI:** Beste keuze - wegenbelasting ~€307-335/kwartaal\n" +
"- **2.0 TSI:** Meer vermogen (200 PK), iets hogere belasting\n" +
"- **DSG versnellingsbak:** Check onderhoud (olie elke 60.000km)\n" +
"- **Distributieketting:** 1.4 TSI heeft ketting (geen vervanging nodig)\n\n" +
"### Checklist Bezichtiging\n" +
"- [ ] NAP-check (km-stand)\n" +
"- [ ] Onderhoudsboekje compleet\n" +
"- [ ] DSG servicehistorie\n" +
"- [ ] Schuifdeuren testen\n" +
"- [ ] Alle 7 stoelen uitproberen\n" +
"- [ ] Panoramadak werking\n" +
"- [ ] Roestvorming wielkasten\n"
' "$INPUT_FILE" > "$OUTPUT_FILE"

# Count lines
LINES=$(wc -l < "$OUTPUT_FILE")
echo "Done! Generated $OUTPUT_FILE ($LINES lines)"
