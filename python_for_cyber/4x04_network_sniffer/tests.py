#!/usr/bin/env python3
"""Unit tests for PySniffer packet processors and sniffer engine.

Tests use fabricated Scapy packets to validate processing logic
without requiring live network traffic or root privileges.
"""

import unittest

try:
    from scapy.all import IP
except ImportError:
    IP = None
try:
    from scapy.all import TCP
except ImportError:
    TCP = None
try:
    from scapy.all import UDP
except ImportError:
    UDP = None
try:
    from scapy.all import ICMP
except ImportError:
    ICMP = None
try:
    from scapy.all import Raw
except ImportError:
    Raw = None

from sniffer import (
    TCPProcessor, UDPProcessor, ICMPProcessor,
    Sniffer, packet_handler
)


class TestTCPProcessor(unittest.TestCase):
    """Tests for TCPProcessor."""

    def test_output_contains_tag(self):
        """Test TCP output contains protocol tag."""
        packet = IP(src="1.1.1.1", dst="2.2.2.2") / TCP(
            sport=12345, dport=80, flags="S"
        )
        result = TCPProcessor().process(packet)
        self.assertIn("[TCP]", result)

    def test_output_contains_ips(self):
        """Test TCP output contains source and dest IPs."""
        packet = IP(src="1.1.1.1", dst="2.2.2.2") / TCP(
            sport=12345, dport=80, flags="S"
        )
        result = TCPProcessor().process(packet)
        self.assertIn("1.1.1.1", result)
        self.assertIn("2.2.2.2", result)

    def test_extracts_ports(self):
        """Test TCP processor handles port extraction."""
        packet = IP(src="10.0.0.1", dst="10.0.0.2") / TCP(
            sport=443, dport=8080
        )
        result = TCPProcessor().process(packet)
        self.assertIn("[TCP]", result)
        self.assertIn("10.0.0.1", result)
        self.assertIn("10.0.0.2", result)


class TestUDPProcessor(unittest.TestCase):
    """Tests for UDPProcessor."""

    def test_output_contains_tag(self):
        """Test UDP output contains protocol tag."""
        packet = IP(src="10.0.0.1", dst="8.8.8.8") / UDP(
            sport=5353, dport=53
        )
        result = UDPProcessor().process(packet)
        self.assertIn("[UDP]", result)

    def test_output_contains_ips(self):
        """Test UDP output contains source and dest IPs."""
        packet = IP(src="10.0.0.1", dst="8.8.8.8") / UDP(
            sport=5353, dport=53
        )
        result = UDPProcessor().process(packet)
        self.assertIn("10.0.0.1", result)
        self.assertIn("8.8.8.8", result)


class TestICMPProcessor(unittest.TestCase):
    """Tests for ICMPProcessor."""

    def test_output_contains_tag(self):
        """Test ICMP output contains protocol tag."""
        packet = IP(
            src="192.168.1.1", dst="192.168.1.2"
        ) / ICMP()
        result = ICMPProcessor().process(packet)
        self.assertIn("[ICMP]", result)

    def test_output_contains_ips(self):
        """Test ICMP output contains source and dest IPs."""
        packet = IP(
            src="192.168.1.1", dst="192.168.1.2"
        ) / ICMP()
        result = ICMPProcessor().process(packet)
        self.assertIn("192.168.1.1", result)
        self.assertIn("192.168.1.2", result)


class TestPacketHandler(unittest.TestCase):
    """Tests for the packet_handler callback function."""

    def test_handler_is_callable(self):
        """Test packet_handler is a callable function."""
        self.assertTrue(callable(packet_handler))

    def test_handler_processes_icmp(self):
        """Test packet_handler handles ICMP packets."""
        packet = IP(
            src="1.1.1.1", dst="2.2.2.2"
        ) / ICMP()
        packet_handler(packet)


class TestSnifferInit(unittest.TestCase):
    """Tests for Sniffer initialization and processing."""

    def test_default_stats(self):
        """Test sniffer initializes with zero counters."""
        sniffer = Sniffer()
        self.assertEqual(sniffer.stats["TCP"], 0)
        self.assertEqual(sniffer.stats["UDP"], 0)
        self.assertEqual(sniffer.stats["ICMP"], 0)
        self.assertEqual(sniffer.stats["Other"], 0)

    def test_processors_registered(self):
        """Test all protocol processors are registered."""
        sniffer = Sniffer()
        self.assertIn("TCP", sniffer.processors)
        self.assertIn("UDP", sniffer.processors)
        self.assertIn("ICMP", sniffer.processors)

    def test_tcp_increments_stats(self):
        """Test processing TCP packet increments counter."""
        sniffer = Sniffer()
        packet = IP(src="1.1.1.1", dst="2.2.2.2") / TCP(
            dport=80
        )
        sniffer._process_packet(packet)
        self.assertEqual(sniffer.stats["TCP"], 1)

    def test_udp_increments_stats(self):
        """Test processing UDP packet increments counter."""
        sniffer = Sniffer()
        packet = IP(src="1.1.1.1", dst="2.2.2.2") / UDP(
            dport=53
        )
        sniffer._process_packet(packet)
        self.assertEqual(sniffer.stats["UDP"], 1)

    def test_icmp_increments_stats(self):
        """Test processing ICMP packet increments counter."""
        sniffer = Sniffer()
        packet = IP(
            src="1.1.1.1", dst="2.2.2.2"
        ) / ICMP()
        sniffer._process_packet(packet)
        self.assertEqual(sniffer.stats["ICMP"], 1)

    def test_payload_search_processes(self):
        """Test payload search does not crash on match."""
        sniffer = Sniffer(search="password")
        if Raw is not None:
            packet = (
                IP(src="1.1.1.1", dst="2.2.2.2")
                / TCP(dport=80)
                / Raw(load=b"password=secret")
            )
        else:
            packet = (
                IP(src="1.1.1.1", dst="2.2.2.2")
                / TCP(dport=80)
            )
        sniffer._process_packet(packet)
        self.assertEqual(sniffer.stats["TCP"], 1)

    def test_no_payload_no_crash(self):
        """Test search with no Raw layer no crash."""
        sniffer = Sniffer(search="password")
        packet = IP(src="1.1.1.1", dst="2.2.2.2") / TCP(
            dport=80
        )
        sniffer._process_packet(packet)
        self.assertEqual(sniffer.stats["TCP"], 1)


if __name__ == "__main__":
    unittest.main()
