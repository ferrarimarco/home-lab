#include "ultrasonic.h"

#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#define TRIGGER_LOW_DELAY 4
#define TRIGGER_HIGH_DELAY 10
#define PING_TIMEOUT 6000
#define ROUNDTRIP 58

static portMUX_TYPE mux = portMUX_INITIALIZER_UNLOCKED;

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

    portENTER_CRITICAL(&mux);

    esp_err_t ret = ESP_OK;
    char err_msg[20];

    // Ping: Low for 2..4 us, then high 10 us
    CHECK(gpio_set_level(dev->trigger_pin, 0));
    ets_delay_us(TRIGGER_LOW_DELAY);
    CHECK(gpio_set_level(dev->trigger_pin, 1));
    ets_delay_us(TRIGGER_HIGH_DELAY);
    CHECK(gpio_set_level(dev->trigger_pin, 0));

    // Previous ping isn't ended
    if (gpio_get_level(dev->echo_pin))
    {
        ret = ESP_ERR_ULTRASONIC_PING;
        ESP_LOGE(TAG, "%s: cannot ping the distance sensor: device is in invalid state.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    // Wait for echo
    int64_t start = esp_timer_get_time();
    while (ret == ESP_OK && !gpio_get_level(dev->echo_pin))
    {
        if (timeout_expired(start, PING_TIMEOUT))
        {
            ret = ESP_ERR_ULTRASONIC_PING_TIMEOUT;
            ESP_LOGE(TAG, "%s: distance sensor ping timeout: (likely) no device found.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
            break;
        }
    }

    int64_t echo_start = esp_timer_get_time();
    int64_t time = echo_start;
    int64_t meas_timeout = echo_start + dev->max_distance * ROUNDTRIP;
    if (ret == ESP_OK)
    {
        // got echo, measuring

        while (ret == ESP_OK && gpio_get_level(dev->echo_pin))
        {
            time = esp_timer_get_time();
            if (timeout_expired(echo_start, meas_timeout))
            {
                ret = ESP_ERR_ULTRASONIC_ECHO_TIMEOUT;
                ESP_LOGE(TAG, "%s: distance sensor echo timeout: (likely) distance is too big to measure.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
                break;
            }
        }
    }

    portEXIT_CRITICAL(&mux);

    if (ret == ESP_OK)
    {
        *distance = (time - echo_start) / ROUNDTRIP;
        ESP_LOGD(TAG, "Measured distance: %d cm", *distance);

        if (*distance < dev->min_distance || *distance > dev->max_distance)
        {
            ret = ESP_ERR_ULTRASONIC_DISTANCE_OUT_OF_RANGE;
            ESP_LOGW(TAG, "%s: Measured distance (%d) is out of the validity range.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)), *distance);
        }

        struct DistanceMeasure distance_measure = {
            *distance,
            dev->min_distance,
            dev->max_distance,
            ret};

        if ((ret = esp_event_post(ULTRASONIC_EVENTS, ULTRASONIC_EVENT_MEASURE_AVAILABLE, &distance_measure, sizeof(distance_measure), portMAX_DELAY)) != ESP_OK)
            ESP_LOGE(TAG, "%s while sending the ULTRASONIC_EVENT_MEASURE_AVAILABLE event.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    return ret;
}
