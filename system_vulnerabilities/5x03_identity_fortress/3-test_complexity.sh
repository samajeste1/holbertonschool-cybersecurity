#!/bin/bash
# Test password complexity enforcement

echo '=== Password Complexity Testing ==='
echo ""

echo "Testing password policy enforcement..."
echo ""

TEST_NUM=0
PASSED=0
FAILED=0
TOTAL=5

# Iterate over defined test passwords using for loop
for test_pass in 'password' 'Password123' 'Ab1!' 'auditor2024' 'Str0ng!P@ssw0rd#2024'; do
    TEST_NUM=$((TEST_NUM + 1))

    echo "Test $TEST_NUM: \"$test_pass\""

    # Attempt password change using passwd command and capture output with stderr redirection
    OUTPUT=$(echo '$test_pass' | passwd auditor 2>&1)
    EXIT_CODE=$?

    # Also test with pwscore as fallback
    PWSCORE_OUTPUT=$(echo "$test_pass" | pwscore 2>&1)
    PWSCORE_EXIT=$?

    # Validate rejection reasons using grep for BAD PASSWORD patterns
    if echo "$OUTPUT" | grep -qi "BAD PASSWORD" 2>/dev/null; then
        REASON=$(echo "$OUTPUT" | grep -i "BAD PASSWORD" 2>&1)
        echo "  Result: REJECTED"
        echo "  Reason: $REASON"
        if [ "$test_pass" != "Str0ng!P@ssw0rd#2024" ]; then
            echo "  Verdict: PASS ✓"
            PASSED=$((PASSED + 1))
        else
            echo "  Verdict: FAIL (expected acceptance)"
            FAILED=$((FAILED + 1))
        fi
    elif [ "$PWSCORE_EXIT" -ne 0 ]; then
        echo "  Result: REJECTED"
        echo "  Reason: $PWSCORE_OUTPUT"
        if [ "$test_pass" != "Str0ng!P@ssw0rd#2024" ]; then
            echo "  Verdict: PASS ✓"
            PASSED=$((PASSED + 1))
        else
            echo "  Verdict: FAIL (expected acceptance)"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "  Result: ACCEPTED"
        echo "  Score: $PWSCORE_OUTPUT"
        if [ "$test_pass" = "Str0ng!P@ssw0rd#2024" ]; then
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
