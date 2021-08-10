#include "i2c_utils.h"

#include <stdbool.h>
#include <stdio.h>

#include "driver/i2c.h"
#include "driver/periph_ctrl.h"
#include "esp_log.h"

#include "print_utils.h"

static const char *TAG = "i2c_utils";

i2c_port_t i2c_port = I2C_NUM_0;

esp_err_t i2c_reset()
{
    esp_err_t ret;
    char err_msg[20];

    if ((ret = i2c_reset_tx_fifo(i2c_port)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while resetting the I2C TX buffers.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    if ((ret = i2c_reset_rx_fifo(i2c_port)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while resetting the I2C RX buffers.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    periph_module_disable(PERIPH_I2C0_MODULE);
    periph_module_enable(PERIPH_I2C0_MODULE);

    if ((ret = i2c_driver_delete(i2c_port)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while deleting the I2C driver.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }
    return ret;
}

esp_err_t i2c_master_driver_initialize(uint8_t sda_pin, uint8_t scl_pin, uint32_t master_clock_frequency)
{
    ESP_LOGI(TAG, "Installing the I2C driver with SDA pin: %u, SCL pin: %u, I2C master clock frequency: %u Hz...", sda_pin, scl_pin, master_clock_frequency);
    i2c_config_t conf = {
        .mode = I2C_MODE_MASTER,
        .sda_io_num = sda_pin,
        .sda_pullup_en = GPIO_PULLUP_ENABLE,
        .scl_io_num = scl_pin,
        .scl_pullup_en = GPIO_PULLUP_ENABLE,
        .master.clk_speed = master_clock_frequency};

    esp_err_t ret;
    char err_msg[20];

    if ((ret = i2c_param_config(i2c_port, &conf)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while initializing I2C parameters.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    if (ret == ESP_OK && (ret = i2c_driver_install(i2c_port, I2C_MODE_MASTER, 0, 0, 0)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while installing the I2C driver.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }
    return ret;
}

esp_err_t i2c_master_write_byte_to_client_ack(uint8_t client_address, uint8_t data, bool detect_only_mode, bool enable_ack)
{
    ESP_LOGD(TAG, "Writing to client 0x%02x. Sending byte: " BYTE_TO_BINARY_PATTERN, client_address, BYTE_TO_BINARY(data));

    i2c_cmd_handle_t cmd = i2c_cmd_link_create();

    esp_err_t ret;
    char err_msg[20];

    if ((ret = i2c_master_start(cmd)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while generating the command start for 0x%02x.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)), client_address);
    }

    if (ret == ESP_OK && (ret = i2c_master_write_byte(cmd, (client_address << 1) | I2C_MASTER_WRITE, enable_ack)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while writing the address to send data to 0x%02x.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)), client_address);
    }

    if (ret == ESP_OK && !detect_only_mode && (ret = i2c_master_write_byte(cmd, data, enable_ack)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while writing a byte of data to send to 0x%02x.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)), client_address);
    }

    if (ret == ESP_OK && (ret = i2c_master_stop(cmd)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while generating the command stop for 0x%02x.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)), client_address);
    }

    if (ret == ESP_OK)
    {
        do
        {
            // ticks_to_wait is a timeout value.
            // If the queue is full for that amount of ticks, the call aborts instead of waiting longer.
            ret = i2c_master_cmd_begin(i2c_port, cmd, 1000 / portTICK_PERIOD_MS);
            if (ret == ESP_OK)
                ESP_LOGD(TAG, "I2C command sent to 0x%02x.", client_address);
            else if (ret == ESP_ERR_TIMEOUT)
                ESP_LOGE(TAG, "%s while sending queued commands to 0x%02x. Retrying...", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)), client_address);
            else
                ESP_LOGE(TAG, "%s while sending queued commands to 0x%02x.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)), client_address);
        } while (ret == ESP_ERR_TIMEOUT);
    }

    i2c_cmd_link_delete(cmd);

    return ret;
}

esp_err_t i2c_detect_device(uint8_t client_address)
{
    ESP_LOGI(TAG, "Checking if there's an I2C client device at 0x%02x...", client_address);

    esp_err_t ret;
    char err_msg[20];

    if ((ret = i2c_master_write_byte_to_client_ack(client_address, 0, true, ACK_ON)) == ESP_OK)
    {
        ESP_LOGI(TAG, "The I2C device at 0x%02x replied with an ACK.", client_address);
    }
    else
    {
        ESP_LOGE(TAG, "%s while detecting I2C devices at 0x%02x.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)), client_address);
    }

    return ret;
}
