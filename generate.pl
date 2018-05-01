#!/usr/bin/perl

use strict;
use warnings;
use Config::General;
use Getopt::Long;

my (@BASE64) = ("A" .. "Z", "a" .. "z", "0" .. "9", "-", "_");

sub append_str {
    my ($ptr)    = shift;
    my ($source) = shift;

    $$ptr .= " " if (length($$ptr));
    $$ptr .= $source;
}

sub append_bits {
    my ($ptr)    = shift;
    my ($source) = shift;
    my ($num)    = shift;

    $$ptr .= " " if (length($$ptr));
    $$ptr .= sprintf("%0" . $num . "b", $source);
}

sub to_base64 {
    my ($source) = shift;
    my ($out);

    # First, remove all cosmetic spaces
    $source =~ s/\s//g;

    # Pad to a multiple of bytes, then to a multiple of 6 bits
    my ($remainder);

    $remainder = length($source) % 8;
    $source .= "0" x (8 - $remainder) if ($remainder);

    $remainder = length($source) % 6;
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

sub main {
    my ($config) = shift;

    # Generate the binary value in string form
    my ($binary);

    # Header
    append_bits(\$binary, $config->{header}{ver},            6);
    append_bits(\$binary, $config->{header}{created},       36);
    append_bits(\$binary, $config->{header}{updated},       36);
    append_bits(\$binary, $config->{header}{cmp_id},        12);
    append_bits(\$binary, $config->{header}{cmp_ver},       12);
    append_bits(\$binary, $config->{header}{screen},         6);

    # Language
    my $language = $config->{header}{language};
    $language =~ s/(.)/&to_binary($1, @BASE64)/ge;

    # Remainder of the header
    append_str(\$binary, $language);
    append_bits(\$binary, $config->{header}{vendor_ver},    12);

    # Purposes
    my $purposes_binary = "0" x 24;
    foreach my $purpose (keys %{ $config->{consent}{purposes} }) {
        next if $purpose >= length($purposes_binary);
        substr($purposes_binary, $purpose - 1, 1) = "1" if ($config->{consent}{purposes}{$purpose});
    }
    append_str(\$binary, $purposes_binary);

    # Vendors
    append_bits(\$binary, $config->{header}{max_vendor_id}, 16);
    append_bits(\$binary, $config->{header}{encoding_type},  1);

    if ($config->{header}{encoding_type}) {
        # Ranges
        my $default_consent = $config->{consent}{default_consent};

        # First pass to build lists
        my $last_vendor_id;
        my %ranges;
        foreach my $vendor (sort keys %{ $config->{consent}{vendors} }) {
            next if ($config->{consent}{vendors}{$vendor} == $default_consent);

            if ($last_vendor_id && $vendor == $last_vendor_id + $ranges{$last_vendor_id} + 1) {
                $ranges{$last_vendor_id}++;
            }
            else {
                $last_vendor_id = $vendor;
                $ranges{$last_vendor_id} = 0;
            }
        }

        # Second pass to write the ranges
        append_bits(\$binary, $default_consent,     1);
        append_bits(\$binary, scalar keys %ranges, 12);

        foreach my $range (sort keys %ranges) {
            if ($ranges{$range}) {
                # Multi-vendor range
                append_bits(\$binary, 1, 1);
                append_bits(\$binary, $range, 16);
                append_bits(\$binary, $range + $ranges{$range}, 16);
            }
            else {
                # Single vendor
                append_bits(\$binary, 0, 1);
                append_bits(\$binary, $range, 16);
            }
        }
    }
    else {
        # Bit field
        my $vendors_binary = "0" x $config->{header}{max_vendor_id};
        foreach my $vendor_id (keys %{ $config->{consent}{vendors} }) {
            next if $vendor_id >= length($vendors_binary);
            substr($vendors_binary, $vendor_id - 1, 1) = "1" if ($config->{consent}{vendors}{$vendor_id});
        }
        append_str(\$binary, $vendors_binary);
    }

    # Convert to base64url
    printf "%s\n", to_base64($binary);
}

my ($in) = {
    header => {
        ver           => 0,
        created       => 0,
        updated       => 0,
        cmp_id        => 0,
        cmp_ver       => 0,
        screen        => 0,
        language      => "EN",
        vendor_ver    => 0,
        max_vendor_id => 0,
        encoding_type => 0,
    },
    consent => {
        default_consent => 0,
        purposes => { },
        vendors  => { },
    }
};

my ($success) = GetOptions(
    'conf=s'            => \my $config_filename,
    'ver=i'             => \my $ver,
    'created=i'         => \my $created,
    'updated=i'         => \my $updated,
    'cmp-id=i'          => \my $cmp_id,
    'cmp-ver=i'         => \my $cmp_ver,
    'screen=i'          => \my $screen,
    'language=s'        => \my $language,
    'vendor-ver=i'      => \my $vendor_ver,
    'max-vendor-id=i'   => \my $max_vendor_id,
    'encoding-type=i'   => \my $encoding_type,
    'default-consent=i' => \my $default_consent,
    'purpose=s'         => \my %purposes,
    'vendor=s'          => \my %vendors,
);

# Load a baseline configuration, if specified
if ($config_filename) {
    my $config = new Config::General(
        -ConfigFile            => $config_filename,
        -MergeDuplicateBlocks  => 1,
        -MergeDuplicateOptions => 1,
        -DefaultConfig         => $in,
    );
    my %hash = $config->getall();
    $in = \%hash;
}

# Merge in command-line options
$in->{header}{ver}              = $ver                     if (defined($ver));
$in->{header}{created}          = $created                 if (defined($created));
$in->{header}{updated}          = $updated                 if (defined($updated));
$in->{header}{cmp_id}           = $cmp_id                  if (defined($cmp_id));
$in->{header}{cmp_ver}          = $cmp_ver                 if (defined($cmp_ver));
$in->{header}{screen}           = $screen                  if (defined($screen));
$in->{header}{language}         = $language                if (defined($language) && length($language) == 2);
$in->{header}{vendor_ver}       = $vendor_ver              if (defined($vendor_ver));
$in->{header}{max_vendor_id}    = $max_vendor_id           if (defined($max_vendor_id));
$in->{header}{encoding_type}    = ($encoding_type) ? 1 : 0 if (defined($encoding_type));
$in->{consent}{default_consent} = $default_consent ? 1 : 0 if (defined($default_consent));
$in->{consent}{purposes}{$_}    = $purposes{$_}    ? 1 : 0 foreach (keys %purposes);
$in->{consent}{vendors}{$_}     = $vendors{$_}     ? 1 : 0 foreach (keys %vendors);

main($in);

