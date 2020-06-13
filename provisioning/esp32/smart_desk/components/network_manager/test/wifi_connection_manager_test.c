#include "unity.h"
#include "sdkconfig.h"
#include "esp_system.h"
#include "nvs_manager.h"

#include "wifi_connection_manager.h"

TEST_CASE("Should connect to the specified wifi network as a client", "[wifi_connection_manager]")
{
    initialize_nvs_flash();
    esp_err_t expected = ESP_OK;
    esp_err_t actual = connect_to_wifi_network(CONFIG_ESP_WIFI_SSID, CONFIG_ESP_WIFI_PASSWORD, 10);

    TEST_ASSERT_EQUAL(expected, actual);
}
