#include "esp_system.h"
#include "esp_log.h"

#include "nvs_flash.h"
#include "nvs_manager.h"

static const char *TAG = "nvs_manager";

esp_err_t initialize_nvs_flash()
{
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND)
    {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    return ret;
}
