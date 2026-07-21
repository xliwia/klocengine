#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <ft2build.h>
#include FT_FREETYPE_H

typedef struct {
  FT_Library library;
  FT_Face face;
  int size;
  int ascent;
} FontHandle;

void* font_load(const char* path, int size) {
  FontHandle* font = (FontHandle*)calloc(1, sizeof(FontHandle));
  if (!font) return NULL;

  if (FT_Init_FreeType(&font->library) != 0) {
    free(font);
    return NULL;
  }

  if (FT_New_Face(font->library, path, 0, &font->face) != 0) {
    FT_Done_FreeType(font->library);
    free(font);
    return NULL;
  }

  if (FT_Set_Pixel_Sizes(font->face, 0, size) != 0) {
    FT_Done_Face(font->face);
    FT_Done_FreeType(font->library);
    free(font);
    return NULL;
  }

  font->size = size;
  font->ascent = (int)ceil(font->face->size->metrics.ascender / 64.0f);
  return font;
}

void font_free(void* handle) {
  FontHandle* font = (FontHandle*)handle;
  if (!font) return;
  if (font->face) FT_Done_Face(font->face);
  if (font->library) FT_Done_FreeType(font->library);
  free(font);
}

void font_free_pixels(unsigned char* pixels) {
  free(pixels);
}

int font_text_width(void* handle, const char* text, float scale) {
  FontHandle* font = (FontHandle*)handle;
  if (!font || !text) return 0;

  int width = 0;
  int cursorX = 0;
  const unsigned char* p = (const unsigned char*)text;
  while (*p) {
    unsigned long cp = *p;
    if (cp == '\n' || cp == '\r') {
      p++;
      continue;
    }
    if (cp == ' ') {
      cursorX += (int)ceil(4.0f * scale);
      if (cursorX > width) width = cursorX;
      p++;
      continue;
    }

    if (FT_Load_Char(font->face, cp, FT_LOAD_RENDER | FT_LOAD_TARGET_NORMAL) != 0) {
      p++;
      continue;
    }

    FT_Bitmap* bitmap = &font->face->glyph->bitmap;
    int glyphAdvance = (int)ceil(font->face->glyph->advance.x / 64.0f * scale);
    cursorX += glyphAdvance;
    if (cursorX > width) width = cursorX;
    p++;
  }

  return width > 0 ? width : 1;
}

unsigned char* font_render_text(void* handle, const char* text, float scale, int* outW, int* outH) {
  FontHandle* font = (FontHandle*)handle;
  if (!font || !text || !outW || !outH) return NULL;

  int width = 0;
  int height = 0;
  int cursorX = 0;
  int baseline = font->ascent;
  const unsigned char* p = (const unsigned char*)text;

  while (*p) {
    unsigned long cp = *p;
    if (cp == '\n' || cp == '\r') {
      p++;
      continue;
    }
    if (cp == ' ') {
      cursorX += (int)ceil(4.0f * scale);
      if (cursorX > width) width = cursorX;
      p++;
      continue;
    }

    if (FT_Load_Char(font->face, cp, FT_LOAD_RENDER | FT_LOAD_TARGET_NORMAL) != 0) {
      p++;
      continue;
    }

    FT_Bitmap* bitmap = &font->face->glyph->bitmap;
    int glyphWidth = bitmap->width;
    int glyphHeight = bitmap->rows;
    int left = font->face->glyph->bitmap_left;
    int top = font->face->glyph->bitmap_top;
    int x0 = cursorX + left;
    int y0 = baseline - top;
    int x1 = x0 + glyphWidth;
    int y1 = y0 + glyphHeight;
    int advance = (int)ceil(font->face->glyph->advance.x / 64.0f * scale);

    if (x1 > width) width = x1;
    if (y1 > height) height = y1;
    cursorX += advance;
    p++;
  }

  if (width <= 0) width = 1;
  if (height <= 0) height = 1;

  unsigned char* pixels = (unsigned char*)calloc(width * height, 1);
  if (!pixels) return NULL;

  cursorX = 0;
  p = (const unsigned char*)text;
  while (*p) {
    unsigned long cp = *p;
    if (cp == '\n' || cp == '\r') {
      p++;
      continue;
    }
    if (cp == ' ') {
      cursorX += (int)ceil(4.0f * scale);
      p++;
      continue;
    }

    if (FT_Load_Char(font->face, cp, FT_LOAD_RENDER | FT_LOAD_TARGET_NORMAL) != 0) {
      p++;
      continue;
    }

    FT_Bitmap* bitmap = &font->face->glyph->bitmap;
    int glyphWidth = bitmap->width;
    int glyphHeight = bitmap->rows;
    int left = font->face->glyph->bitmap_left;
    int top = font->face->glyph->bitmap_top;
    int x0 = cursorX + left;
    int y0 = baseline - top;
    int advance = (int)ceil(font->face->glyph->advance.x / 64.0f * scale);

    for (int row = 0; row < glyphHeight; row++) {
      for (int col = 0; col < glyphWidth; col++) {
        unsigned char alpha = bitmap->buffer[row * bitmap->pitch + col];
        if (alpha > 0) {
          int px = x0 + col;
          int py = y0 + row;
          if (px >= 0 && px < width && py >= 0 && py < height) {
            pixels[py * width + px] = alpha;
          }
        }
      }
    }

    cursorX += advance;
    p++;
  }

  *outW = width;
  *outH = height;
  return pixels;
}