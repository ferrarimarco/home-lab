# -*- coding: utf-8 -*-

import argparse
import logging
import re
import requests
import sys
import time

from html.parser import HTMLParser

from prometheus_client import CollectorRegistry, Gauge, Summary, write_to_textfile

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Create a metric to track time spent and requests made.
REQUEST_TIME = Summary("request_processing_seconds", "Time spent processing request")

registry = CollectorRegistry()
namespace = "ztef6005ont"


metrics = {
    "device_info": Gauge(
        name="device_info",
        documentation="ZTE F6005 ONT device info",
        labelnames=[
            "model",
            "hardware_version",
            "software_version",
            "bootloader_version",
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
    ),
    "gpon_status": Gauge(
        name="gpon_status",
        documentation="GPON status",
        labelnames=[
            "flag",
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
    ),
    "optical_tx_power": Gauge(
        name="optical_tx_power",
        documentation="Optical network interface transmit power",
        labelnames=[
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
        unit="dbm"
    ),
    "optical_rx_power": Gauge(
        name="optical_rx_power",
        documentation="Optical network interface receive power",
        labelnames=[
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
        unit="dbm"
    ),
    "optical_interface_voltage": Gauge(
        name="optical_interface_voltage",
        documentation="Optical network interface voltage",
        labelnames=[
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
        unit="volts"
    ),
    "optical_interface_current": Gauge(
        name="optical_interface_current",
        documentation="Optical network interface current",
        labelnames=[
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
        unit="amperes"
    ),
    "optical_interface_temperature": Gauge(
        name="optical_interface_temperature",
        documentation="Optical network interface temperature",
        labelnames=[
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
        unit="celsius"
    ),
    "ethernet_interface_link_status": Gauge(
        name="ethernet_interface_link_up",
        documentation="Ethernet network interface link status",
        labelnames=[
            "flag",
            "mac_address",
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
    ),
    "ethernet_interface_link_type": Gauge(
        name="ethernet_interface_link_type",
        documentation="Ethernet network interface link type",
        labelnames=[
            "flag",
            "mac_address",
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
    ),
    "ethernet_interface_mac_address": Gauge(
        name="ethernet_interface_mac_address",
        documentation="Ethernet network interface MAC address",
        labelnames=[
            "mac_address",
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
    ),
    "ethernet_interface_rx_bytes": Gauge(
        name="ethernet_interface_rx_bytes",
        documentation="Ethernet network interface received bytes",
        labelnames=[
            "mac_address",
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
        unit="bytes"
    ),
    "ethernet_interface_rx_packets": Gauge(
        name="ethernet_interface_rx_packets",
        documentation="Ethernet network interface received packets",
        labelnames=[
            "mac_address",
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
    ),
    "ethernet_interface_rx_unicast_packets": Gauge(
        name="ethernet_interface_rx_unicast_packets",
        documentation="Ethernet network interface received unicast packets",
        labelnames=[
            "mac_address",
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
    ),
    "ethernet_interface_rx_multicast_packets": Gauge(
        name="ethernet_interface_rx_multicast_packets",
        documentation="Ethernet network interface received multicast packets",
        labelnames=[
            "mac_address",
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
    ),
    "ethernet_interface_rx_errors": Gauge(
        name="ethernet_interface_rx_errors",
        documentation="Ethernet network interface received errors",
        labelnames=[
            "mac_address",
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
    ),
    "ethernet_interface_rx_drops": Gauge(
        name="ethernet_interface_rx_drops",
        documentation="Ethernet network interface received dropped packets",
        labelnames=[
            "mac_address",
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
    ),
    "ethernet_interface_tx_bytes": Gauge(
        name="ethernet_interface_tx_bytes",
        documentation="Ethernet network interface transmitted bytes",
        labelnames=[
            "mac_address",
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
        unit="bytes"
    ),
    "ethernet_interface_tx_packets": Gauge(
        name="ethernet_interface_tx_packets",
        documentation="Ethernet network interface transmitted packets",
        labelnames=[
            "mac_address",
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
    ),
    "ethernet_interface_tx_unicast_packets": Gauge(
        name="ethernet_interface_tx_unicast_packets",
        documentation="Ethernet network interface transmitted unicast packets",
        labelnames=[
            "mac_address",
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
    ),
    "ethernet_interface_tx_multicast_packets": Gauge(
        name="ethernet_interface_tx_multicast_packets",
        documentation="Ethernet network interface transmitted multicast packets",
        labelnames=[
            "mac_address",
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
    ),
    "ethernet_interface_tx_errors": Gauge(
        name="ethernet_interface_tx_errors",
        documentation="Ethernet network interface transmitted errors",
        labelnames=[
            "mac_address",
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
    ),
    "ethernet_interface_tx_drops": Gauge(
        name="ethernet_interface_tx_drops",
        documentation="Ethernet network interface transmitted dropped packets",
        labelnames=[
            "mac_address",
            "pon_serial_number",
        ],
        namespace=namespace,
        registry=registry,
    ),
}


gpon_states = [
    "Initial state(O1)",
    "Standby state(O2)",
    "Serial_Number state(O3)",
    "Ranging state(O4)",
    "Operation state(O5)",
    "POPUP state(O6)",
    "Emergency Stop state(O7)",
]


ethernet_interface_link_states = [
    "Down",
    "Up",
]


ethernet_interface_link_types = {
    0: "Down",
    1: "UP/10Mbps/Full Duplex",
    2: "UP/100Mbps/Full Duplex",
    3: "UP/1000Mbps/Full Duplex",
    6: "UP/2500Mps/Full Duplex",
    17: "UP/10Mbps/Half Duplex",
    18: "UP/100Mbps/Half Duplex",
    19: "UP/1000Mbps/Half Duplex",
    21: "UP/2500Mbps/Half Duplex",
}


device_info_field_names = {
    "model": "Model",
    "hardware_version": "HardwareVer",
    "software_version": "SoftwareVer",
    "bootloader_version": "BootLoaderVer",
    "pon_serial_number": "PonSerialNum",
}


optical_interface_field_names = {
    "gpon_status_index": "ponStaIndex",
    "tx_power": "txpower",
    "rx_power": "rxpower",
    "voltage": "voltage",
    "current": "current",
    "temperature": "temperature",
}


ethernet_network_interface_field_names = {
    "link_up": "linkUp",
    "link_mode": "mode",
    "ethernet_interface_mac_address": "Mac",
    "ethernet_interface_rx_bytes": "rxBytes",
    "ethernet_interface_rx_packets": "rxPkts",
    "ethernet_interface_rx_unicast_packets": "rxUnicast",
    "ethernet_interface_rx_multicast_packets": "rxMulticast",
    "ethernet_interface_rx_errors": "rxErrs",
    "ethernet_interface_rx_drops": "rxDrop",
    "ethernet_interface_tx_bytes": "txBytes",
    "ethernet_interface_tx_packets": "txPkts",
    "ethernet_interface_tx_unicast_packets": "txUnicast",
    "ethernet_interface_tx_multicast_packets": "txMulticast",
    "ethernet_interface_tx_errors": "txErrs",
    "ethernet_interface_tx_drops": "txDrop",
}


class AdminInterfaceHTMLParser(HTMLParser):

    def __init__(self, page_name, convert_charrefs: bool = True) -> None:
        self.page_name = page_name
        super().__init__(convert_charrefs=convert_charrefs)

    def handle_data(self, data):
        page_name_instruction = "var pagename=\"{page_name}\"".format(page_name=self.page_name)
        logger.debug("Check if {page_name} is in data: {page_name_instruction}".format(page_name=self.page_name, page_name_instruction=page_name_instruction))
        if page_name_instruction in data:
            logger.debug("Found script data for {page_name}".format(page_name=self.page_name))
            self.script_tag_content = data


def _get_script_tag_content(response, page_name, field_names):
    page_content = response.content.decode("utf-8")

    parser = AdminInterfaceHTMLParser(page_name)
    parser.feed(page_content)

    script_tag_content = parser.script_tag_content

    matched_data = {}

    for (field_name,field_name_js) in field_names.items():
        javascript_data_re = re.compile(r"^{field_name}=\"(?P<data>\S*)\";$".format(field_name=field_name_js))
        logger.debug("Matching content to regex: {regex}. Content:\n{content}".format(regex=javascript_data_re, content=script_tag_content))
        for line in script_tag_content.splitlines():
            logger.debug("Check if {line} matches {regex}".format(line=line, regex=javascript_data_re))
            matches = javascript_data_re.match(line)
            if matches != None:
                matches_groups = matches.groupdict()
                match = matches_groups["data"]
                logger.debug("Found match ({field_name},{field_name_js}): {match}".format(field_name=field_name, field_name_js=field_name_js,match=match))
                if match.isnumeric():
                    match = int(match)
                matched_data[field_name] = match

    logger.info("Matched data for {page_name}: {matched_data}".format(page_name=page_name,matched_data=matched_data))

    return matched_data


def login(session, username, password, ip_address):
    login_url = "https://{ip_address}/goform/LoginForm".format(ip_address=ip_address)

    logger.info("Logging in: {ip_address}".format(ip_address=ip_address))

    # TODO: sha256_digest(admin + "97s" + password)
    cmt = "5f326e96ccb8a54b15e74c366d3eba3be7d38ed3ae32bdbb46005daa88503b78"

    # TODO: random alphanumerig string (len: 32)
    nonce = "bDrQDehYkrGECD2dhyPRKt25T2s7esni"

    login_headers = {
        "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
        "Referer": "https://{ip_address}/login.html".format(ip_address=ip_address)
    }

    login_payload = {
        "cmt": cmt,
        "nonce": nonce,
    }

    # Disable SSL verification because the ONT uses a self-signed certificate
    login_response = session.post(
        login_url,
        headers=login_headers,
        data=login_payload,
        verify=False,
    )

    logger.info(login_response.text)


def collect_device_info(session, ip_address):
    device_info_url = "https://{ip_address}/devinfo.html".format(ip_address=ip_address)

    logger.info("Collecting device info from {url}".format(url=device_info_url))

    device_info_response = session.get(
        device_info_url,
        verify=False,
    )

    script_tag_content = _get_script_tag_content(device_info_response, "devinfo", device_info_field_names)

    pon_serial_number = script_tag_content["pon_serial_number"]

    metrics["device_info"].labels(
        script_tag_content["model"],
        script_tag_content["hardware_version"],
        script_tag_content["software_version"],
        script_tag_content["bootloader_version"],
        pon_serial_number,
    ).set(1)

    return pon_serial_number


def collect_network_interface_metrics(session, pon_serial_number, ip_address):
    gpon_info_url = "https://{ip_address}/gponinfo.html".format(ip_address=ip_address)
    gpon_info_response = session.get(
        gpon_info_url,
        verify=False,
    )

    script_tag_content = _get_script_tag_content(gpon_info_response, "gponinfo", optical_interface_field_names)

    gpon_status_index = script_tag_content["gpon_status_index"]

    for i in range(len(gpon_states)):
        gpon_state_value = 0

        if gpon_status_index - 1 == i:
            gpon_state_value = 1

        metrics["gpon_status"].labels(
            gpon_states[i],
            pon_serial_number,
        ).set(gpon_state_value)

    tx_power = script_tag_content["tx_power"]
    if tx_power != -1:
        tx_power = (tx_power / 500) - 30

    metrics["optical_tx_power"].labels(
        pon_serial_number,
    ).set(tx_power)

    rx_power = script_tag_content["rx_power"] / 500 - 40
    metrics["optical_rx_power"].labels(
        pon_serial_number,
    ).set(rx_power)

    voltage = script_tag_content["voltage"] / 50
    metrics["optical_interface_voltage"].labels(
        pon_serial_number,
    ).set(voltage)

    current = script_tag_content["current"]
    metrics["optical_interface_current"].labels(
        pon_serial_number,
    ).set(current)

    temperature = script_tag_content["temperature"] / 256
    metrics["optical_interface_temperature"].labels(
        pon_serial_number,
    ).set(temperature)


def collect_user_network_interface_metrics(session, pon_serial_number, ip_address):
    user_info_url = "https://{ip_address}/userinfo.html".format(ip_address=ip_address)
    user_info_response = session.get(
        user_info_url,
        verify=False,
    )

    script_tag_content = _get_script_tag_content(user_info_response, "userinfo", ethernet_network_interface_field_names)

    link_up = script_tag_content["link_up"]
    link_mode = script_tag_content["link_mode"]

    ethernet_interface_mac_address = script_tag_content["ethernet_interface_mac_address"]
    metrics["ethernet_interface_mac_address"].labels(
        ethernet_interface_mac_address,
        pon_serial_number,
    ).set(1)

    for i in range(len(ethernet_interface_link_states)):
        ethernet_interface_link_status_value = 0
        if i == link_up:
            ethernet_interface_link_status_value = 1
        metrics["ethernet_interface_link_status"].labels(
            ethernet_interface_link_states[i],
            ethernet_interface_mac_address,
            pon_serial_number,
        ).set(ethernet_interface_link_status_value)

    for key, value in ethernet_interface_link_types.items():
        ethernet_interface_link_mode_value = 0

        if (key == link_mode and link_up != 0) or (key == 0 and link_up == 0):
            ethernet_interface_link_mode_value = 1

        metrics["ethernet_interface_link_type"].labels(
            value,
            ethernet_interface_mac_address,
            pon_serial_number,
        ).set(ethernet_interface_link_mode_value)

    ethernet_interface_rx_bytes = script_tag_content["ethernet_interface_rx_bytes"]
    metrics["ethernet_interface_rx_bytes"].labels(
        ethernet_interface_mac_address,
        pon_serial_number,
    ).set(ethernet_interface_rx_bytes)

    ethernet_interface_rx_packets = script_tag_content["ethernet_interface_rx_packets"]
    metrics["ethernet_interface_rx_packets"].labels(
        ethernet_interface_mac_address,
        pon_serial_number,
    ).set(ethernet_interface_rx_packets)

    ethernet_interface_rx_unicast_packets = script_tag_content["ethernet_interface_rx_unicast_packets"]
    metrics["ethernet_interface_rx_unicast_packets"].labels(
        ethernet_interface_mac_address,
        pon_serial_number,
    ).set(ethernet_interface_rx_unicast_packets)

    ethernet_interface_rx_multicast_packets = script_tag_content["ethernet_interface_rx_multicast_packets"]
    metrics["ethernet_interface_rx_multicast_packets"].labels(
        ethernet_interface_mac_address,
        pon_serial_number,
    ).set(ethernet_interface_rx_multicast_packets)

    ethernet_interface_rx_errors = script_tag_content["ethernet_interface_rx_errors"]
    metrics["ethernet_interface_rx_errors"].labels(
        ethernet_interface_mac_address,
        pon_serial_number,
    ).set(ethernet_interface_rx_errors)

    ethernet_interface_rx_drops = script_tag_content["ethernet_interface_rx_drops"]
    metrics["ethernet_interface_rx_drops"].labels(
        ethernet_interface_mac_address,
        pon_serial_number,
    ).set(ethernet_interface_rx_drops)

    ethernet_interface_tx_bytes = script_tag_content["ethernet_interface_tx_bytes"]
    metrics["ethernet_interface_tx_bytes"].labels(
        ethernet_interface_mac_address,
        pon_serial_number,
    ).set(ethernet_interface_tx_bytes)

    ethernet_interface_tx_packets = script_tag_content["ethernet_interface_tx_packets"]
    metrics["ethernet_interface_tx_packets"].labels(
        ethernet_interface_mac_address,
        pon_serial_number,
    ).set(ethernet_interface_tx_packets)

    ethernet_interface_tx_unicast_packets = script_tag_content["ethernet_interface_tx_unicast_packets"]
    metrics["ethernet_interface_tx_unicast_packets"].labels(
        ethernet_interface_mac_address,
        pon_serial_number,
    ).set(ethernet_interface_tx_unicast_packets)

    ethernet_interface_tx_multicast_packets = script_tag_content["ethernet_interface_tx_multicast_packets"]
    metrics["ethernet_interface_tx_multicast_packets"].labels(
        ethernet_interface_mac_address,
        pon_serial_number,
    ).set(ethernet_interface_tx_multicast_packets)

    ethernet_interface_tx_errors = script_tag_content["ethernet_interface_tx_errors"]
    metrics["ethernet_interface_tx_errors"].labels(
        ethernet_interface_mac_address,
        pon_serial_number,
    ).set(ethernet_interface_tx_errors)

    ethernet_interface_tx_drops = script_tag_content["ethernet_interface_tx_drops"]
    metrics["ethernet_interface_tx_drops"].labels(
        ethernet_interface_mac_address,
        pon_serial_number,
    ).set(ethernet_interface_tx_drops)


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )

    parser.add_argument(
        "--ont-ip-address",
        help="ONT IP address",
        default="192.168.1.1",
        type=str,
    )
    parser.add_argument(
        "--ont-username",
        help="ONT username",
        default="admin",
    )
    parser.add_argument(
        "--ont-password",
        help="ONT username",
        default="admin",
    )
    parser.add_argument(
        "--router-eth-interface",
        help="Ethernet interface of the router to which the ONT is connected",
    )
    parser.add_argument(
        "--seconds-between-reads",
        help="Seconds to wait between reads",
        default=30,
        type=int,
    )
    parser.add_argument(
        "--metrics_textfile_path",
        help="The path of the text file to save the metrics to",
        default="/var/lib/node_exporter/textfile_collector/zte-f6005-ont.prom",
    )

    args = parser.parse_args(sys.argv[1:])

    while True:
        session = requests.Session()
        ont_ip_address = args.ont_ip_address
        login(
            session,
            args.ont_username,
            args.ont_password,
            ont_ip_address,
        )
        pon_serial_number = collect_device_info(session, ont_ip_address)
        collect_network_interface_metrics(session, pon_serial_number, ont_ip_address)
        collect_user_network_interface_metrics(session, pon_serial_number, ont_ip_address)
        write_to_textfile(args.metrics_textfile_path, registry)
        time.sleep(args.seconds_between_reads)


if __name__ == '__main__':
    main()
