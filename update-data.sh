#!/bin/bash
# Update vw-sharan.json with latest Marktplaats listings
# Usage: ./update-data.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MP_DIR="$SCRIPT_DIR/../marktplaats-go"
OUTPUT_FILE="$SCRIPT_DIR/vw-sharan.json"

# Check if mp tool exists
if [[ ! -x "$MP_DIR/mp" ]]; then
    echo "Building mp tool..."
    (cd "$MP_DIR" && devbox run go build -o mp ./cmd/mp)
fi

echo "Fetching VW Sharan listings from Marktplaats..."
echo "  - Brand: Volkswagen"
echo "  - Model: Sharan"
echo "  - Fuel: Benzine"
echo "  - Seats: 7+"
echo "  - Max price: €20.000"
echo "  - Location: 7941HS"
echo ""

"$MP_DIR/mp" search \
    -c volkswagen \
    --model sharan \
    --fuel benzine \
    --seats-from 7 \
    --price-to 20000 \
    -p 7941HS \
    --details \
    > "$OUTPUT_FILE"

# Count results
COUNT=$(jq '.count' "$OUTPUT_FILE")
TOTAL=$(jq '.total_count' "$OUTPUT_FILE")

echo ""
echo "Done! Saved $COUNT of $TOTAL listings to $OUTPUT_FILE"
