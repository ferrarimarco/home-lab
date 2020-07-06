#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include "esp_timer.h"
#include "esp_log.h"

#include "ultrasonic.h"

#define TRIGGER_LOW_DELAY 4
#define TRIGGER_HIGH_DELAY 10
#define PING_TIMEOUT 6000
#define ROUNDTRIP 58

static portMUX_TYPE mux = portMUX_INITIALIZER_UNLOCKED;
#define PORT_ENTER_CRITICAL portENTER_CRITICAL(&mux)
#define PORT_EXIT_CRITICAL portEXIT_CRITICAL(&mux)

#define timeout_expired(start, len) ((esp_timer_get_time() - (start)) >= (len))

#define CHECK_ARG(VAL)                  \
    do                                  \
    {                                   \
        if (!(VAL))                     \
            return ESP_ERR_INVALID_ARG; \
    } while (0)
#define CHECK(x)                \
    do                          \
    {                           \
        esp_err_t __;           \
        if ((__ = x) != ESP_OK) \
            return __;          \
    } while (0)
#define RETURN_CRITICAL(RES) \
    do                       \
    {                        \
        PORT_EXIT_CRITICAL;  \
        return RES;          \
    } while (0)

static const char *TAG = "ultrasonic";

ESP_EVENT_DEFINE_BASE(ULTRASONIC_EVENTS);

esp_err_t ultrasonic_init(const ultrasonic_sensor_t *dev)
{
    CHECK_ARG(dev);

    CHECK(gpio_set_direction(dev->trigger_pin, GPIO_MODE_OUTPUT));
    CHECK(gpio_set_direction(dev->echo_pin, GPIO_MODE_INPUT));

    return gpio_set_level(dev->trigger_pin, 0);
}

esp_err_t ultrasonic_measure_cm(const ultrasonic_sensor_t *dev, uint32_t *distance)
{
    CHECK_ARG(dev && distance);

    PORT_ENTER_CRITICAL;

    // Ping: Low for 2..4 us, then high 10 us
    CHECK(gpio_set_level(dev->trigger_pin, 0));
    ets_delay_us(TRIGGER_LOW_DELAY);
    CHECK(gpio_set_level(dev->trigger_pin, 1));
    ets_delay_us(TRIGGER_HIGH_DELAY);
    CHECK(gpio_set_level(dev->trigger_pin, 0));

    // Previous ping isn't ended
    if (gpio_get_level(dev->echo_pin))
        RETURN_CRITICAL(ESP_ERR_ULTRASONIC_PING);

    // Wait for echo
    int64_t start = esp_timer_get_time();
    while (!gpio_get_level(dev->echo_pin))
    {
        if (timeout_expired(start, PING_TIMEOUT))
            RETURN_CRITICAL(ESP_ERR_ULTRASONIC_PING_TIMEOUT);
    }

    // got echo, measuring
    int64_t echo_start = esp_timer_get_time();
    int64_t time = echo_start;
    int64_t meas_timeout = echo_start + dev->max_distance * ROUNDTRIP;
    while (gpio_get_level(dev->echo_pin))
    {
        time = esp_timer_get_time();
        if (timeout_expired(echo_start, meas_timeout))
            RETURN_CRITICAL(ESP_ERR_ULTRASONIC_ECHO_TIMEOUT);
    }
    PORT_EXIT_CRITICAL;

    *distance = (time - echo_start) / ROUNDTRIP;

    struct DistanceMeasure distance_measure = {
        *distance,
        dev->min_distance,
        dev->max_distance};

    ESP_ERROR_CHECK(esp_event_post(ULTRASONIC_EVENTS, ULTRASONIC_EVENT_MEASURE_AVAILABLE, &distance_measure, sizeof(distance_measure), portMAX_DELAY));

    return ESP_OK;
}
void ultrasonic_sensor_demo(const ultrasonic_sensor_t *dev)
{
    while (true)
    {
        uint32_t distance;
        esp_err_t res = ultrasonic_measure_cm(dev, &distance);
        if (res != ESP_OK)
        {
            switch (res)
            {
            case ESP_ERR_ULTRASONIC_PING:
                ESP_LOGE(TAG, "Cannot ping (device is in invalid state)");
                break;
            case ESP_ERR_ULTRASONIC_PING_TIMEOUT:
                ESP_LOGE(TAG, "Ping timeout (no device found)");
                break;
            case ESP_ERR_ULTRASONIC_ECHO_TIMEOUT:
                ESP_LOGE(TAG, "Echo timeout (i.e. distance too big)");
                break;
            default:
                ESP_LOGE(TAG, "Error: %d\n", res);
            }
        }
        else
            ESP_LOGI(TAG, "Measured distance: %d cm", distance);

        vTaskDelay(500 / portTICK_PERIOD_MS);
    }
}
