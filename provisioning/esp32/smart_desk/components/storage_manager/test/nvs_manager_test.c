#include "unity.h"
#include "esp_system.h"

#include "nvs_manager.h"

TEST_CASE("Should initialize the non-volatile storage flash", "[nvs_manager]")
{
    esp_err_t expected = ESP_OK;
    esp_err_t actual = initialize_nvs_flash();

    TEST_ASSERT_EQUAL(expected, actual);
}
