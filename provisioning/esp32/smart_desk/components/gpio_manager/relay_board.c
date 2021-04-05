#include <string.h>

#include "relay_board.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"

static const char *TAG = "relay_board";

esp_err_t init_relays(uint8_t relay_pins[], size_t relay_num, struct Relay **relays_p)
{
    ESP_LOGI(TAG, "Initializing %u relays...", relay_num);
    esp_err_t ret = ESP_OK;
    char err_msg[20];

    if ((*relays_p = (struct Relay *)calloc(relay_num, sizeof(struct Relay))) == NULL)
    {
        ret = ESP_ERR_NO_MEM;
        ESP_LOGE(TAG, "%s while allocating memory for the relays.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
        return ret;
    }
    gpio_num_t gpio_num = GPIO_NUM_NC;

    int i;
    for (i = 0; i < relay_num && ret == ESP_OK; i++)
    {
        size_t relay_size = sizeof(struct Relay);
        struct Relay *relay;
        if ((relay = (struct Relay *)calloc(1, relay_size)) == NULL)
            ret = ESP_ERR_NO_MEM;

        if (ret == ESP_OK)
        {
            struct Relay r = {relay_pins[i], GPIO_MODE_OUTPUT, GPIO_PULLUP_ONLY, 1, 0, 1};
            memcpy(relay, &r, relay_size);
            (*relays_p)[i] = *relay;
            gpio_num = relay->gpio_num;
            ESP_LOGI(TAG, "Initializing relay connected to GPIO PIN no. %u (pointer to relay: %p)", gpio_num, relay);
        }
        if (ret == ESP_OK && (ret = gpio_reset_pin(gpio_num)) != ESP_OK)
        {
            ESP_LOGE(TAG, "%s while resetting GPIO pin.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
        }
        if (ret == ESP_OK && (ret = gpio_set_direction(gpio_num, relay->gpio_mode)) != ESP_OK)
        {
            ESP_LOGE(TAG, "%s while setting GPIO direction.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
        }
        if (ret == ESP_OK && (ret = gpio_set_pull_mode(gpio_num, relay->pull_mode)) != ESP_OK)
        {
            ESP_LOGE(TAG, "%s while setting GPIO pull mode.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
        }
        if (ret == ESP_OK && (ret = gpio_set_level(gpio_num, relay->initial_level)) != ESP_OK)
        {
            ESP_LOGE(TAG, "%s while setting GPIO level.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
        }
    }

    ESP_LOGI(TAG, "Completed relays initialization (pointer to pointer to relays array: %p, pointer to relays array: %p)", relays_p, *relays_p);

    return ret;
}

esp_err_t turn_relay_on(struct Relay *relay)
{
    ESP_LOGI(TAG, "Turning relay ON (pointer: %p)", relay);
    gpio_num_t gpio_num = relay->gpio_num;
    ESP_LOGI(TAG, "Turning the relay connected to GPIO PIN no. %u ON...", gpio_num);
    esp_err_t ret = ESP_OK;
    char err_msg[20];

    if ((ret = gpio_set_level(gpio_num, relay->active_level)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while setting GPIO level.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    return ret;
}

esp_err_t turn_relay_off(struct Relay *relay)
{
    ESP_LOGI(TAG, "Turning relay OFF (pointer: %p)", relay);
    gpio_num_t gpio_num = relay->gpio_num;
    ESP_LOGI(TAG, "Turning the relay connected to GPIO PIN no. %u OFF...", gpio_num);
    esp_err_t ret = ESP_OK;
    char err_msg[20];

    if ((ret = gpio_set_level(gpio_num, relay->inactive_level)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while setting GPIO level.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    return ret;
}
