#include "fps_overlay.h"

#include <stdio.h>

// 5x7 bitmap glyphs: 0-9 and '.'
static const uint8_t gGlyphs[11][7] = {
    { 0x0e, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0e }, // 0
    { 0x04, 0x0c, 0x04, 0x04, 0x04, 0x04, 0x0e }, // 1
    { 0x0e, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1f }, // 2
    { 0x1f, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0e }, // 3
    { 0x02, 0x06, 0x0a, 0x12, 0x1f, 0x02, 0x02 }, // 4
    { 0x1f, 0x10, 0x1e, 0x01, 0x01, 0x11, 0x0e }, // 5
    { 0x06, 0x08, 0x10, 0x1e, 0x11, 0x11, 0x0e }, // 6
    { 0x1f, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08 }, // 7
    { 0x0e, 0x11, 0x11, 0x0e, 0x11, 0x11, 0x0e }, // 8
    { 0x0e, 0x11, 0x11, 0x0f, 0x01, 0x02, 0x0c }, // 9
    { 0x00, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x0c }, // .
};

static float gDisplay_fps;
static uint32_t gLast_fps_time;
static int gFrame_count;

static int glyph_index(char c) {
    if (c >= '0' && c <= '9') {
        return c - '0';
    }
    if (c == '.') {
        return 10;
    }
    return -1;
}

static void draw_glyph(uint32_t* pixels, int pitch_px, int width, int height, int x, int y, int glyph, int scale, uint32_t color) {
    int row;
    int col;
    int py;
    int px;
    int bit;
    uint32_t* dst;

    for (row = 0; row < 7; row++) {
        for (col = 0; col < 5; col++) {
            bit = (gGlyphs[glyph][row] >> (4 - col)) & 1;
            if (!bit) {
                continue;
            }
            for (py = 0; py < scale; py++) {
                for (px = 0; px < scale; px++) {
                    int draw_x = x + col * scale + px;
                    int draw_y = y + row * scale + py;
                    if (draw_x < 0 || draw_y < 0 || draw_x >= width || draw_y >= height) {
                        continue;
                    }
                    dst = pixels + draw_y * pitch_px + draw_x;
                    *dst = color;
                }
            }
        }
    }
}

static void draw_text(uint32_t* pixels, int pitch_px, int width, int height, int x, int y, const char* text, int scale, uint32_t color) {
    int cursor_x = x;
    const char* c;

    for (c = text; *c != '\0'; c++) {
        int glyph = glyph_index(*c);
        if (glyph < 0) {
            continue;
        }
        draw_glyph(pixels, pitch_px, width, height, cursor_x, y, glyph, scale, color);
        cursor_x += 6 * scale;
    }
}

void FpsOverlay_Tick(uint32_t now_ms) {
    gFrame_count++;
    if (gLast_fps_time == 0) {
        gLast_fps_time = now_ms;
        return;
    }
    if (now_ms - gLast_fps_time >= 500) {
        gDisplay_fps = (float)gFrame_count * 1000.0f / (float)(now_ms - gLast_fps_time);
        gFrame_count = 0;
        gLast_fps_time = now_ms;
    }
}

void FpsOverlay_Draw(uint32_t* pixels, int pitch_bytes, int width, int height) {
    char text[16];
    int whole;
    int fraction;
    int pitch_px = pitch_bytes / (int)sizeof(uint32_t);

    whole = (int)gDisplay_fps;
    fraction = (int)((gDisplay_fps - (float)whole) * 10.0f);
    if (fraction < 0) {
        fraction = 0;
    }
    if (fraction > 9) {
        fraction = 9;
    }
    snprintf(text, sizeof(text), "%d.%d", whole, fraction);
    draw_text(pixels, pitch_px, width, height, 2, 2, text, 1, 0xff40ff40u);
}
