# GDPR Consent String Utilities

## Pre-requisites

These two utilities are written in Perl, and rely on the language version 5.10 or later. In addition, the script `generate.pl` requires the following CPAN libraries:
- `Config::General`;
- `Getopt::Long`.

## Generation

The script `generate.pl` is used to create a consent string. It has two primary modes of usage, from a configuration file or from command-line settings. The two can be used in combination -- the command-line settings override the configuration file.

To generate the string from a configuration file:
```
./generate.pl --conf demo.conf
```
To generate the string from command-line settings:
```
./generate.pl --ver=1 --created=15100821554 --updated=15100821554 --cmp-id=7 --cmp-ver=1 --screen=3 --language=EN --vendor-ver=8 --max-vendor-id=2011 --encoding-type=1 --purpose 1=1 --purpose 2=1 --purpose 3=1 --default-consent=1 --vendor 9=0
```

## Parsing

The script `parse.pl` is used to interpret a consent string. It is used with a single argument, as follows:
```
./parse.pl BOEFEAyOEFEAyAHABDENAI4AAAB9vABAASA
```
