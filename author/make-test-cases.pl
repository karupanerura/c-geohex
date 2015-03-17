use strict;
use warnings;
use utf8;

my $VERSION    = 3.2;
my $URL_FORMAT = "http://geohex.net/testcase/hex_v${VERSION}_test_%s.json";
my @CASES = qw!
    XY2HEX
    code2HEX
    code2XY
    coord2HEX
    coord2XY
!;

use File::Temp qw/tempdir/;
use File::Spec;
use HTTP::Tiny;
use JSON::PP;

main();

sub main {
    my $dir = tempdir(CLEANUP => 1);

    # download
    my $ua = HTTP::Tiny->new;
    for my $case (@CASES) {
        my $url = sprintf $URL_FORMAT, $case;
        print STDERR "Download: $url\n";

        my $path = File::Spec->catfile($dir, "$case.json");
        my $res = $ua->mirror($url, $path);
        die "Failed: $res->{reason}" unless $res->{success};
    }

    # parse & generate
    my @src;
    my $json = JSON::PP->new;
    for my $case (@CASES) {
        my $path = File::Spec->catfile($dir, "$case.json");
        print STDERR "Parse: $path\n";
        open my $fh, '<', $path or die $!;

        my $content  = do { local $/; <$fh> };
        my $testdata = $json->decode($content);
        my $subname  = "gen_$case";
        push @src => __PACKAGE__->can($subname)->($testdata);
    }

    my $src = join "\n", @src;
    print <<"EOD";
/* use `make test` to run the test */
/* This code is generated by $0    */
/* DO *NOT* EDIT IT DIRECTRY       */

#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <math.h>
#include "picotest.h"
#include "geohex.h"

void xy2hex (void);
void code2hex (void);
void code2xy (void);
void coord2hex (void);
void coord2xy (void);

int main (void) {
  subtest("XY2HEX(geohex_get_zone_by_coordinate)",        xy2hex);
  subtest("code2HEX(geohex_get_zone_by_code)",            code2hex);
  subtest("code2XY(geohex_get_zone_by_code)",             code2xy);
  subtest("coord2HEX(geohex_get_zone_by_location)",       coord2hex);
  subtest("coord2XY(geohex_get_coordinate_by_location)",  coord2xy);
  return done_testing();
}

inline bool cmp_num (const long double got, const long double expected) {
  const static long double diff = 0.000000000001L;
  return got == expected || (expected - diff < got && got < expected + diff);
}

inline void str_is (const char* got, const char* expected, const char* msg) {
  const bool ok = strcmp(got, expected) == 0;
  ok(ok);
  if (!ok) note("%s: expected: %s, but got: %s", msg, expected, got);
}

inline void location_is (const geohex_location_t got, const geohex_location_t expected, const char* msg) {
  const bool ok = cmp_num(got.lat, expected.lat) && cmp_num(got.lng, expected.lng);
  ok(ok);
  if (!ok) note("%s: expected: lat:%Lf,lng:%Lf, but got: lat:%Lf,lng:%Lf", msg, expected.lat, expected.lng, got.lat, got.lng);
}

inline void coordinate_is (const geohex_coordinate_t got, const geohex_coordinate_t expected, const char* msg) {
  const bool ok = got.x == expected.x && got.y == expected.y;
  ok(ok);
  if (!ok) note("%s: expected: x:%ld,y:%ld, but got: x:%ld,y:%ld", msg, expected.x, expected.y, got.x, got.y);
}

$src
EOD
}

sub gen_XY2HEX {
    my $testdata = shift;

    my @src;
    for my $row (@$testdata) {
        my ($level, $x, $y, $geohex) = @$row;
        push @src => qq{str_is(geohex_get_zone_by_coordinate(geohex_coordinate(${x}L, ${y}L), $level).code, "$geohex", "x:$x,y:$y,level:$level: $geohex");};
    }

    return sprintf <<'EOD', join "\n  ", @src;
void xy2hex (void) {
  %s
}
EOD
}

sub gen_code2HEX {
    my $testdata = shift;

    my @src;
    for my $row (@$testdata) {
        my ($geohex, $lat, $lng) = @$row;
        push @src => qq{location_is(geohex_get_zone_by_code("$geohex").location, geohex_location(${lat}L, ${lng}L), "$geohex: lat:$lat,lng:$lng");};
    }

    return sprintf <<'EOD', join "\n  ", @src;
void code2hex (void) {
  %s
}
EOD
}

sub gen_code2XY {
    my $testdata = shift;

    my @src;
    for my $row (@$testdata) {
        my ($geohex, $x, $y) = @$row;
        push @src => qq{coordinate_is(geohex_get_zone_by_code("$geohex").coordinate, geohex_coordinate(${x}L, ${y}L), "$geohex: x:$x,y:$y");};
    }

    return sprintf <<'EOD', join "\n  ", @src;
void code2xy (void) {
  %s
}
EOD
}

sub gen_coord2HEX {
    my $testdata = shift;

    my @src;
    for my $row (@$testdata) {
        my ($level, $lat, $lng, $geohex) = @$row;
        push @src => qq{str_is(geohex_get_zone_by_location(geohex_location(${lat}L, ${lng}L), $level).code, "$geohex", "lat:$lat,lng:$lng,level:$level: $geohex");};
    }

    return sprintf <<'EOD', join "\n  ", @src;
void coord2hex (void) {
  %s
}
EOD
}

sub gen_coord2XY {
    my $testdata = shift;

    my @src;
    for my $row (@$testdata) {
        my ($level, $lat, $lng, $x, $y) = @$row;
        push @src => qq{coordinate_is(geohex_get_coordinate_by_location(geohex_location(${lat}L, ${lng}L), $level), geohex_coordinate(${x}L, ${y}L), "lat:$lat,lng:$lng,level:$level: x:$x,y:$y");};
    }

    return sprintf <<'EOD', join "\n  ", @src;
void coord2xy (void) {
  %s
}
EOD
}
