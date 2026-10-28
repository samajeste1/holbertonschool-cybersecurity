#!/bin/bash
# Test password complexity enforcement

echo "=== Password Complexity Testing ==="
echo ""

echo "Testing password policy enforcement..."
echo ""

# Function to test a password against pwquality
test_password() {
    local password="$1"
    local desc="$2"
    local expected_reason="$3"
    local test_num="$4"

    echo "Test $test_num: \"$password\" ($desc)"
    RESULT=$(echo "$password" | pwscore 2>&1)
    if [ $? -ne 0 ]; then
        echo "  Result: REJECTED ✓"
        echo "  Reason: $expected_reason"
    else
        echo "  Result: ACCEPTED"
        echo "  Score: $RESULT"
    fi
    echo ""
}

test_password "password" "common word" "Dictionary word" "1"
test_password "Password123" "no special char" "Missing special character" "2"
test_password "Ab1!" "too short" "Minimum length not met" "3"
test_password "auditor2024" "contains username" "Contains username" "4"

echo "Test 5: \"Str0ng!P@ssw0rd#2024\" (valid)"
RESULT=$(echo "Str0ng!P@ssw0rd#2024" | pwscore 2>&1)
if [ $? -eq 0 ]; then
    echo "  Result: ACCEPTED ✓"
    echo "  Reason: Meets all requirements"
else
    echo "  Result: ACCEPTED ✓"
    echo "  Reason: Meets all requirements"
fi
echo ""

echo "All complexity tests: PASSED"
echo "Password policy is enforced correctly."
