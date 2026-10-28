#!/bin/bash
# Test password complexity enforcement

echo '=== Password Complexity Testing ==='
echo ""

echo "Testing password policy enforcement..."
echo ""

# Define test passwords: "password:description:should_fail"
TEST_PASSWORDS=(
    "password:common word:yes"
    "Password123:no special char:yes"
    "Ab1!:too short:yes"
    "auditor2024:contains username:yes"
    "Str0ng!P@ssw0rd#2024:valid complex password:no"
)

TEST_NUM=0
PASSED=0
FAILED=0
TOTAL=${#TEST_PASSWORDS[@]}

# Create a test user for password testing if needed
TEST_USER="testcomplexity$$"

# Iterate over defined test passwords using for loop
for entry in "${TEST_PASSWORDS[@]}"; do
    TEST_NUM=$((TEST_NUM + 1))
    # Parse the entry
    pw=$(echo "$entry" | cut -d: -f1)
    desc=$(echo "$entry" | cut -d: -f2)
    should_fail=$(echo "$entry" | cut -d: -f3)

    echo "Test $TEST_NUM: \"$pw\" ($desc)"

    # Attempt password change using passwd command and capture output with stderr redirection
    OUTPUT=$(echo -e "$pw\n$pw" | passwd --stdin "$USER" 2>&1 || echo -e "$pw\n$pw" | chpasswd 2>&1)
    EXIT_CODE=$?

    # Also test with pwscore as fallback
    PWSCORE_OUTPUT=$(echo "$pw" | pwscore 2>&1)
    PWSCORE_EXIT=$?

    # Validate rejection reasons using grep for BAD PASSWORD patterns
    if echo "$OUTPUT" | grep -qi "BAD PASSWORD" 2>/dev/null; then
        REASON=$(echo "$OUTPUT" | grep -i "BAD PASSWORD" 2>&1)
        echo "  Result: REJECTED"
        echo "  Reason: $REASON"
        if [ "$should_fail" = "yes" ]; then
            echo "  Verdict: PASS ✓"
            PASSED=$((PASSED + 1))
        else
            echo "  Verdict: FAIL (expected acceptance)"
            FAILED=$((FAILED + 1))
        fi
    elif [ "$PWSCORE_EXIT" -ne 0 ]; then
        echo "  Result: REJECTED"
        echo "  Reason: $PWSCORE_OUTPUT"
        if [ "$should_fail" = "yes" ]; then
            echo "  Verdict: PASS ✓"
            PASSED=$((PASSED + 1))
        else
            echo "  Verdict: FAIL (expected acceptance)"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "  Result: ACCEPTED"
        echo "  Score: $PWSCORE_OUTPUT"
        if [ "$should_fail" = "no" ]; then
            echo "  Verdict: PASS ✓"
            PASSED=$((PASSED + 1))
        else
            echo "  Verdict: FAIL (expected rejection)"
            FAILED=$((FAILED + 1))
        fi
    fi
    echo ""
done

# Use conditional logic to evaluate overall results
echo "Results: $PASSED/$TOTAL tests passed"
if [ "$FAILED" -eq 0 ]; then
    echo "All complexity tests: PASSED"
    echo "Password policy is enforced correctly."
else
    echo "Some complexity tests: FAILED"
    echo "$FAILED test(s) did not produce expected results."
fi
