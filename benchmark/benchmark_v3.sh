#!/bin/bash
cd "$(dirname "$0")"
LXPEN="../lxpen"

B='\033[1m'
G='\033[0;32m'
R='\033[0;31m'
Y='\033[1;33m'
C='\033[0;36m'
N='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║    LXPEN v0.3 vs Hashcat v6.2.6 — NTLM Benchmark        ║"
echo "║    CPU-only, same machine, same 20 hashes                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# ── 20 test passwords, 5 tiers ──
PASSWORDS=(
    "password"          # T1: trivial
    "123456"
    "admin"
    "qwerty"
    "password123"       # T2: word+digits
    "admin123"
    "shadow99"
    "dragon69"
    "Michael1994"       # T3: name+year
    "Jessica2024"
    "Mehmet1994"
    "Shadow99"
    "P@ssw0rd123"       # T4: l33t/symbol/TR
    "h4ck3r666"
    "Galatasaray1905!"
    "fenerbahce1907"
    "Tr0ub4dor&3"       # T5: hard
    "xK9#mZ2pLq"
    "butterfly"
    "superman1"
)

TIER_NAMES=("" "Trivial" "Trivial" "Trivial" "Trivial" "Word+Digits" "Word+Digits" "Word+Digits" "Word+Digits" "Name+Year" "Name+Year" "Name+Year" "Name+Year" "L33t/Symbol" "L33t/Symbol" "L33t/Symbol" "L33t/Symbol" "Hard" "Hard" "Hard" "Hard")

