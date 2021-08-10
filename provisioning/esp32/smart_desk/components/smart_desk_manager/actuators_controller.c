#include <string.h>

#include "esp_log.h"
#include "esp_timer.h"

#include "actuators_controller.h"
#include "ultrasonic.h"

// First attempt: 1 minute (to tune)
#define ACTUATORS_SAFETY_TIMEOUT_US 60000000

ESP_EVENT_DEFINE_BASE(ACTUATOR_EVENT);

static const char *TAG = "smart_desk_manager";

esp_timer_handle_t safety_timer;

static esp_err_t register_distance_sensor_events(uint8_t target_height);
static esp_err_t unregister_distance_sensor_events();

static esp_err_t actuators_event_post(int32_t event_id, void *event_data, size_t event_data_size)
{
    ESP_LOGD(TAG, "Posting the %u actuator event...", event_id);
    esp_err_t ret = ESP_OK;
    char err_msg[20];

    if ((ret = esp_event_post(ACTUATOR_EVENT, event_id, event_data, event_data_size, portMAX_DELAY)) != ESP_OK)
        ESP_LOGE(TAG, "%s while sending the EXTEND_ACTUATORS_EVENT event.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));

    return ret;
}

esp_err_t start_actuators_extension(uint8_t target_height)
{
    ESP_LOGI(TAG, "Extending the actuators to %u cm...", target_height);

    esp_err_t ret = register_distance_sensor_events(target_height);
    if (ret == ESP_OK)
        ret = actuators_event_post(EXTEND_ACTUATORS_EVENT, &target_height, sizeof(target_height));
    return ret;
}

esp_err_t start_actuators_retraction(uint8_t target_height)
{
    ESP_LOGI(TAG, "Retracting the actuators to %u cm...", target_height);
    register_distance_sensor_events(target_height);
    return actuators_event_post(RETRACT_ACTUATORS_EVENT, &target_height, sizeof(target_height));
}

static esp_err_t start_actuators_shutdown()
{
    ESP_LOGI(TAG, "Shutting down the actuators...");
    unregister_distance_sensor_events();
    return actuators_event_post(SHUTDOWN_ACTUATORS_EVENT, NULL, 0);
}

static void operate_actuators(void *event_handler_arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGD(TAG, "Operating the actuators...");

    esp_err_t ret = ESP_OK;
    char err_msg[20];

    // Init the timer if needed

    if (event_id == SHUTDOWN_ACTUATORS_EVENT)
    {
        // Stop the safety timer because the actuators stopped moving
        ret = esp_timer_stop(safety_timer);
        if (ret != ESP_OK)
        {
            ESP_LOGE(TAG, "%s while stopping the safety timer.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
            if (ret == ESP_ERR_INVALID_STATE)
            {
                ESP_LOGE(TAG, "The safety timer wasn't running, so cannot be stopped.");
            }
        }
    }
    else if (event_id == EXTEND_ACTUATORS_EVENT || event_id == RETRACT_ACTUATORS_EVENT)
    {
        if ((ret = esp_timer_start_once(safety_timer, ACTUATORS_SAFETY_TIMEOUT_US)) != ESP_OK)
            ESP_LOGE(TAG, "%s while starting the safety timer event.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));

        if (ret == ESP_ERR_INVALID_STATE)
        {
            ESP_LOGE(TAG, "The safety timer is already running. This is likely due to the fact that the actuators may be in movement.");
        }
    }

    // When requesting a shutdown, do that regardless of the error code because it might be
    // an emergency shutdown
    if (ret == ESP_OK || event_id == SHUTDOWN_ACTUATORS_EVENT)
    {
        struct ActuatorsEventMessage *actuators_event_message = (struct ActuatorsEventMessage *)event_handler_arg;
        ESP_LOGD(TAG, "event_handler_arg pointer: %p, actuators_event_message pointer: %p...", event_handler_arg, actuators_event_message);

        struct Actuator **actuators = actuators_event_message->actuators;
        size_t actuators_size = actuators_event_message->actuators_num;

        int i;
        for (i = 0; i < actuators_size; i++)
        {
            struct Actuator *actuator = actuators[i];
            ESP_LOGI(TAG, "Operating actuator %u (pointer: %p)...", i, actuator);
            struct Relay *relay_1 = actuator->relay_1;
            struct Relay *relay_2 = actuator->relay_2;
            ESP_LOGI(TAG, "Operating actuator %u (pointer: %p) via relays (pointers: %p, %p)...", i, actuator, relay_1, relay_2);
            if (event_id == EXTEND_ACTUATORS_EVENT)
            {
                ESP_LOGI(TAG, "Extending actuator %u (pointer: %p) via relays (pointers: %p, %p)...", i, actuator, relay_1, relay_2);
                turn_relay_on(relay_1);
                turn_relay_off(relay_2);
            }
            else if (event_id == RETRACT_ACTUATORS_EVENT)
            {
                ESP_LOGI(TAG, "Retracting actuator %u (pointer: %p) via relays (pointers: %p, %p)...", i, actuator, relay_1, relay_2);
                turn_relay_off(relay_1);
                turn_relay_on(relay_2);
            }
            else if (event_id == SHUTDOWN_ACTUATORS_EVENT)
            {
                ESP_LOGI(TAG, "Shutting down actuator %u (pointer: %p) via relays (pointers: %p, %p)...", i, actuator, relay_1, relay_2);
                turn_relay_off(relay_1);
                turn_relay_off(relay_2);
            }
            else
            {
                ret = ESP_ERR_INVALID_ARG;
                // Safety measure
                ESP_LOGE(TAG, "%d event type is not supported. Shutting the actuators down...", event_id);
                start_actuators_shutdown();
            }
        }
    }
}

// Callback that will be executed when the timer period lapses.
static void actuators_safety_timer_callback(void *arg)
{
    ESP_LOGI(TAG, "Safety timer triggered. Stopping the actuators to prevent damage...");
    start_actuators_shutdown();
}

static void ultrasonic_sensor_measure_available_handler(void *event_handler_arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGD(TAG, "%s: %u ultrasonic_sensor_measure_available_handler", event_base, event_id);

    struct DistanceMeasure distance_measure = *((struct DistanceMeasure *)event_data);
    uint32_t measured_distance = distance_measure.distance;

    uint8_t target_distance = *((uint8_t *)event_handler_arg);

    if (distance_measure.return_code == ESP_OK && (measured_distance == target_distance))
    {
        ESP_LOGI(TAG, "Reached target distance: %u cm. Measured distance: %u cm. Stopping actuators...", target_distance, measured_distance);
        start_actuators_shutdown();
    }
}

static esp_err_t register_distance_sensor_events(uint8_t target_height)
{
    esp_err_t ret = ESP_OK;
    char err_msg[20];

    uint8_t *target_distance_p = &target_height;
    size_t target_distance_size = sizeof(uint8_t);
    if ((target_distance_p = calloc(1, target_distance_size)) == NULL)
    {
        ret = ESP_ERR_NO_MEM;
        ESP_LOGE(TAG, "%s while allocating memory for the target distance.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
        return ret;
    }
    memcpy(target_distance_p, &target_height, target_distance_size);

    ESP_LOGD(TAG, "Registering the handler for ULTRASONIC_EVENT_MEASURE_AVAILABLE event...");
    if ((ret = esp_event_handler_instance_register(ULTRASONIC_EVENTS, ULTRASONIC_EVENT_MEASURE_AVAILABLE, ultrasonic_sensor_measure_available_handler, target_distance_p, NULL)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while registering the handler for the ULTRASONIC_EVENT_MEASURE_AVAILABLE event.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    return ret;
}

static esp_err_t unregister_distance_sensor_events()
{
    esp_err_t ret = ESP_OK;
    char err_msg[20];

    ESP_LOGD(TAG, "Unregistering the handler for ULTRASONIC_EVENT_MEASURE_AVAILABLE event...");
    if ((ret = esp_event_handler_unregister(ULTRASONIC_EVENTS, ULTRASONIC_EVENT_MEASURE_AVAILABLE, ultrasonic_sensor_measure_available_handler)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while unregistering the handler for the ULTRASONIC_EVENT_MEASURE_AVAILABLE event.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    return ret;
}

esp_err_t init_actuators(struct Relay *relays, size_t relays_num, struct Actuator ***actuators_p, size_t actuators_num)
{
    esp_err_t ret = ESP_OK;
    char err_msg[20];

    ESP_LOGI(TAG, "Initializing %u actuators (%u relays, relays pointer: %p)...", actuators_num, relays_num, relays);
    if ((*actuators_p = (struct Actuator **)calloc(actuators_num, sizeof(struct Actuator *))) == NULL)
    {
        ret = ESP_ERR_NO_MEM;
        ESP_LOGE(TAG, "%s while allocating memory for the actuators.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
        return ret;
    }

    ESP_LOGI(TAG, "Actuator pointers array initialized at %p...", *actuators_p);

    if (ret == ESP_OK)
    {
        int i;
        for (i = 0; i < actuators_num; i++)
        {
            size_t actuator_size = sizeof(struct Actuator);
            struct Actuator *actuator;
            if ((actuator = (struct Actuator *)calloc(1, actuator_size)) == NULL)
            {
                ret = ESP_ERR_NO_MEM;
                ESP_LOGE(TAG, "%s while allocating memory for the actuator.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
                return ret;
            }
            // Here we want:
            // i = 0: r1 = 0, r2 = 1
            // i = 1: r1 = 2, r2 = 3
            // i = 2: r1 = 4, r2 = 5
            // i = 3: r1 = 6, r2 = 7
            // ...
            // This initialization assumes that we control each actuator via two
            // relays.
            struct Actuator a = {
                .relay_1 = &(relays[i * 2]),
                .relay_2 = &(relays[i * 2 + 1]),
                .relays_num = relays_num};
            memcpy(actuator, &a, actuator_size);
            (*actuators_p)[i] = actuator;
            ESP_LOGI(TAG, "Iniitialized actuator %u (pointer to actuator: %p)", i, actuator);
        }
    }
    else
    {
        ESP_LOGE(TAG, "%s while initializing the actuators.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    ESP_LOGI(TAG, "Completed actuators initialization (pointer to pointer to actuators pointers array: %p, pointer to actuators pointer array: %p)", actuators_p, *actuators_p);

    return ret;
}

esp_err_t
register_actuators_events(struct Actuator **actuators, size_t actuators_num)
{
    ESP_LOGI(TAG, "Registering events for %u actuators (actuators pointer: %p)...", actuators_num, actuators);
    esp_err_t ret = ESP_OK;
    char err_msg[20];

    struct ActuatorsEventMessage *actuators_event_message_p = NULL;
    size_t actuators_event_message_size = sizeof(struct ActuatorsEventMessage);
    if ((actuators_event_message_p = calloc(1, actuators_event_message_size)) == NULL)
    {
        ret = ESP_ERR_NO_MEM;
        ESP_LOGE(TAG, "%s while allocating memory for the actuators event message.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
        return ret;
    }

    struct ActuatorsEventMessage actuators_event_message =
        {
            .actuators = actuators,
            .actuators_num = actuators_num};
    memcpy(actuators_event_message_p, &actuators_event_message, actuators_event_message_size);

    ESP_LOGI(TAG, "Loaded the pointer to actuators in the actuators event message: %p...", actuators);

    ESP_LOGI(TAG, "Registering the handler for EXTEND_ACTUATORS_EVENT event (event_handler_arg pointer: %p)...", actuators_event_message_p);
    if ((ret = esp_event_handler_instance_register(ACTUATOR_EVENT, EXTEND_ACTUATORS_EVENT, operate_actuators, actuators_event_message_p, NULL)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while registering the handler for the EXTEND_ACTUATORS_EVENT event.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    ESP_LOGI(TAG, "Registering the handler for RETRACT_ACTUATORS_EVENT event (event_handler_arg pointer: %p)...", actuators_event_message_p);
    if ((ret = esp_event_handler_instance_register(ACTUATOR_EVENT, RETRACT_ACTUATORS_EVENT, operate_actuators, actuators_event_message_p, NULL)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while registering the handler for the RETRACT_ACTUATORS_EVENT event.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    ESP_LOGI(TAG, "Registering the handler for SHUTDOWN_ACTUATORS_EVENT event (event_handler_arg pointer: %p)...", actuators_event_message_p);
    if ((ret = esp_event_handler_instance_register(ACTUATOR_EVENT, SHUTDOWN_ACTUATORS_EVENT, operate_actuators, actuators_event_message_p, NULL)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while registering the handler for the SHUTDOWN_ACTUATORS_EVENT event.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    // Create and start the event sources for the safety timer
    esp_timer_create_args_t timer_args = {
        .callback = &actuators_safety_timer_callback};

    ESP_LOGD(TAG, "Registering the handler for the safety timer...");
    if ((ret = esp_timer_create(&timer_args, &safety_timer)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while registering the handler for the safety timer.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    return ret;
}
