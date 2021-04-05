#ifndef RELAY_BOARD_H_
#define RELAY_BOARD_H_

#include "driver/gpio.h"

struct Relay
{
    gpio_num_t gpio_num;
    gpio_mode_t gpio_mode;
    gpio_pull_mode_t pull_mode;
    uint32_t initial_level;
    uint32_t active_level;
    uint32_t inactive_level;
};

esp_err_t init_relays(uint8_t relay_pins[], size_t relay_num, struct Relay **relays_p);
esp_err_t turn_relay_on(struct Relay *relay);
esp_err_t turn_relay_off(struct Relay *relay);

#endif
