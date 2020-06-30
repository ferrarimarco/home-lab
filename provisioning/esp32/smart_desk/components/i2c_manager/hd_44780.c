#include <stdio.h>
#include "sdkconfig.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "driver/i2c.h"
#include "esp32/rom/ets_sys.h"

#include "hd_44780.h"

// LCD module defines
#define LCD_LINEONE 0x00   // start of line 1
#define LCD_LINETWO 0x40   // start of line 2
#define LCD_LINETHREE 0x14 // start of line 3
#define LCD_LINEFOUR 0x54  // start of line 4

#define LCD_BACKLIGHT_ON 0x08
#define LCD_BACKLIGHT_OFF 0x00
#define LCD_ENABLE 0x04
#define LCD_COMMAND 0x00
#define LCD_WRITE 0x01

#define LCD_SET_DDRAM_ADDR 0x80
#define LCD_READ_BF 0x40

// LCD commands
#define LCD_CLEAR 0x01             // replace all characters with ASCII 'space'
#define LCD_HOME 0x02              // return cursor to first position on first line
#define LCD_ENTRY_MODE 0x06        // shift cursor from left to right on read/write
#define LCD_DISPLAY_OFF 0x08       // turn display off
#define LCD_DISPLAY_ON 0x0C        // display on, cursor off, don't blink character
#define LCD_FUNCTION_RESET 0x30    // reset the LCD
#define LCD_FUNCTION_SET_4BIT 0x28 // 4-bit data, 2-line display, 5 x 7 font
#define LCD_SET_CURSOR 0x80        // set cursor position

static const char *TAG = "hd_44780";

static uint8_t LCD_addr;
static uint8_t LCD_cols;
static uint8_t LCD_rows;

static void LCD_writeNibble(uint8_t nibble, uint8_t mode);
static void LCD_writeByte(uint8_t data, uint8_t mode);
static void LCD_pulseEnable(uint8_t nibble);

void LCD_init(uint8_t addr, uint8_t cols, uint8_t rows)
{
    ESP_LOGI(TAG, "Initializing the LCD screen...");

    LCD_addr = addr;
    LCD_cols = cols;
    LCD_rows = rows;
    vTaskDelay(100 / portTICK_RATE_MS); // Initial 40 mSec delay

    ESP_LOGI(TAG, "Resetting the LCD screen...");
    LCD_writeNibble(LCD_FUNCTION_RESET, LCD_COMMAND);    // First part of reset sequence
    vTaskDelay(10 / portTICK_RATE_MS);                   // 4.1 mS delay (min)
    LCD_writeNibble(LCD_FUNCTION_RESET, LCD_COMMAND);    // second part of reset sequence
    ets_delay_us(200);                                   // 100 uS delay (min)
    LCD_writeNibble(LCD_FUNCTION_RESET, LCD_COMMAND);    // Third time's a charm
    LCD_writeNibble(LCD_FUNCTION_SET_4BIT, LCD_COMMAND); // Activate 4-bit mode
    ets_delay_us(80);                                    // 40 uS delay (min)

    // --- Busy flag now available ---
    // Function Set instruction
    ESP_LOGI(TAG, "Set LCD mode...");
    LCD_writeByte(LCD_FUNCTION_SET_4BIT, LCD_COMMAND); // Set mode, lines, and font
    ets_delay_us(80);

    // Clear Display instruction
    LCD_writeByte(LCD_CLEAR, LCD_COMMAND); // clear display RAM
    vTaskDelay(2 / portTICK_RATE_MS);      // Clearing memory takes a bit longer

    // Entry Mode Set instruction
    LCD_writeByte(LCD_ENTRY_MODE, LCD_COMMAND); // Set desired shift characteristics
    ets_delay_us(80);

    LCD_writeByte(LCD_DISPLAY_ON, LCD_COMMAND); // Ensure LCD is set to on
}

void LCD_setCursor(uint8_t col, uint8_t row)
{
    if (row > LCD_rows - 1)
    {
        ESP_LOGE(TAG, "Cannot write to row %d. Please select a row in the range (0, %d)", row, LCD_rows - 1);
        row = LCD_rows - 1;
    }
    uint8_t row_offsets[] = {LCD_LINEONE, LCD_LINETWO, LCD_LINETHREE, LCD_LINEFOUR};
    LCD_writeByte(LCD_SET_DDRAM_ADDR | (col + row_offsets[row]), LCD_COMMAND);
}

void LCD_writeChar(char c)
{
    LCD_writeByte(c, LCD_WRITE); // Write data to DDRAM
}

void LCD_writeStr(char *str)
{
    while (*str)
    {
        LCD_writeChar(*str++);
    }
}

