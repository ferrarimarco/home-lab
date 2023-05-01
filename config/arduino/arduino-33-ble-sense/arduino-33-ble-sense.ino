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

  Serial.print("Initializing the DHT sensor. Data pin: ");
  Serial.print(DHT22_DATA_PIN);
  Serial.print(", DHT sensor type: ");
  Serial.println(DHT_TYPE);
  dht.begin();
}

void loop() {
  digitalWrite(LED_BUILTIN, LOW);
  delay(2000);
  digitalWrite(LED_BUILTIN, HIGH);

  Serial.println("Reading humidity from the DHT sensor");
  float dht22_humidity = dht.readHumidity();

  if (isnan(dht22_humidity)) {
    Serial.println("Failed to read humidity from the DHT sensor.");
    return;
  }

  Serial.println("Reading temperature from the DHT sensor");
  float dht22_temperature = dht.readTemperature();

  if (isnan(dht22_temperature)) {
    Serial.println("Failed to read temperature from the DHT sensor.");
    return;
  }

  Serial.print("Humidity: ");
  Serial.print(dht22_humidity);
  Serial.print("% || Temperature: ");
  Serial.print(dht22_temperature);
  Serial.print("°C ");

  Serial.println();
}
