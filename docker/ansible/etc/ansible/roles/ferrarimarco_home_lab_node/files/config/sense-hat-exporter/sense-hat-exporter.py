import argparse
import time

from prometheus_client import REGISTRY, Metric, Summary, write_to_textfile
from sense_hat import SenseHat

# Create a metric to track time spent and requests made.
REQUEST_TIME = Summary("request_processing_seconds", "Time spent processing request")


class SenseHatCollector:
    """This sets up a custom collector for the SenseHat"""

    def __init__(self, orientation=False):
        self.sense = SenseHat()
        self.orientation = orientation

    @REQUEST_TIME.time()
    def collect(self):
        # Get data from the Sense Hat
        temperature = self.sense.get_temperature()
        temperature_humidity = self.sense.get_temperature_from_humidity()
        temperature_pressure = self.sense.get_temperature_from_pressure()
        humidity = self.sense.get_humidity()
        pressure = self.sense.get_pressure()

        # Store the data from the Sense Hat in Prometheus metrics
        metric = Metric(
            "raspberry_pi_sensehat", "Raspberry Pi SenseHat metrics", "gauge"
        )
        metric.add_sample(
            "raspberry_pi_sensehat_temperature",
            value=temperature,
            labels={
                "name": "SenseHat temperature from the temperature sensor in Celsius degrees"
            },
        )
        metric.add_sample(
            "raspberry_pi_sensehat_temperature_humidity",
            value=temperature_humidity,
            labels={
                "name": "SenseHat temperature from the humidity sensor in Celsius degrees"
            },
        )
        metric.add_sample(
            "raspberry_pi_sensehat_temperature_pressure",
            value=temperature_pressure,
            labels={
                "name": "SenseHat temperature from the pressure sensor in Celsius degrees"
            },
        )
        metric.add_sample(
            "raspberry_pi_sensehat_humidity",
            value=humidity,
            labels={"name": "SenseHat relative humidity percentage"},
        )
        metric.add_sample(
            "raspberry_pi_sensehat_pressure",
            value=pressure,
            labels={"name": "SenseHat pressure in millibars"},
        )
        if self.orientation:
            roll = self.sense.orientation["roll"]
            yaw = self.sense.orientation["yaw"]
            pitch = self.sense.orientation["pitch"]
            metric.add_sample(
                "raspberry_pi_sensehat_roll",
                value=roll,
                labels={"name": "SenseHat Roll"},
            )
            metric.add_sample(
                "raspberry_pi_sensehat_yaw", value=yaw, labels={"name": "SenseHat Yaw"}
            )
            metric.add_sample(
                "raspberry_pi_sensehat_pitch",
                value=pitch,
                labels={"name": "SenseHat Pitch"},
            )

        yield metric


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        "--seconds_between_reads",
        help="Seconds to wait between reads",
        default=60,
        type=int,
    )
    parser.add_argument(
        "--metrics_textfile_path",
        help="The path of the text file to save the metrics to",
        default="/var/lib/node_exporter/textfile_collector/sense-hat.prom",
    )
    parser.add_argument(
        "--orientation", help="Output orientation data", action="store_true"
    )
    parser.set_defaults(orientation=False)
    args = parser.parse_args()

    REGISTRY.register(SenseHatCollector(orientation=args.orientation))
    while True:
        write_to_textfile(args.metrics_textfile_path, REGISTRY)
        time.sleep(args.seconds_between_reads)
