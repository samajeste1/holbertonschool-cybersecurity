#!/usr/bin/env python3
"""
tests.py - Unit tests for BreachCheck.

Run with: python3 tests.py
"""

import unittest

from breach_check import check_policy
from utils import clean_data, hash_password, validate_line


class TestValidateLine(unittest.TestCase):
    """Tests for utils.validate_line."""

    def test_valid_line(self) -> None:
        """A well-formed email:password line is accepted."""
        self.assertTrue(validate_line("user@mail.com:Secret123"))

    def test_invalid_separator(self) -> None:
        """A ';' separator is rejected."""
        self.assertFalse(validate_line("bob@gmail.com;password"))

    def test_invalid_email(self) -> None:
        """A first part that is not an email is rejected."""
        self.assertFalse(validate_line("bobgmail.com:password"))

    def test_missing_password(self) -> None:
        """A line without password is rejected."""
        self.assertFalse(validate_line("bob@gmail.com:"))

    def test_missing_email(self) -> None:
        """A line without email is rejected."""
        self.assertFalse(validate_line(":password"))

    def test_password_only(self) -> None:
        """A bare password is rejected."""
        self.assertFalse(validate_line("password"))


class TestCheckPolicy(unittest.TestCase):
    """Tests for breach_check.check_policy."""

    def test_short_password(self) -> None:
        """A password shorter than 8 characters is WEAK."""
        self.assertEqual(check_policy("Ab1!"), "WEAK")

    def test_numeric_password(self) -> None:
        """A digits-only password is WEAK."""
        self.assertEqual(check_policy("12345678901"), "WEAK")

    def test_letters_only_password(self) -> None:
        """A letters-only password is WEAK."""
        self.assertEqual(check_policy("abcdefghij"), "WEAK")

    def test_common_password(self) -> None:
        """A password from the common list is WEAK."""
        self.assertEqual(check_policy("12345678"), "WEAK")

    def test_compliant_password(self) -> None:
        """A long password mixing letters and digits is COMPLIANT."""
        self.assertEqual(check_policy("Sup3rS3cur3Pass"), "COMPLIANT")


class TestHashPassword(unittest.TestCase):
    """Tests for utils.hash_password."""

    def test_deterministic(self) -> None:
        """The same input always gives the same hash."""
        self.assertEqual(hash_password("secret", "salt"),
                         hash_password("secret", "salt"))

    def test_salt_changes_hash(self) -> None:
        """A different salt gives a different hash."""
        self.assertNotEqual(hash_password("secret", "salt1"),
                            hash_password("secret", "salt2"))

    def test_sha256_format(self) -> None:
        """The hash is a 64-character hex string."""
        digest = hash_password("secret", "salt")
        self.assertEqual(len(digest), 64)
        int(digest, 16)


class TestCleanData(unittest.TestCase):
    """Tests for utils.clean_data."""

    def test_example(self) -> None:
        """Whitespace, empty lines and comments are removed."""
        self.assertEqual(
            clean_data([" user@mail.com:pass ", "", "# Comment"]),
            ["user@mail.com:pass"],
        )


if __name__ == "__main__":
    unittest.main()
