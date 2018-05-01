#!/usr/bin/perl

use strict;
use warnings;
use bigint;

my (@BASE64) = ("A" .. "Z", "a" .. "z", "0" .. "9", "-", "_");

sub extract_bits {
    my ($label)  = shift;
    my ($ptr)    = shift;
    my ($target) = shift;
    my ($num)    = shift;

    my $bits = substr($$ptr, 0, $num);
    $$ptr    = substr($$ptr, $num);
    $$target = to_decimal($bits);

    if (defined($label)) {
        printf "%-17s%s (%d)\n", "$label:", $bits, $$target;
    }
}

sub extract_str {
    my ($label)  = shift;
    my ($ptr)    = shift;
    my ($target) = shift;
    my ($num)    = shift;

    my $bits = substr($$ptr, 0, $num);
    $$ptr    = substr($$ptr, $num);
    $$target = to_base64($bits);

    printf "%-17s%s (%s)\n", "$label:", $bits, $$target;
}

sub to_base64 {
    my ($source) = shift;
    my ($out);

    # First, remove all cosmetic spaces
    $source =~ s/\s//g;

    # Pad to a multiple of 6 bits
    my ($remainder) = length($source) % 6;
    $source .= "0" x (6 - $remainder) if ($remainder);

    # Iterate over the string
    while (length($source)) {
        # Encode the first 6 bits
        my ($bc) = substr($source, 0, 6);
        $out .= $BASE64[ oct("0b" . $bc) ];

        # Advance to the next block
        $source = substr($source, 6);
    }

    return $out;
}

sub find_in {
    my ($element) = shift;
    my (@source)  = @_;

    my $index;
    for ($index = 0; $index < scalar @source; $index++) {
        last if ($source[$index] eq $element);
    }

    return $index;
}

sub to_binary {
    my ($element) = shift;
    my (@source)  = @_;

    return sprintf("%06b", find_in($element, @source));
}

sub to_decimal {
    my ($element) = shift;

    return oct("0b" . $element);
}

sub main {
    my ($in) = shift;

    # Generate the binary value in string form
    my ($binary);

    # Decode
    $binary = $in;
    $binary =~ s/(.)/&to_binary($1, @BASE64)/ge;

    # Header
    extract_bits("Version",        \$binary, \my $ver,            6);
    extract_bits("Created",        \$binary, \my $created,       36);
    extract_bits("Updated",        \$binary, \my $updated,       36);
    extract_bits("CMP ID",         \$binary, \my $cmp_id,        12);
    extract_bits("CMP Version",    \$binary, \my $cmp_ver,       12);
    extract_bits("Screen",         \$binary, \my $screen,         6);
    extract_str("Language",        \$binary, \my $language,      12);
    extract_bits("Vendor Version", \$binary, \my $vendor_ver,    12);
    extract_bits("Purposes",       \$binary, \my $purposes,      24);
    extract_bits("Max Vendor ID",  \$binary, \my $max_vendor_id, 16);
    extract_bits("Encoding Type",  \$binary, \my $encoding_type,  1);

    my $default_consent;

    if ($encoding_type) {
        # Ranges -- convert to bit field
        extract_bits("Default Consent", \$binary, \$default_consent, 1);

        my $bitfield = "$default_consent" x $max_vendor_id;
        my $override_consent = "" . (1 - $default_consent);

        while (length($binary) >= 6) {
            extract_bits("Num Ranges", \$binary, \my $num_ranges, 12);

            for (my $i = 0; $i < $num_ranges; $i++) {
                my $vendor_start;
                my $vendor_end;

                extract_bits("Is Range", \$binary, \my $is_range, 1);

                if ($is_range) {
                    extract_bits("Vendor Start", \$binary, \$vendor_start, 16);
                    extract_bits("Vendor End",   \$binary, \$vendor_end,   16);
                }
                else {
                    extract_bits("Single Vendor", \$binary, \$vendor_start, 16);
                    $vendor_end = $vendor_start;
                }

                substr($bitfield, $vendor_start - 1, $vendor_end - $vendor_start + 1) = $override_consent;
            }
        }

        $binary = $bitfield;
    }
    else {
        $default_consent = 0;
    }

    # Bit field
    my $vendor_id = 0;
    my $vendor_consent;
    while (length($binary) && $vendor_id < $max_vendor_id) {
        ++$vendor_id;
        extract_bits(undef, \$binary, \$vendor_consent, 1);

        # Only print the exceptions to the default
        if ($vendor_consent != $default_consent) {
            printf "%-17s%s\n", "Vendor $vendor_id:", $vendor_consent;
        }
    }
}

die "usage $0 <consent_string>\n" if (scalar @ARGV < 1);

main($ARGV[0]);

