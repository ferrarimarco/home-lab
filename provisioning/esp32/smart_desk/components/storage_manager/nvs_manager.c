#include "esp_system.h"
#include "esp_log.h"

#include "nvs_flash.h"
#include "nvs_manager.h"

static const char *TAG = "smart_desk";

static esp_err_t open_nvs_handle(const char *namespace, nvs_handle_t *nvs_handle)
{
    esp_err_t err;
    ESP_LOGI(TAG, "Opening %s NVS namespace...", namespace);
    err = nvs_open(namespace, NVS_READWRITE, nvs_handle);
    return err;
}

bool blob_exists(const char *namespace, const char *key)
{
    ESP_LOGI(TAG, "Checking if a blob with %s key exists in %s namespace...", key, namespace);

    nvs_handle_t nvs_handle;
    esp_err_t err;
    bool result = false;

    ESP_ERROR_CHECK(open_nvs_handle(namespace, &nvs_handle));

    ESP_LOGI(TAG, "Checking if the %s namespace contains %s key...", namespace, key);
    size_t required_size = 0;
    err = nvs_get_blob(nvs_handle, key, NULL, &required_size);
    if (err == ESP_ERR_NVS_NOT_FOUND)
    {
        result = false;
        ESP_LOGI(TAG, "%s key not found in %s namespace.", key, namespace);
    }
    else if (err == ESP_OK)
    {
        result = true;
        ESP_LOGI(TAG, "Found %s key in %s namespace. Value size: %u.", key, namespace, required_size);
    }
    else
        ESP_ERROR_CHECK(err);

    ESP_LOGI(TAG, "Closing the NVS storage handle...");
    nvs_close(nvs_handle);

    return result;
}

esp_err_t initialize_nvs_flash()
{
    ESP_LOGI(TAG, "Initializing the NVS flash...");
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND)
    {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    return ret;
}

esp_err_t get_blob_length(const char *namespace, const char *key, size_t *length)
{
    ESP_LOGI(TAG, "Loading blob size from namespace: %s, key: %s...", namespace, key);

    nvs_handle_t nvs_handle;
    esp_err_t err;

    ESP_ERROR_CHECK(open_nvs_handle(namespace, &nvs_handle));

    err = nvs_get_blob(nvs_handle, key, NULL, length);
    if (err != ESP_OK && err != ESP_ERR_NVS_NOT_FOUND)
        return err;

    nvs_close(nvs_handle);
    return ESP_OK;
}

esp_err_t load_blob(const char *namespace, const char *key, void *blob_output, size_t blob_length)
{
    ESP_LOGI(TAG, "Loading blob from namespace: %s, key: %s...", namespace, key);

    nvs_handle_t nvs_handle;
    esp_err_t err;

    ESP_ERROR_CHECK(open_nvs_handle(namespace, &nvs_handle));

    err = nvs_get_blob(nvs_handle, key, blob_output, &blob_length);
    if (err != ESP_OK)
    {
        free(blob_output);
        return err;
    }

    nvs_close(nvs_handle);
    return ESP_OK;
}

esp_err_t save_blob(const char *namespace, const char *key, const void *value, size_t value_size)
{
    ESP_LOGI(TAG, "Writing blob in namespace: %s, key: %s...", namespace, key);

    nvs_handle_t nvs_handle;
    esp_err_t err;

    ESP_ERROR_CHECK(open_nvs_handle(namespace, &nvs_handle));

    ESP_LOGI(TAG, "Writing %s key in %s namespace...", key, namespace);
    err = nvs_set_blob(nvs_handle, key, value, value_size);
    if (err != ESP_OK)
        return err;

    ESP_LOGI(TAG, "Committing NVS changes...");
    err = nvs_commit(nvs_handle);
    if (err != ESP_OK)
        return err;

    ESP_LOGI(TAG, "Closing the NVS storage handle...");
    nvs_close(nvs_handle);

    return ESP_OK;
}
