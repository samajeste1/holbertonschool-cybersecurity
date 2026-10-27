#!/usr/bin/env python3
"""PySniffer - A professional network packet sniffer built with Scapy.

Captures, filters, and analyzes network traffic in real-time.
Supports BPF filters, PCAP export, payload search, and
protocol-specific processing using a Thread/Queue architecture.
"""

import sys
import os
import argparse
import threading
from queue import Queue, Empty

try:
    from scapy.all import sniff
except ImportError:
    sniff = None
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
try:
    from scapy.all import hexdump
except ImportError:
    hexdump = None
try:
    from scapy.utils import PcapWriter
except ImportError:
    PcapWriter = None


class PacketProcessor:
    """Base class for protocol-specific packet processors."""

    def process(self, packet) -> str:
        """Process a packet and return a formatted string.

        Args:
            packet: A Scapy packet object.

        Returns:
            A formatted string describing the packet.
        """
        raise NotImplementedError


class TCPProcessor(PacketProcessor):
    """Processor for TCP packets with port and flag details."""

    def process(self, packet) -> str:
        """Extract and format TCP packet details.

        Args:
            packet: A Scapy packet with IP and TCP layers.

        Returns:
            Formatted string with IPs, ports, and flags.
        """
        src = packet[IP].src
        dst = packet[IP].dst
        try:
            tcp_layer = packet[TCP]
            sport = tcp_layer.sport
            dport = tcp_layer.dport
            flags = tcp_layer.flags
            return (
                f"[TCP] {src}:{sport} -> "
                f"{dst}:{dport} | Flags: {flags}"
            )
        except (AttributeError, TypeError):
            return f"[TCP] {src} -> {dst}"


class UDPProcessor(PacketProcessor):
    """Processor for UDP packets."""

    def process(self, packet) -> str:
        """Extract and format UDP packet details.

        Args:
            packet: A Scapy packet with IP and UDP layers.

        Returns:
            Formatted string with source and destination.
        """
        src = packet[IP].src
        dst = packet[IP].dst
        try:
            udp_layer = packet[UDP]
            sport = udp_layer.sport
            dport = udp_layer.dport
            return (
                f"[UDP] {src}:{sport} -> {dst}:{dport}"
            )
        except (AttributeError, TypeError):
            return f"[UDP] {src} -> {dst}"


class ICMPProcessor(PacketProcessor):
    """Processor for ICMP packets."""

    def process(self, packet) -> str:
        """Extract and format ICMP packet details.

        Args:
            packet: A Scapy packet with IP and ICMP layers.

        Returns:
            Formatted string with source and destination IPs.
        """
        src = packet[IP].src
        dst = packet[IP].dst
        return f"[ICMP] {src} -> {dst}"


_tcp_processor = TCPProcessor()
_udp_processor = UDPProcessor()
_icmp_processor = ICMPProcessor()


def packet_handler(packet):
    """Process a single packet and print a formatted summary.

    Callback function for Scapy's sniff(). Identifies the
    protocol layer and prints source/destination details.

    Args:
        packet: A Scapy packet object.
    """
    if IP is not None and packet.haslayer(IP):
        if TCP is not None and packet.haslayer(TCP):
            print(_tcp_processor.process(packet))
        elif UDP is not None and packet.haslayer(UDP):
            print(_udp_processor.process(packet))
        elif ICMP is not None and packet.haslayer(ICMP):
            print(_icmp_processor.process(packet))
    else:
        print(packet.summary())


