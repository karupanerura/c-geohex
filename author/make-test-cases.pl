use strict;
use warnings;
use utf8;
use 5.14.0;

my $VERSION    = 3.2;
my $URL_FORMAT = "http://geohex.net/testcase/hex_v${VERSION}_test_%s.json";
my @CASES = qw!
    XY2HEX
    code2HEX
    code2XY
    coord2HEX
    coord2XY
!;

my @EXTRA = qw!
    code2coords
!;

use File::Temp qw/tempdir/;
use File::Basename qw/dirname/;
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

    # generate extra case
    for my $case (@EXTRA) {
        my $path = File::Spec->catfile(dirname(__FILE__), 'extra-case', "$case.json");
        print STDERR "Parse: $path\n";
        open my $fh, '<', $path or die $!;

        my $content  = do { local $/; <$fh> };
        my $testdata = $json->decode($content);
        my $subname  = "gen_$case";
        push @src => __PACKAGE__->can($subname)->($testdata);
    }

    my $src = join "\n", map s/^\s+$//mr, @src;
    print <<"EOD";
/* use `make test` to run the test */
/* This code is generated by $0    */
/* DO *NOT* EDIT IT DIRECTRY       */

#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <math.h>
#include "picotest.h"
#include "geohex3.h"

void xy2hex (void);
void code2hex (void);
void code2xy (void);
void coord2hex (void);
void coord2xy (void);
void code2coords (void);

int main (void) {
  subtest("XY2HEX(geohex_get_zone_by_coordinate)",        xy2hex);
  subtest("code2HEX(geohex_get_zone_by_code)",            code2hex);
  subtest("code2XY(geohex_get_zone_by_code)",             code2xy);
  subtest("coord2HEX(geohex_get_zone_by_location)",       coord2hex);
  subtest("coord2XY(geohex_get_coordinate_by_location)",  coord2xy);
  subtest("code2coords(geohex_get_hex_polygon)",          code2coords);
  return done_testing();
}

static inline bool cmp_num (const long double got, const long double expected) {
  const static long double diff = 0.000000000001L;
  return got == expected || (expected - diff < got && got < expected + diff);
}

static inline void str_is (const char* got, const char* expected, const char* msg) {
  const bool ok = strcmp(got, expected) == 0;
  ok(ok);
  if (!ok) note("%s: expected: %s, but got: %s", msg, expected, got);
}

static inline void location_is (const geohex_location_t got, const geohex_location_t expected, const char* msg) {
  const bool ok = cmp_num(got.lat, expected.lat) && cmp_num(got.lng, expected.lng);
  ok(ok);
  if (!ok) note("%s: expected: lat:%Lf,lng:%Lf, but got: lat:%Lf,lng:%Lf", msg, expected.lat, expected.lng, got.lat, got.lng);
}

static inline void coordinate_is (const geohex_coordinate_t got, const geohex_coordinate_t expected, const char* msg) {
  const bool ok = got.x == expected.x && got.y == expected.y;
  ok(ok);
  if (!ok) note("%s: expected: x:%lld,y:%lld, but got: x:%lld,y:%lld", msg, expected.x, expected.y, got.x, got.y);
}

$src
EOD
}

