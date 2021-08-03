#ifndef PROVISIONING_ESP32_SMART_DESK_COMPONENTS_I2C_MANAGER_I2C_UTILS_H_
#define PROVISIONING_ESP32_SMART_DESK_COMPONENTS_I2C_MANAGER_I2C_UTILS_H_

#include <stdbool.h>

#include "esp_err.h"

#define ACK_OFF 0
#define ACK_ON 1

esp_err_t i2c_detect_device(uint8_t client_address);
esp_err_t i2c_master_driver_initialize(uint8_t sda_pin, uint8_t scl_pin, uint32_t master_clock_frequency);
esp_err_t i2c_master_write_byte_to_client_ack(uint8_t client_address, uint8_t data, bool detect_only_mode, bool enable_ack);
esp_err_t i2c_reset();
esp_err_t do_i2cdetect();

#endif  // PROVISIONING_ESP32_SMART_DESK_COMPONENTS_I2C_MANAGER_I2C_UTILS_H_
