#ifndef HARNESS_FPS_OVERLAY_H
#define HARNESS_FPS_OVERLAY_H

#include <stdint.h>

void FpsOverlay_Tick(uint32_t now_ms);
void FpsOverlay_Draw(uint32_t* pixels, int pitch_bytes, int width, int height);

#endif
