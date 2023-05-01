#include <Arduino_HTS221.h>
#include <DHT.h>

#define DHT22_DATA_PIN 2
#define DHT_TYPE DHT22

DHT dht = DHT(DHT22_DATA_PIN, DHT_TYPE);

void setup() {
  Serial.print("Initializing the LED pin:");
  Serial.println(LED_BUILTIN);
  pinMode(LED_BUILTIN, OUTPUT);

  Serial.println("Initializing the serial port");
  Serial.begin(9600);
  // Wait for the serial port to be available
  while(!Serial);

  Serial.print("Initializing the DHT sensor. Data pin: ");
  Serial.print(DHT22_DATA_PIN);
  Serial.print(", DHT sensor type: ");
  Serial.println(DHT_TYPE);
  dht.begin();

  // HTS sensor seems to need some time for setup
  delay(10);
  if (!HTS.begin()) {
    Serial.println("Failed to initialize HTS22 sensor!");
    while (1);
  }
}

void loop() {
  digitalWrite(LED_BUILTIN, LOW);
  delay(2000);
  digitalWrite(LED_BUILTIN, HIGH);

  float dht22_humidity = dht.readHumidity();
  if (isnan(dht22_humidity)) {
    Serial.println("Failed to read humidity from the DHT sensor.");
    return;
  }

  float dht22_temperature = dht.readTemperature();
  if (isnan(dht22_temperature)) {
    Serial.println("Failed to read temperature from the DHT sensor.");
    return;
  }

  Serial.print("(DHT22) Humidity: ");
  Serial.print(dht22_humidity);
  Serial.print("% || Temperature: ");
  Serial.print(dht22_temperature);
  Serial.print("°C");

  Serial.println();

  float hts22_humidity = HTS.readHumidity();
  if (isnan(hts22_humidity)) {
    Serial.println("Failed to read humidity from the HTS221 sensor.");
    return;
  }

  float hts22_temperature = HTS.readTemperature();
  if (isnan(hts22_temperature)) {
    Serial.println("Failed to read temperature from the HTS221 sensor.");
    return;
  }

  Serial.print("(HTS221) Humidity: ");
  Serial.print(hts22_humidity);
  Serial.print("% || Temperature: ");
  Serial.print(hts22_temperature);
  Serial.print("°C");
  Serial.println();
}
