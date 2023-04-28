#define DHT22_PIN 20

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
  pinMode(DHT22_PIN, INPUT);
}

void loop() {
  digitalWrite(LED_BUILTIN, HIGH);
  delay(1000);
  digitalWrite(LED_BUILTIN, LOW);
  delay(1000);
}