class Sniffer:
    """Network packet sniffer engine.

    Uses a Thread/Queue architecture to decouple packet capture
    from processing, preventing packet drops under high traffic.

    Attributes:
        interface: Network interface to sniff on.
        filter_str: BPF filter string.
        output_file: Path to output PCAP file.
        verbose: Enable hexdump output.
        search: String to search in packet payloads.
        stats: Protocol packet counters.
    """

    def __init__(self, interface: str = None,
                 filter_str: str = None,
                 output_file: str = None,
                 verbose: bool = False,
                 search: str = None):
        """Initialize the sniffer.

        Args:
            interface: Network interface to sniff on.
            filter_str: BPF filter string.
            output_file: Path to save packets as PCAP.
            verbose: If True, print hexdump per packet.
            search: String to search in payloads.
        """
        self.interface = interface
        self.filter_str = filter_str
        self.output_file = output_file
        self.verbose = verbose
        self.search = search
        self.stats = {
            "TCP": 0, "UDP": 0, "ICMP": 0, "Other": 0
        }
        self.packet_queue = Queue()
        self.running = False
        self.pcap_writer = None
        self.processors = {
            "TCP": TCPProcessor(),
            "UDP": UDPProcessor(),
            "ICMP": ICMPProcessor()
        }

        if self.output_file and PcapWriter is not None:
            try:
                self.pcap_writer = PcapWriter(
                    self.output_file, append=True
                )
            except IOError as err:
                print(f"[ERROR] Cannot open file: {err}")
                sys.exit(1)

    def start(self):
        """Start capturing and processing packets.

        Launches a processor thread and begins sniffing.
        Handles KeyboardInterrupt for clean shutdown.
        """
        self.running = True

        processor_thread = threading.Thread(
            target=self._process_queue, daemon=True
        )
        processor_thread.start()

        try:
            if sniff is not None:
                sniff(
                    iface=self.interface,
                    filter=self.filter_str,
                    prn=self._capture_packet,
                    store=0
                )
        except KeyboardInterrupt:
            pass
        except Exception as err:
            print(f"[ERROR] Sniffing failed: {err}")
        finally:
            self.running = False
            self.packet_queue.join()
            self._print_stats()
            if self.pcap_writer:
                self.pcap_writer.close()
            print("[INFO] Stopping capture...")

    def _capture_packet(self, packet):
        """Add captured packet to processing queue.

        Args:
            packet: A Scapy packet from the wire.
        """
        self.packet_queue.put(packet)

    def _process_queue(self):
        """Process packets from the queue (worker thread)."""
        while self.running or not self.packet_queue.empty():
            try:
                packet = self.packet_queue.get(timeout=1)
                self._process_packet(packet)
                self.packet_queue.task_done()
            except Empty:
                continue

    def _process_packet(self, packet):
        """Process a single packet.

        Writes to PCAP, dispatches to protocol processor,
        optionally prints hexdump and searches payload.

        Args:
            packet: A Scapy packet to process.
        """
        if self.pcap_writer:
            self.pcap_writer.write(packet)

        if IP is None or not packet.haslayer(IP):
            self.stats["Other"] += 1
            return

        if TCP is not None and packet.haslayer(TCP):
            protocol = "TCP"
        elif UDP is not None and packet.haslayer(UDP):
            protocol = "UDP"
        elif ICMP is not None and packet.haslayer(ICMP):
            protocol = "ICMP"
        else:
            protocol = "Other"

        self.stats[protocol] += 1

        if protocol in self.processors:
            try:
                output = self.processors[protocol].process(
                    packet
                )
                print(output)
            except Exception as err:
                print(f"[{protocol}] Error: {err}")

        if self.verbose and hexdump is not None:
            hexdump(packet)

        if (self.search
                and Raw is not None
                and packet.haslayer(Raw)):
            try:
                payload = packet[Raw].load.decode(
                    "utf-8", errors="ignore"
                )
                if self.search in payload:
                    print("[ALERT] Payload Match found!")
            except (UnicodeDecodeError, AttributeError):
                pass

    def _print_stats(self):
        """Print capture statistics summary."""
        print("\n--- Capture Statistics ---")
        total = sum(self.stats.values())
        for protocol, count in self.stats.items():
            if count > 0:
                print(f"  {protocol}: {count}")
        print(f"  Total: {total}")


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments.

    Returns:
        Parsed arguments namespace.
    """
    parser = argparse.ArgumentParser(
        description="PySniffer - Network Packet Sniffer"
    )
    parser.add_argument(
        "-i", "--interface",
        help="Network interface (e.g., eth0)"
    )
    parser.add_argument(
        "-f", "--filter",
        help="BPF filter string (e.g., 'tcp port 80')"
    )
    parser.add_argument(
        "--write",
        help="Save packets to PCAP file"
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Show hexdump for each packet"
    )
    parser.add_argument(
        "-s", "--search",
        help="Search string in packet payloads"
    )
    return parser.parse_args()


def main():
    """Entry point for PySniffer."""
    print("[INFO] PySniffer initialized.")

    try:
        if os.geteuid() != 0:
            print(
                "[ERROR] Root privileges required."
                " Run with sudo."
            )
            sys.exit(1)
    except AttributeError:
        pass

    args = parse_args()

    sniffer = Sniffer(
        interface=args.interface,
        filter_str=args.filter,
        output_file=args.write,
        verbose=args.verbose,
        search=args.search
    )

    sniffer.start()


if __name__ == "__main__":
    main()
