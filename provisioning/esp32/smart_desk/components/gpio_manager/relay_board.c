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

void extend_actuators(struct Relay relay_1, struct Relay relay_2, struct Relay relay_3, struct Relay relay_4)
{
    turn_relay_on(relay_1);
    turn_relay_on(relay_3);

    turn_relay_off(relay_2);
    turn_relay_off(relay_4);
}

void retract_actuators(struct Relay relay_1, struct Relay relay_2, struct Relay relay_3, struct Relay relay_4)
{
    turn_relay_on(relay_2);
    turn_relay_on(relay_4);

    turn_relay_off(relay_1);
    turn_relay_off(relay_3);
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

void shut_down_actuators(struct Relay relay_1, struct Relay relay_2, struct Relay relay_3, struct Relay relay_4)
{
    ESP_LOGI(TAG, "Shutting down the actuators...");
    turn_relay_off(relay_1);
    turn_relay_off(relay_2);
    turn_relay_off(relay_3);
    turn_relay_off(relay_4);
}

void actuators_demo(struct Relay relay_1, struct Relay relay_2, struct Relay relay_3, struct Relay relay_4)
{
    ESP_LOGI(TAG, "Initializing the actuators...");

    ESP_LOGI(TAG, "Shutting down the actuators to start from a known configuration...");
    shut_down_actuators(relay_1, relay_2, relay_3, relay_4);

    uint32_t actuators_demo_duration = 25000;

    ESP_LOGI(TAG, "Retracting actuators for %u ms to start from a known position...", actuators_demo_duration);
    retract_actuators(relay_1, relay_2, relay_3, relay_4);
    vTaskDelay(actuators_demo_duration / portTICK_PERIOD_MS);
    shut_down_actuators(relay_1, relay_2, relay_3, relay_4);

    ESP_LOGI(TAG, "Extending actuators for %u ms...", actuators_demo_duration);
    extend_actuators(relay_1, relay_2, relay_3, relay_4);
    vTaskDelay(actuators_demo_duration / portTICK_PERIOD_MS);

    ESP_LOGI(TAG, "Pausing for %u ms...", actuators_demo_duration);
    shut_down_actuators(relay_1, relay_2, relay_3, relay_4);
    vTaskDelay(actuators_demo_duration / portTICK_PERIOD_MS);

    ESP_LOGI(TAG, "Retracting actuators for %u ms...", actuators_demo_duration);
    retract_actuators(relay_1, relay_2, relay_3, relay_4);
    vTaskDelay(actuators_demo_duration / portTICK_PERIOD_MS);

    shut_down_actuators(relay_1, relay_2, relay_3, relay_4);
}
