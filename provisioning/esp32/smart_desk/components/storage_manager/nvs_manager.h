#include "esp_system.h"

bool blob_exists(const char *namespace, const char *key);
esp_err_t get_blob_length(const char *namespace, const char *key, size_t *length);
esp_err_t initialize_nvs_flash();
esp_err_t load_blob(const char *namespace, const char *key, void *blob_output, size_t blob_length);
esp_err_t save_blob(const char *namespace, const char *key, const void *value, size_t value_size);
