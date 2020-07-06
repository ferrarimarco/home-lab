#include "relay_board.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"

static const char *TAG = "relay_board";

void init_relay(struct Relay relay)
{
    gpio_num_t gpio_num = relay.gpio_num;
    ESP_LOGI(TAG, "Initializing relay connected to GPIO PIN no. %u", gpio_num);
    ESP_ERROR_CHECK(gpio_reset_pin(gpio_num));
    ESP_ERROR_CHECK(gpio_set_direction(gpio_num, relay.gpio_mode));
    ESP_ERROR_CHECK(gpio_set_pull_mode(gpio_num, relay.pull_mode));
    ESP_ERROR_CHECK(gpio_set_level(gpio_num, relay.initial_level));
}

void turn_relay_on(struct Relay relay)
{
    gpio_num_t gpio_num = relay.gpio_num;
    ESP_LOGI(TAG, "Turning the relay connected to GPIO PIN no. %u ON...", gpio_num);
    ESP_ERROR_CHECK(gpio_set_level(gpio_num, relay.active_level));
}

void turn_relay_off(struct Relay relay)
{
    gpio_num_t gpio_num = relay.gpio_num;
    ESP_LOGI(TAG, "Turning the relay connected to GPIO PIN no. %u OFF...", gpio_num);
    ESP_ERROR_CHECK(gpio_set_level(gpio_num, relay.inactive_level));
}

void relay_board_demo(struct Relay relay_1, struct Relay relay_2, struct Relay relay_3, struct Relay relay_4)
{
    turn_relay_on(relay_1);
    turn_relay_on(relay_2);
    turn_relay_on(relay_3);
    turn_relay_on(relay_4);

    vTaskDelay(5000 / portTICK_PERIOD_MS);

    turn_relay_off(relay_1);
    turn_relay_off(relay_2);
    turn_relay_off(relay_3);
    turn_relay_off(relay_4);
}
