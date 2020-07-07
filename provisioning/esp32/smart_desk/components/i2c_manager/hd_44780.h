// LCD display positions
#define LCD_LINEONE 0x00   // Start of line 1
#define LCD_LINETWO 0x40   // Start of line 2
#define LCD_LINETHREE 0x14 // Start of line 3
#define LCD_LINEFOUR 0x54  // Start of line 4

// Register select (instruction or data, RS bit)
#define LCD_INSTRUCTION_REGISTER 0
#define LCD_DATA_REGISTER 1

#define LCD_SEND_4_BITS 0
#define LCD_SEND_8_BITS 1

// Command mode (read or write, R/W bit)
#define LCD_WRITE_MODE 0x00 // Write data to the LCD display (I2C master -> I2C slave)
#define LCD_READ_MODE 0x02  // Read data from the LCD display (I2C slave -> I2C master) - binary: 10

// LCD Backlight bits
#define LCD_BACKLIGHT_ON_MASK 0xFF  // Backlight mask used when backlight is ON
#define LCD_BACKLIGHT_OFF_MASK 0x00 // Backlight mask used when backlight is OFF
#define BACKLIGHT_OFF 0             // Used in combination with the setBacklight to switch the LCD backlight OFF
#define BACKLIGHT_ON 255            // Used in combination with the setBacklight to switch the LCD backlight ON

// LCD commands
#define LCD_CLEAR_DISPLAY 0x01           // Replace all characters with ASCII SP (space, code 32, 0x20) - binary: 1
#define LCD_RETURN_HOME 0x02             // Return cursor to first position on first line  - binary: 10
#define LCD_ENTRY_MODE_SET 0x04          // Set the direction of the cursor movement and display shift - binary: 100
#define LCD_DISPLAY_ON_OFF 0x08          // Turn on or off the display, show or hide the cursor, turn on or off cursor blinking - binary: 1000
#define LCD_CURSOR_OR_DISPLAY_SHIFT 0x10 // Shift cursor or display position (useful to search or to correct data)
#define LCD_FUNCTION_SET 0x20            // Set 8-bit or 4-bit command mode, set 1-line or 2-line display mode, set 5x8 or 5x11 font mode - binary: 100000
#define LCD_SET_CGRAM_ADDRESS 0x40       // Set CGRAM address
#define LCD_SET_DDRAM_ADDRESS 0x80       // Set DDRAM address (cursor position) - binary: 10000000

// LCD reset command
#define LCD_FUNCTION_RESET 0x03            // Reset the LCD controller when in 4-bits mode
#define LCD_FUNCTION_SET_4_BITS_RESET 0x02 // Set 4-bits mode during initialization when in 4-bits mode

// LCD entry mode command parameters
#define LCD_ENTRY_MODE_SET_INCREMENT_DDRAM_ADDRESS 0x02 // Cursor moves to right and DDRAM address is increased by 1
#define LCD_ENTRY_MODE_SET_DECREMENT_DDRAM_ADDRESS 0x00 // Cursor moves to left and DDRAM address is decreased by 1
#define LCD_ENTRY_MODE_SET_SHIFT_DISPLAY 0x01           // When reading from DDRAM, or reading from or writing to CGRAM, shift the entire display according to increment or decrement
#define LCD_ENTRY_MODE_SET_NO_SHIFT_DISPLAY 0x00        // When reading from DDRAM, or reading from or writing to CGRAM, don't shift the entire display according to increment or decrement

// LCD display on/off command parameters
#define LCD_DISPLAY_ON_OFF_DISPLAY_ON 0x04  // Turn the entire display on - binary: 100
#define LCD_DISPLAY_ON_OFF_DISPLAY_OFF 0x00 // Turn the entire display off, but data remains in DDRAM
#define LCD_DISPLAY_ON_OFF_CURSOR_ON 0x02   // Show the cursor - binary: 10
#define LCD_DISPLAY_ON_OFF_CURSOR_OFF 0x00  // Hide the cursor, but the cursor position register preserves data
#define LCD_DISPLAY_ON_OFF_BLINK_ON 0x01    // Enable cursor blinking
#define LCD_DISPLAY_ON_OFF_BLINK_OFF 0x00   // Disable cursor blinking

// LCD shift command parameters
#define LCD_CURSOR_OR_DISPLAY_SHIFT_CURSOR_LEFT_DECREASE_AC 0x00  // Shift cursor to the left, AC is decreased by 1
#define LCD_CURSOR_OR_DISPLAY_SHIFT_CURSOR_RIGHT_INCREASE_AC 0x01 // Shift cursor to the right, AC is increased by 1
#define LCD_CURSOR_OR_DISPLAY_SHIFT_SHIFT_DISPLAY_LEFT 0x02       // Shift all the display to the left, Cursor moves according to the display
#define LCD_CURSOR_OR_DISPLAY_SHIFT_SHIFT_DISPLAY_RIGHT 0x03      // Shift all the display to the right, cursor moves according to the display

// LCD function parameters
#define LCD_FUNCTION_SET_8_BIT 0x10   // Enable 8-bit bus mode
#define LCD_FUNCTION_SET_4_BIT 0x00   // Enable 4-bit bus mode
#define LCD_FUNCTION_SET_1_LINE 0x00  // Enable 1-line display mode
#define LCD_FUNCTION_SET_2_LINES 0x08 // Enable 2-lines display mode - binary: 1000
#define LCD_FUNCTION_SET_5X8 0x00     // Enable 5x8 font mode
#define LCD_FUNCTION_SET_5X11 0x04    // Enable 5x11 font mode

void LCD_init(uint8_t addr, uint8_t cols, uint8_t rows, uint8_t En, uint8_t Rw, uint8_t Rs, uint8_t d4, uint8_t d5, uint8_t d6, uint8_t d7, uint8_t backlighPin, uint8_t initial_bit_mode);
void LCD_setCursor(uint8_t col, uint8_t row);
void LCD_home(void);
void LCD_clearScreen(void);
void LCD_switchBacklightOff(void);
void LCD_switchBacklightOn(void);
void LCD_turnDisplayOff(void);
void LCD_turnDisplayOn(void);
void LCD_writeChar(char c);
void LCD_writeStr(const char *str);

void LCD_Demo();

void register_lcd_events();
