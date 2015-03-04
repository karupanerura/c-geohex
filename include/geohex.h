#ifndef GEOHEX_H
#define GEOHEX_H

#include <math.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>

#define GEOHEX_MIN_LEVEL           0
#define GEOHEX_MAX_LEVEL           15
#define GEOHEX_GLOBAL_CODE_BUFSIZE 4
#define GEOHEX_DEC9_BUFSIZE        32
#define GEOHEX_DEC3_BUFSIZE        64

typedef struct _geohex_location_s {
  double lat;
  double lng;
} geohex_location_t;

typedef struct _geohex_coordinate_s {
  double x;
  double y;
  bool   rev;
} geohex_coordinate_t;

struct _geohex_location_lrpair_s {
  geohex_location_t right;
  geohex_location_t left;
};

typedef struct _geohex_polygon_s {
  struct _geohex_location_lrpair_s top;
  struct _geohex_location_lrpair_s middle;
  struct _geohex_location_lrpair_s bottom;
} geohex_polygon_t;

typedef struct _geohex_s {
  geohex_location_t   location;
  geohex_coordinate_t coordinate;
  char                code[GEOHEX_MAX_LEVEL + 3];
  size_t              level;
  double              size;
} geohex_t;

inline geohex_coordinate_t geohex_coordinate (const double x, const double y) {
  const geohex_coordinate_t coordinate = { .x = x, .y = y, .rev = false };
  return coordinate;
}

inline geohex_location_t geohex_location (const double lat, const double lng) {
  const geohex_location_t location = { .lat = lat, .lng = lng };
  return location;
}

inline size_t geohex_calc_level_by_code(const char *code) {
  return strlen(code) - 2;
}

extern geohex_coordinate_t geohex_location2coordinate(const geohex_location_t location);
extern geohex_location_t   geohex_coordinate2location(const geohex_coordinate_t coordinate);
extern geohex_t            geohex_get_zone_by_location(const geohex_location_t location, size_t level);
extern geohex_t            geohex_get_zone_by_coordinate(const geohex_coordinate_t coordinate, size_t level);
extern geohex_t            geohex_get_zone_by_code(const char *code);
extern geohex_coordinate_t geohex_get_coordinate_by_location(const geohex_location_t location, size_t level);
extern geohex_coordinate_t geohex_get_coordinate_by_code(const char *code);
extern geohex_coordinate_t geohex_adjust_coordinate(const geohex_coordinate_t coordinate, size_t level);
extern geohex_polygon_t    geohex_get_hex_polygon (const geohex_t *geohex);
extern double              geohex_get_hex_size (const geohex_t *geohex);

#endif