TOTAL=${#PASSWORDS[@]}

# Generate hashes
> hashes_all.txt
> hashes_hc.txt

declare -A PW_HASH
declare -A HASH_PW

for i in "${!PASSWORDS[@]}"; do
    pw="${PASSWORDS[$i]}"
    hash=$($LXPEN hash "$pw" | cut -d'>' -f2 | tr -d ' ')
    echo "$hash" >> hashes_all.txt
    echo "$hash" >> hashes_hc.txt
    PW_HASH["$pw"]="$hash"
    HASH_PW["$hash"]="$pw"
done

echo -e "${B}Test Set: $TOTAL passwords across 5 difficulty tiers${N}"
echo ""

# ════════════════════════════════════════════
# LXPEN — per-hash streaming
# ════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${C}${B}  LXPEN v0.3.0${N} — Streaming mode (early exit, 6 threads)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

declare -A LXPEN_TIME
declare -A LXPEN_TRIED
declare -A LXPEN_FOUND
LXPEN_TOTAL_OK=0
LXPEN_TOTAL_MS=0

for i in "${!PASSWORDS[@]}"; do
    pw="${PASSWORDS[$i]}"
    hash="${PW_HASH[$pw]}"

    START_NS=$(date +%s%N)
    output=$($LXPEN crack "$hash" 2>&1)
    END_NS=$(date +%s%N)
    MS=$(( (END_NS - START_NS) / 1000000 ))
    LXPEN_TOTAL_MS=$((LXPEN_TOTAL_MS + MS))

    if echo "$output" | grep -q "CRACKED"; then
        found_pw=$(echo "$output" | grep "Password:" | sed 's/.*Password: *//' | sed 's/ *║.*//')
        tried=$(echo "$output" | grep "Tried:" | sed 's/.*Tried: *//' | sed 's/ *candidates.*//')
        LXPEN_FOUND["$pw"]="1"
        LXPEN_TIME["$pw"]="$MS"
        LXPEN_TRIED["$pw"]="$tried"
        LXPEN_TOTAL_OK=$((LXPEN_TOTAL_OK + 1))
        printf "  ${G}✓${N} %-25s  %6dms  tried: %s\n" "$pw" "$MS" "$tried"
    else
        LXPEN_FOUND["$pw"]="0"
        LXPEN_TIME["$pw"]="$MS"
        LXPEN_TRIED["$pw"]="-"
        printf "  ${R}✗${N} %-25s  %6dms  (not found)\n" "$pw" "$MS"
    fi
done

echo ""
echo -e "  Total: ${G}${LXPEN_TOTAL_OK}/$TOTAL${N} cracked in ${B}${LXPEN_TOTAL_MS}ms${N}"
echo ""

# ════════════════════════════════════════════
# HASHCAT — 3.5K wordlist + best64
# ════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${Y}${B}  Hashcat v6.2.6${N} — john 3.5K + best64 rules (~228K candidates)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

WL_SM="/usr/share/john/password.lst"
rm -f hc_sm.potfile hc_sm_out.txt

START_NS=$(date +%s%N)
hashcat -m 1000 -a 0 --potfile-path=hc_sm.potfile -D 1 --force \
    hashes_hc.txt "$WL_SM" \
    -r /usr/share/hashcat/rules/best64.rule \
    -o hc_sm_out.txt --outfile-format=2 \
    --quiet 2>/dev/null || true
END_NS=$(date +%s%N)
HC_SM_MS=$(( (END_NS - START_NS) / 1000000 ))

declare -A HC_SM_FOUND
HC_SM_OK=0

if [ -f hc_sm_out.txt ]; then
    while IFS= read -r pw_line; do
        for i in "${!PASSWORDS[@]}"; do
            if [ "${PASSWORDS[$i]}" = "$pw_line" ]; then
                HC_SM_FOUND["${PASSWORDS[$i]}"]="1"
                HC_SM_OK=$((HC_SM_OK + 1))
                break
            fi
        done
    done < hc_sm_out.txt
fi

for i in "${!PASSWORDS[@]}"; do
    pw="${PASSWORDS[$i]}"
    if [ "${HC_SM_FOUND[$pw]}" = "1" ]; then
        printf "  ${G}✓${N} %-25s\n" "$pw"
    else
        printf "  ${R}✗${N} %-25s\n" "$pw"
    fi
done

echo ""
echo -e "  Total: ${G}${HC_SM_OK}/$TOTAL${N} cracked in ${B}${HC_SM_MS}ms${N}"
echo ""

# ════════════════════════════════════════════
# HASHCAT — 100K wordlist + best64
# ════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${Y}${B}  Hashcat v6.2.6${N} — 100K common + best64 rules (~6.4M candidates)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

WL_BG="/tmp/100k-common.txt"
rm -f hc_bg.potfile hc_bg_out.txt

START_NS=$(date +%s%N)
hashcat -m 1000 -a 0 --potfile-path=hc_bg.potfile -D 1 --force \
    hashes_hc.txt "$WL_BG" \
    -r /usr/share/hashcat/rules/best64.rule \
    -o hc_bg_out.txt --outfile-format=2 \
    --quiet 2>/dev/null || true
END_NS=$(date +%s%N)
HC_BG_MS=$(( (END_NS - START_NS) / 1000000 ))

declare -A HC_BG_FOUND
HC_BG_OK=0

if [ -f hc_bg_out.txt ]; then
    while IFS= read -r pw_line; do
        for i in "${!PASSWORDS[@]}"; do
            if [ "${PASSWORDS[$i]}" = "$pw_line" ]; then
                HC_BG_FOUND["${PASSWORDS[$i]}"]="1"
                HC_BG_OK=$((HC_BG_OK + 1))
                break
            fi
        done
    done < hc_bg_out.txt
fi

for i in "${!PASSWORDS[@]}"; do
    pw="${PASSWORDS[$i]}"
    if [ "${HC_BG_FOUND[$pw]}" = "1" ]; then
        printf "  ${G}✓${N} %-25s\n" "$pw"
    else
        printf "  ${R}✗${N} %-25s\n" "$pw"
    fi
done

echo ""
echo -e "  Total: ${G}${HC_BG_OK}/$TOTAL${N} cracked in ${B}${HC_BG_MS}ms${N}"
echo ""

# ════════════════════════════════════════════
# PER-HASH COMPARISON TABLE
# ════════════════════════════════════════════
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                      PER-HASH COMPARISON TABLE                           ║"
echo "╠═════════════════════════╦════════╦══════════╦════════════╦════════════════╣"
printf "║ %-23s ║ %-6s ║ %-8s ║ %-10s ║ %-14s ║\n" "Password" "Tier" "LXPEN" "HC (3.5K)" "HC (100K)"
echo "╠═════════════════════════╬════════╬══════════╬════════════╬════════════════╣"

for i in "${!PASSWORDS[@]}"; do
    pw="${PASSWORDS[$i]}"
    tier="${TIER_NAMES[$((i+1))]}"

    if [ "${LXPEN_FOUND[$pw]}" = "1" ]; then
        lx="${LXPEN_TIME[$pw]}ms"
    else
        lx="MISS"
    fi

    if [ "${HC_SM_FOUND[$pw]}" = "1" ]; then
        hc_sm="✓"
    else
        hc_sm="MISS"
    fi

    if [ "${HC_BG_FOUND[$pw]}" = "1" ]; then
        hc_bg="✓"
    else
        hc_bg="MISS"
    fi

    printf "║ %-23s ║ %-6s ║ %8s ║ %10s ║ %14s ║\n" "$pw" "$tier" "$lx" "$hc_sm" "$hc_bg"
done

echo "╠═════════════════════════╬════════╬══════════╬════════════╬════════════════╣"
printf "║ %-23s ║ %-6s ║ %8s ║ %10s ║ %14s ║\n" "TOTAL CRACKED" "" "$LXPEN_TOTAL_OK/20" "$HC_SM_OK/20" "$HC_BG_OK/20"
printf "║ %-23s ║ %-6s ║ %8s ║ %10s ║ %14s ║\n" "TOTAL TIME" "" "${LXPEN_TOTAL_MS}ms" "${HC_SM_MS}ms" "${HC_BG_MS}ms"
printf "║ %-23s ║ %-6s ║ %8s ║ %10s ║ %14s ║\n" "WORDLIST NEEDED" "" "NO" "YES" "YES"
printf "║ %-23s ║ %-6s ║ %8s ║ %10s ║ %14s ║\n" "CANDIDATE SPACE" "" "3.9M" "~228K" "~6.4M"
echo "╚═════════════════════════╩════════╩══════════╩════════════╩════════════════╝"
echo ""

# Success rate per tier
echo "╔═══════════════════════════════════════════════════╗"
echo "║           SUCCESS RATE PER DIFFICULTY TIER        ║"
echo "╠═══════════════╦═════════╦═══════════╦═════════════╣"
printf "║ %-13s ║ %-7s ║ %-9s ║ %-11s ║\n" "Tier" "LXPEN" "HC(3.5K)" "HC(100K)"
echo "╠═══════════════╬═════════╬═══════════╬═════════════╣"

tiers=("Trivial:0:3" "Word+Digits:4:7" "Name+Year:8:11" "L33t/Symbol:12:15" "Hard:16:19")
for tier_info in "${tiers[@]}"; do
    IFS=: read -r tier_name t_start t_end <<< "$tier_info"
    lx_ok=0; sm_ok=0; bg_ok=0; tier_total=0
    for j in $(seq $t_start $t_end); do
        pw="${PASSWORDS[$j]}"
        tier_total=$((tier_total + 1))
        [ "${LXPEN_FOUND[$pw]}" = "1" ] && lx_ok=$((lx_ok + 1))
        [ "${HC_SM_FOUND[$pw]}" = "1" ] && sm_ok=$((sm_ok + 1))
        [ "${HC_BG_FOUND[$pw]}" = "1" ] && bg_ok=$((bg_ok + 1))
    done
    printf "║ %-13s ║ %s/4 %3d%% ║ %s/4  %3d%% ║ %s/4    %3d%% ║\n" \
        "$tier_name" "$lx_ok" "$((lx_ok*100/4))" "$sm_ok" "$((sm_ok*100/4))" "$bg_ok" "$((bg_ok*100/4))"
done
echo "╚═══════════════╩═════════╩═══════════╩═════════════╝"
echo ""