void LCD_home(void)
{
    LCD_writeByte(LCD_HOME, LCD_COMMAND);
    vTaskDelay(2 / portTICK_RATE_MS); // This command takes a while to complete
}

void LCD_clearScreen(void)
{
    LCD_writeByte(LCD_CLEAR, LCD_COMMAND);
    vTaskDelay(2 / portTICK_RATE_MS); // This command takes a while to complete
}

static void LCD_writeNibble(uint8_t nibble, uint8_t mode)
{
    uint8_t data = (nibble & 0xF0) | mode | LCD_BACKLIGHT_ON;
    i2c_cmd_handle_t cmd = i2c_cmd_link_create();
    ESP_ERROR_CHECK(i2c_master_start(cmd));
    ESP_ERROR_CHECK(i2c_master_write_byte(cmd, (LCD_addr << 1) | I2C_MASTER_WRITE, 1));
    ESP_ERROR_CHECK(i2c_master_write_byte(cmd, data, 1));
    ESP_ERROR_CHECK(i2c_master_stop(cmd));
    ESP_ERROR_CHECK(i2c_master_cmd_begin(I2C_NUM_0, cmd, 1000 / portTICK_PERIOD_MS));
    i2c_cmd_link_delete(cmd);

    LCD_pulseEnable(data); // Clock data into LCD
}

static void LCD_writeByte(uint8_t data, uint8_t mode)
{
    LCD_writeNibble(data & 0xF0, mode);
    LCD_writeNibble((data << 4) & 0xF0, mode);
}

static void LCD_pulseEnable(uint8_t data)
{
    i2c_cmd_handle_t cmd = i2c_cmd_link_create();
    ESP_ERROR_CHECK(i2c_master_start(cmd));
    ESP_ERROR_CHECK(i2c_master_write_byte(cmd, (LCD_addr << 1) | I2C_MASTER_WRITE, 1));
    ESP_ERROR_CHECK(i2c_master_write_byte(cmd, data | LCD_ENABLE, 1));
    ESP_ERROR_CHECK(i2c_master_stop(cmd));
    ESP_ERROR_CHECK(i2c_master_cmd_begin(I2C_NUM_0, cmd, 1000 / portTICK_PERIOD_MS));
    i2c_cmd_link_delete(cmd);
    ets_delay_us(1);

    cmd = i2c_cmd_link_create();
    ESP_ERROR_CHECK(i2c_master_start(cmd));
    ESP_ERROR_CHECK(i2c_master_write_byte(cmd, (LCD_addr << 1) | I2C_MASTER_WRITE, 1));
    ESP_ERROR_CHECK(i2c_master_write_byte(cmd, (data & ~LCD_ENABLE), 1));
    ESP_ERROR_CHECK(i2c_master_stop(cmd));
    ESP_ERROR_CHECK(i2c_master_cmd_begin(I2C_NUM_0, cmd, 1000 / portTICK_PERIOD_MS));
    i2c_cmd_link_delete(cmd);
    ets_delay_us(500);
}

void LCD_Demo()
{
    ESP_LOGI(TAG, "Quick 3 blinks of backlight...");
    for (int i = 0; i < 3; i++)
    {
        ESP_LOGI(TAG, "Backlight on...");
        LCD_writeByte(LCD_BACKLIGHT_ON, LCD_COMMAND);
        vTaskDelay(250 / portTICK_RATE_MS);
        ESP_LOGI(TAG, "Backlight off...");
        LCD_writeByte(LCD_BACKLIGHT_OFF, LCD_COMMAND);
        vTaskDelay(250 / portTICK_RATE_MS);
    }
    ESP_LOGI(TAG, "Turning backlight on...");
    LCD_writeByte(LCD_BACKLIGHT_ON, LCD_COMMAND);

    ESP_LOGI(TAG, "Showing the demo...");
    char txtBuf[11];
    while (true)
    {
        int row = 0, col = 0;
        LCD_home();
        LCD_clearScreen();
        LCD_writeStr("----- 20x4 LCD -----");
        LCD_setCursor(0, 1);
        LCD_writeStr("LCD Library Demo");
        LCD_setCursor(12, 3);
        LCD_writeStr("Time: ");
        for (int i = 10; i >= 0; i--)
        {
            LCD_setCursor(18, 3);
            sprintf(txtBuf, "%02d", i);
            printf(txtBuf);
            LCD_writeStr(txtBuf);
            vTaskDelay(1000 / portTICK_RATE_MS);
        }

        for (int i = 0; i < 80; i++)
        {
            LCD_clearScreen();
            LCD_setCursor(col, row);
            LCD_writeChar('*');

            if (i >= 19)
            {
                row = (i + 1) / 20;
            }
            if (col++ >= 19)
            {
                col = 0;
            }

            vTaskDelay(50 / portTICK_RATE_MS);
        }
    }
}
