#ifndef __ACTUATORS_CONTROLLER_H__
#define __ACTUATORS_CONTROLLER_H__

#include "esp_event.h"

#include "relay_board.h"

struct Actuator
{
    struct Relay *relay_1;
    struct Relay *relay_2;
    size_t relays_num;
};

struct ActuatorsEventMessage
{
    size_t actuators_num;
    struct Actuator **actuators;
};

esp_err_t init_actuators(struct Relay *relays, size_t relays_num, struct Actuator ***actuators_p, size_t actuators_num);

esp_err_t register_actuators_events(struct Actuator **actuators, size_t actuators_num);

esp_err_t start_actuators_extension(uint8_t target_height);
esp_err_t start_actuators_retraction(uint8_t target_height);

ESP_EVENT_DECLARE_BASE(ACTUATOR_EVENT);

enum
{                            // declaration of the specific events under the actuator events family
    EXTEND_ACTUATORS_EVENT,  // raised when there's a request to extend the actuators
    RETRACT_ACTUATORS_EVENT, // raised when there's a request to retract the actuators
    SHUTDOWN_ACTUATORS_EVENT // raised when there's a request to stop the actuators
};

#endif /* __ACTUATORS_CONTROLLER_H__ */
