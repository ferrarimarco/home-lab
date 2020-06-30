#include <stdio.h>
#include "sdkconfig.h"
#include "freertos/FreeRTOS.h"
#include "esp_log.h"
#include "esp_event.h"
#include "esp_system.h"
#include "esp_spi_flash.h"

#include "app_info.h"
#include "board_info.h"
#include "i2c_utils.h"
#include "hd_44780.h"

#include "ip_address_manager.h"
#include "wifi_connection_manager.h"
#include "provisioning_manager.h"

#define SDA_PIN 23
#define SCL_PIN 22
#define I2C_FREQUENCY ((uint8_t)100000)

#define LCD_ADDR 0x27
#define LCD_COLS 20
#define LCD_ROWS 4

static const char *TAG = "smart_desk";

void app_main(void)
{
    i2c_master_driver_initialize(SDA_PIN, SCL_PIN, I2C_FREQUENCY);
    do_i2cdetect();

    LCD_init(LCD_ADDR, LCD_COLS, LCD_ROWS);

    ESP_LOGI(TAG, "Showing LCD demo...");
    LCD_Demo();

    esp_chip_info_t chip_info;
    esp_chip_info(&chip_info);
    const char *board_info = get_board_info(chip_info, spi_flash_get_chip_size(), esp_get_free_heap_size());
    printf(board_info);

    const char *app_info = get_app_info();
    printf(app_info);

    ESP_LOGI(TAG, "Creating the default loop...");
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    ESP_LOGI(TAG, "Registering event handlers...");
    register_wifi_manager_event_handlers();
    register_ip_address_manager_event_handlers();
    register_provisioning_manager_event_handlers();

    start_wifi_provisioning();
}