sub gen_XY2HEX {
    my $testdata = shift;

    my @src;

    push @src => '// verify';
    for my $row (@$testdata) {
        my (undef, undef, undef, $geohex) = @$row;
        push @src => qq{ok(geohex_verify_code("$geohex") == GEOHEX3_VERIFY_RESULT_SUCCESS);};
    }
    push @src => '';

    push @src => '// xy2hex';
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

    push @src => '// verify';
    for my $row (@$testdata) {
        my ($geohex) = @$row;
        push @src => qq{ok(geohex_verify_code("$geohex") == GEOHEX3_VERIFY_RESULT_SUCCESS);};
    }
    push @src => '';

    push @src => '// code2hex';
    for my $row (@$testdata) {
        my ($geohex, $lat, $lng) = @$row;
        push @src =>_generate_location_is(qq{geohex_get_zone_by_code("$geohex").location}, $lat, $lng, "$geohex: lat:$lat,lng:$lng");
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

    push @src => '// verify';
    for my $row (@$testdata) {
        my ($geohex) = @$row;
        push @src => qq{ok(geohex_verify_code("$geohex") == GEOHEX3_VERIFY_RESULT_SUCCESS);};
    }
    push @src => '';

    push @src => '// code2xy';
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

    push @src => '// verify';
    for my $row (@$testdata) {
        my (undef, undef, undef, $geohex) = @$row;
        push @src => qq{ok(geohex_verify_code("$geohex") == GEOHEX3_VERIFY_RESULT_SUCCESS);};
    }
    push @src => '';

    push @src => '// coord2hex';
    for my $row (@$testdata) {
        my ($level, $lat, $lng, $geohex) = @$row;
        $lat = '-0.00001' if $lat == 0 && $lng == -60.46875; ## XXX: work around (SEE ALSO: https://gist.github.com/karupanerura/f0dc5485de85c4c0f74e0
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
        $lat = '-0.00001' if $lat == 0 && $lng == -60.46875; ## XXX: work around (SEE ALSO: https://gist.github.com/karupanerura/f0dc5485de85c4c0f74e0
        push @src => qq{coordinate_is(geohex_get_coordinate_by_location(geohex_location(${lat}L, ${lng}L), $level), geohex_coordinate(${x}L, ${y}L), "lat:$lat,lng:$lng,level:$level: x:$x,y:$y");};
    }

    return sprintf <<'EOD', join "\n  ", @src;
void coord2xy (void) {
  %s
}
EOD
}

sub gen_code2coords {
    my $testdata = shift;

    my @src;

    push @src => '// verify';
    for my $row (@$testdata) {
        my ($geohex) = @$row;
        push @src => qq{ok(geohex_verify_code("$geohex") == GEOHEX3_VERIFY_RESULT_SUCCESS);};
    }
    push @src => '';

    push @src => '// code2coords';
    for my $row (@$testdata) {
        my ($geohex, $middle_left, $bottom_left, $bottom_right, $middle_right, $top_right, $top_left) = @$row;
        push @src => '{';
        push @src => qq{  note("geohex: $geohex");};
        push @src => qq{  geohex_t zone = geohex_get_zone_by_code("$geohex");};
        push @src => qq{  geohex_polygon_t polygon = geohex_get_hex_polygon(&zone);};
        push @src =>  q{  }._generate_location_is('polygon.top.right',    $top_right->[0], $top_right->[1],       "top.right");
        push @src =>  q{  }._generate_location_is('polygon.top.left',     $top_left->[0], $top_left->[1],         "top.left");
        push @src =>  q{  }._generate_location_is('polygon.middle.right', $middle_right->[0], $middle_right->[1], "middle.right");
        push @src =>  q{  }._generate_location_is('polygon.middle.left',  $middle_left->[0], $middle_left->[1],   "middle.left");
        push @src =>  q{  }._generate_location_is('polygon.bottom.right', $bottom_right->[0], $bottom_right->[1], "bottom.right");
        push @src =>  q{  }._generate_location_is('polygon.bottom.left',  $bottom_left->[0], $bottom_left->[1],   "bottom.left");
        push @src => '}';
    }

    return sprintf <<'EOD', join "\n  ", @src;
void code2coords (void) {
  %s
}
EOD
}

sub _generate_location_is {
    my ($expr, $lat, $lng, $msg) = @_;
    $lat .= '.0' if $lat !~ m/\./o;
    $lng .= '.0' if $lng !~ m/\./o;
    return qq{location_is(${expr}, geohex_location(${lat}L, ${lng}L), "$msg");};
}
