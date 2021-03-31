#define ACK_OFF 0
#define ACK_ON 1

esp_err_t i2c_detect_device(uint8_t client_address);
esp_err_t i2c_master_driver_initialize(uint8_t sda_pin, uint8_t scl_pin, uint32_t master_clock_frequency);
esp_err_t i2c_master_write_byte_to_client_ack(uint8_t client_address, uint8_t data, bool detect_only_mode, bool enable_ack);
esp_err_t i2c_reset();
esp_err_t do_i2cdetect();
