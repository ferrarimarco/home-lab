#include <stdio.h>
#include "sdkconfig.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_event.h"
#include "driver/i2c.h"
#include "esp32/rom/ets_sys.h"

#include "hd_44780.h"
#include "i2c_utils.h"

#include "print_utils.h"

#include "ultrasonic.h"

static const char *TAG = "hd_44780";

static uint8_t LCD_addr;
static uint8_t LCD_cols;
static uint8_t LCD_rows;

static uint8_t _backlightPinMask;    // Backlight IO pin mask
static uint8_t _backlightStatusMask; // Backlight status mask
static uint8_t _En;                  // LCD expander word for enable pin
static uint8_t _Rw;                  // LCD expander word for R/W pin
static uint8_t _Rs;                  // LCD expander word for Register Select pin

// LCD data lines
static uint8_t _d4;
static uint8_t _d5;
static uint8_t _d6;
static uint8_t _d7;

static uint8_t _displayfunction;

static esp_err_t
LCD_write_4_bits(uint8_t nibble, uint8_t reg, bool enable_ack)
{
    ESP_LOGD(TAG, "Preparing 4 bits to send to the LCD: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(nibble));

    uint8_t data = 0;

    // convert the value to an i/o expander port value
    // based on pin mappings
    if (nibble & (1 << 0))
        data |= _d4;

    if (nibble & (1 << 1))
        data |= _d5;

    if (nibble & (1 << 2))
        data |= _d6;

    if (nibble & (1 << 3))
        data |= _d7;

    ESP_LOGD(TAG, "Mapped the data to send to LCD data pins: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(data));

    // Is it a command (instruction register) or data (data register)
    // -----------------------
    if (reg == LCD_DATA_REGISTER)
    {
        reg = _Rs;
    }

    data |= reg | _backlightStatusMask;

    ESP_LOGD(TAG, "Mapped the data to send to backlight, and RS pins: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(data));

    // Clock data into LCD
    uint8_t data_enable = data | _En;
    ESP_LOGD(TAG, "Mapped the data to send to Enable pin: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(data_enable));

    uint8_t data_not_enable = data & ~_En;
    ESP_LOGD(TAG, "Mapped the data to send to NOT Enable pin: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(data_not_enable));

    esp_err_t ret;
    char err_msg[20];

    if ((ret = i2c_master_write_byte_to_client_ack(LCD_addr, data_enable, false, enable_ack)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while sending bits (data bit on).", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    if (ret == ESP_OK && (ret = i2c_master_write_byte_to_client_ack(LCD_addr, data_not_enable, false, enable_ack)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while sending bits (data bit off).", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }
    ets_delay_us(500);
    return ret;
}

static esp_err_t send(uint8_t value, uint8_t mode, uint8_t reg, bool enable_ack)
{
    // ensure that previous LCD instruction finished.
    // There is a 45us offset since there will be at least 2 bytes
    // (the i2c address and the i/o expander data)  transmitted over i2c
    // before the i/o expander i/o pins could be seen by the LCD.
    // At 400Khz (max rate supported by the i/o expanders) 16 bits plus start
    // and stop bits is 45us.
    // So there is at least 45us of time overhead in the physical interface.
    ets_delay_us(45);

    // Wait a bit more because we're using internal pull-up resistors which
    // are slower than what the i2c spec allows
    vTaskDelay(10 / portTICK_RATE_MS);

    esp_err_t ret;
    char err_msg[20];

    ESP_LOGD(TAG, "Sending the 4 most significant bits of: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(value));
    if ((ret = LCD_write_4_bits((value >> 4), reg, enable_ack)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while sending the 4 most significant bits.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    if (ret == ESP_OK && mode == LCD_SEND_8_BITS)
    {
        ESP_LOGD(TAG, "Sending the 4 least significant bits of: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(value));
        if ((ret = LCD_write_4_bits((value & 0x0F), reg, enable_ack)) != ESP_OK)
        {
            ESP_LOGE(TAG, "%s while sending the 4 least significant bits.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
        }
    }

    return ret;
}

static void setBacklight(uint8_t value)
{
    // Check if backlight is available
    // ----------------------------------------------------
    if (_backlightPinMask != 0x0)
    {
        if (value > 0)
        {
            _backlightStatusMask = _backlightPinMask & LCD_BACKLIGHT_ON_MASK;
        }
        else
        {
            _backlightStatusMask = _backlightPinMask & LCD_BACKLIGHT_OFF_MASK;
        }

        i2c_master_write_byte_to_client_ack(LCD_addr, _backlightStatusMask, false, ACK_ON);

        ets_delay_us(80);
    }
}

esp_err_t LCD_init(uint8_t addr, uint8_t cols, uint8_t rows, uint8_t En, uint8_t Rw, uint8_t Rs, uint8_t d4, uint8_t d5, uint8_t d6, uint8_t d7, uint8_t backligh_pin, uint8_t interface_bit_mode)
{
    ESP_LOGI(TAG, "Initializing the LCD screen (I2C address: 0x%02x, rows: %d, columns: %d)...", addr, rows, cols);

    LCD_addr = addr;
    LCD_cols = cols;
    LCD_rows = rows;

    _backlightPinMask = 0;
    _backlightStatusMask = LCD_BACKLIGHT_OFF_MASK;

    ESP_LOGI(TAG, "Initializing pin mappings...");
    _En = (1 << En);
    _Rw = (1 << Rw);
    _Rs = (1 << Rs);
    _d4 = (1 << d4);
    _d5 = (1 << d5);
    _d6 = (1 << d6);
    _d7 = (1 << d7);
    _backlightPinMask = (1 << backligh_pin);

    ESP_LOGD(TAG, "RS pin mask:        " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_Rs));
    ESP_LOGD(TAG, "R/W pin mask:       " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_Rw));
    ESP_LOGD(TAG, "E pin mask:         " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_En));
    ESP_LOGD(TAG, "Backlight pin mask: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_backlightPinMask));
    ESP_LOGD(TAG, "D4 pin mask:        " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_d4));
    ESP_LOGD(TAG, "D5 pin mask:        " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_d5));
    ESP_LOGD(TAG, "D6 pin mask:        " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_d6));
    ESP_LOGD(TAG, "D7 pin mask:        " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_d7));

    // SEE PAGE 45/46 of the Hitachi HD44780 datasheet FOR INITIALIZATION SPECIFICATION!
    // according to datasheet, we need at least 40ms after power rises above 2.7V
    // before sending commands.
    ESP_LOGD(TAG, "Waiting for the Vcc to raise to 4.5V (this needs at least 40 ms)...");
    vTaskDelay(100 / portTICK_RATE_MS);

    esp_err_t ret;
    char err_msg[20];

    // There's no way to know if the HD44780 is in 4-bit mode or 8-bit mode.
    // This initialization sequence reliably sets it in 8-bit mode
    ESP_LOGD(TAG, "Beginning the initialization sequence to set the interface to 8-bits mode...");
    ESP_LOGD(TAG, "Sending the first command of the initialization sequence....");
    if ((ret = send(LCD_FUNCTION_SET | LCD_FUNCTION_SET_8_BIT, LCD_SEND_4_BITS, LCD_INSTRUCTION_REGISTER, ACK_ON)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while sending the first LCD initialization command.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
        // Return immediately because the LCD didn't ACK the data transfer
        return ret;
    }
    vTaskDelay(5 / portTICK_RATE_MS);
    ESP_LOGD(TAG, "Sending the second command of the initialization sequence....");
    if ((ret = send(LCD_FUNCTION_SET | LCD_FUNCTION_SET_8_BIT, LCD_SEND_4_BITS, LCD_INSTRUCTION_REGISTER, ACK_ON)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while sending the second LCD initialization command.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
        // Return immediately because the LCD didn't ACK the data transfer
        return ret;
    }
    vTaskDelay(1 / portTICK_RATE_MS);
    ESP_LOGD(TAG, "Sending the third command of the initialization sequence....");
    if ((ret = send(LCD_FUNCTION_SET | LCD_FUNCTION_SET_8_BIT, LCD_SEND_4_BITS, LCD_INSTRUCTION_REGISTER, ACK_ON)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while sending the third LCD initialization command.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
        // Return immediately because the LCD didn't ACK the data transfer
        return ret;
    }
    vTaskDelay(1 / portTICK_RATE_MS);
    ESP_LOGI(TAG, "Initialization sequence completed.");

    ESP_LOGD(TAG, "Initializing the display function...");
    _displayfunction = LCD_FUNCTION_SET;

    if (!(interface_bit_mode & LCD_FUNCTION_SET_8_BIT))
    {
        ESP_LOGD(TAG, "Setting interface to 4-bits mode...");
        ret = send(LCD_FUNCTION_SET | LCD_FUNCTION_SET_4_BIT, LCD_SEND_4_BITS, LCD_INSTRUCTION_REGISTER, ACK_ON);
        _displayfunction |= LCD_FUNCTION_SET_4_BIT;
    }
    else
    {
        ESP_LOGD(TAG, "Leaving the interface in 8-bits mode...");
        _displayfunction |= LCD_FUNCTION_SET_8_BIT;
    }

    if (rows > 1)
    {
        ESP_LOGD(TAG, "Enabling 2-lines mode...");
        _displayfunction |= LCD_FUNCTION_SET_2_LINES;
    }

    ESP_LOGD(TAG, "Enabling 5x8 font...");
    _displayfunction |= LCD_FUNCTION_SET_5X8;

    ESP_LOGD(TAG, "Display function value: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_displayfunction));
    ESP_LOGD(TAG, "Sending the Function Set command...");
    ret = send(_displayfunction, LCD_SEND_8_BITS, LCD_INSTRUCTION_REGISTER, ACK_ON);
    ets_delay_us(80);

    LCD_turnDisplayOff();
    LCD_clearScreen();

    ESP_LOGD(TAG, "Setting LCD entry mode...");
    ret = send(LCD_ENTRY_MODE_SET | LCD_ENTRY_MODE_SET_INCREMENT_DDRAM_ADDRESS, LCD_SEND_8_BITS, LCD_INSTRUCTION_REGISTER, ACK_ON);
    ets_delay_us(80);

    LCD_home();
    LCD_turnDisplayOn();
    LCD_switchBacklightOn();

    return ret;
}

void LCD_setCursor(uint8_t col, uint8_t row)
{
    ESP_LOGD(TAG, "Set cursor to col %d, row %d", col, row);
    if (row > LCD_rows - 1)
    {
        ESP_LOGE(TAG, "Cannot write to row %d. Please select a row in the range (0, %d)", row, LCD_rows - 1);
        row = LCD_rows - 1;
    }
    uint8_t row_offsets[] = {LCD_LINEONE, LCD_LINETWO, LCD_LINETHREE, LCD_LINEFOUR};
    send(LCD_SET_DDRAM_ADDRESS | (col + row_offsets[row]), LCD_SEND_8_BITS, LCD_INSTRUCTION_REGISTER, ACK_ON);
    ets_delay_us(80);
}

void LCD_writeChar(char c)
{
    ESP_LOGD(TAG, "Write char: %c", c);
    send(c, LCD_SEND_8_BITS, LCD_DATA_REGISTER, ACK_ON);
    ets_delay_us(80);
}

void LCD_writeStr(const char *str)
{
    ESP_LOGD(TAG, "Write string: %s", str);
    while (*str)
    {
        LCD_writeChar(*str++);
    }
}

void LCD_switchBacklightOff(void)
{
    ESP_LOGI(TAG, "Turning backlight off...");
    setBacklight(BACKLIGHT_OFF);
    ets_delay_us(80);
}

void LCD_switchBacklightOn(void)
{
    ESP_LOGI(TAG, "Turning backlight on...");
    setBacklight(BACKLIGHT_ON);
    ets_delay_us(80);
}

void LCD_home(void)
{
    ESP_LOGI(TAG, "Returning the cursor home...");
    send(LCD_RETURN_HOME, LCD_SEND_8_BITS, LCD_INSTRUCTION_REGISTER, ACK_ON);
    vTaskDelay(2 / portTICK_RATE_MS); // This command takes a while to complete
}

void LCD_clearScreen(void)
{
    ESP_LOGI(TAG, "Clearing the LCD...");
    send(LCD_CLEAR_DISPLAY, LCD_SEND_8_BITS, LCD_INSTRUCTION_REGISTER, ACK_ON);
    vTaskDelay(3 / portTICK_RATE_MS);
}

void LCD_turnDisplayOff(void)
{
    ESP_LOGI(TAG, "Turning the Display OFF...");
    send(LCD_DISPLAY_ON_OFF | LCD_DISPLAY_ON_OFF_DISPLAY_OFF, LCD_SEND_8_BITS, LCD_INSTRUCTION_REGISTER, ACK_ON);
    ets_delay_us(80);
}

void LCD_turnDisplayOn(void)
{
    ESP_LOGI(TAG, "Turning the Display ON...");
    send(LCD_DISPLAY_ON_OFF | LCD_DISPLAY_ON_OFF_DISPLAY_ON | LCD_DISPLAY_ON_OFF_CURSOR_OFF | LCD_DISPLAY_ON_OFF_BLINK_OFF, LCD_SEND_8_BITS, LCD_INSTRUCTION_REGISTER, ACK_ON);
    ets_delay_us(80);
}

static void sta_got_ip_event_handler(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGI(TAG, "%s: %u sta_got_ip_event_handler", event_base, event_id);
    ip_event_got_ip_t *event = (ip_event_got_ip_t *)event_data;
    esp_ip4_addr_t ip_address = event->ip_info.ip;

    char txtBuf[16];
    sprintf(txtBuf, IPSTR, IP2STR(&ip_address));
    ESP_LOGI(TAG, "Got IP address: %s", txtBuf);
    LCD_setCursor(4, 0);
    LCD_writeStr(txtBuf);
}

static void ultrasonic_sensor_measure_available_handler(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGD(TAG, "%s: %u ultrasonic_sensor_measure_available_handler", event_base, event_id);
    struct DistanceMeasure distance_measure = *((struct DistanceMeasure *)event_data);
    char txtBuf[11];

    if (distance_measure.return_code == ESP_OK)
        sprintf(txtBuf, "%03u", distance_measure.distance);
    else
        sprintf(txtBuf, "N/A");

    LCD_setCursor(10, 1);
    LCD_writeStr(txtBuf);
}

esp_err_t register_lcd_events()
{
    esp_err_t ret = ESP_OK;
    char err_msg[20];

    ESP_LOGI(TAG, "Registering the handler for IP_EVENT_STA_GOT_IP event...");
    if ((ret = esp_event_handler_instance_register(IP_EVENT, IP_EVENT_STA_GOT_IP, sta_got_ip_event_handler, NULL, NULL)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while registering the handler for the IP_EVENT_STA_GOT_IP event.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    ESP_LOGI(TAG, "Registering the handler for ULTRASONIC_EVENT_MEASURE_AVAILABLE event...");
    if ((ret = esp_event_handler_instance_register(ULTRASONIC_EVENTS, ULTRASONIC_EVENT_MEASURE_AVAILABLE, ultrasonic_sensor_measure_available_handler, NULL, NULL)) != ESP_OK)
    {
        ESP_LOGE(TAG, "%s while registering the handler for the ULTRASONIC_EVENT_MEASURE_AVAILABLE event.", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)));
    }

    return ret;
}
