package AnyJob::Constants::Crontab;

###############################################################################
# Constants used for crontab-based scheduling.
#
# Author:       LightStar
# Created:      25.01.2019
# Last update:  25.01.2019
#

use strict;
use warnings;
use utf8;

use base 'Exporter';

###############################################################################
# Total number of space-separated items in crontab specification string.
#
use constant CRONTAB_SETS_COUNT => 5;

###############################################################################
# Last module name part of minutes set class.
#
use constant CRONTAB_MINUTE_SET => 'Minute';

###############################################################################
# Index of minutes among space-separated items in crontab specification string.
#
use constant CRONTAB_MINUTE_INDEX => 0;

###############################################################################
# Total range of minutes.
#
use constant CRONTAB_MINUTE_RANGE => [ 0 .. 59 ];

###############################################################################
# Last module name part of hours set class.
#
use constant CRONTAB_HOUR_SET => 'Hour';

###############################################################################
# Index of hours among space-separated items in crontab specification string.
#
use constant CRONTAB_HOUR_INDEX => 1;

###############################################################################
# Total range of hours.
#
use constant CRONTAB_HOUR_RANGE => [ 0 .. 23 ];

###############################################################################
# Last module name part of month days set class.
#
use constant CRONTAB_DAY_SET => 'Day';

###############################################################################
# Index of days of month among space-separated items in crontab specification string.
#
use constant CRONTAB_DAY_INDEX => 2;

###############################################################################
# Default max day number used in month days set class.
#
use constant CRONTAB_DEFAULT_MAX_DAY => 31;

###############################################################################
# Total ranges of days of month. There are 3 variants dependent on month.
#
use constant CRONTAB_DAY_RANGES => {
    29 => [ 1 .. 29 ],
    30 => [ 1 .. 30 ],
    31 => [ 1 .. 31 ]
};

###############################################################################
# Last module name part of months set class.
#
use constant CRONTAB_MONTH_SET => 'Month';

###############################################################################
# Index of months among space-separated items in crontab specification string.
#
use constant CRONTAB_MONTH_INDEX => 3;

###############################################################################
# Total range of months.
#
use constant CRONTAB_MONTH_RANGE => [ 1 .. 12 ];

###############################################################################
# Mapper function used to map month names to their corresponding values.
#
use constant CRONTAB_MONTH_MAPPER => sub {
    {
        jan => 1,
        feb => 2,
        mar => 3,
        apr => 4,
        may => 5,
        jun => 6,
        jul => 7,
        aug => 8,
        sep => 9,
        oct => 10,
        nov => 11,
        dec => 12
    }->{lc($_[0])} || $_[0];
};

###############################################################################
# Last module name part of week days set class.
#
use constant CRONTAB_WEEKDAY_SET => 'WeekDay';

###############################################################################
# Index of week days among space-separated items in crontab specification string.
#
use constant CRONTAB_WEEKDAY_INDEX => 4;

###############################################################################
# Total range of week days.
#
use constant CRONTAB_WEEKDAY_RANGE => [ 1 .. 7 ];

###############################################################################
# Mapper function used to map week day names to their corresponding values.
# Also number '0' is mapped to '1' for compatibility purposes.
#
use constant CRONTAB_WEEKDAY_MAPPER => sub {
    {
        0   => 1,
        mon => 1,
        tue => 2,
        web => 3,
        thu => 4,
        fri => 5,
        sat => 6,
        sun => 7
    }->{lc($_[0])} || $_[0];
};

our @EXPORT = qw(
    CRONTAB_SETS_COUNT
    CRONTAB_MINUTE_SET
    CRONTAB_MINUTE_INDEX
    CRONTAB_MINUTE_RANGE
    CRONTAB_HOUR_SET
    CRONTAB_HOUR_INDEX
    CRONTAB_HOUR_RANGE
    CRONTAB_DAY_SET
    CRONTAB_DAY_INDEX
    CRONTAB_DEFAULT_MAX_DAY
    CRONTAB_DAY_RANGES
    CRONTAB_MONTH_SET
    CRONTAB_MONTH_INDEX
    CRONTAB_MONTH_RANGE
    CRONTAB_MONTH_MAPPER
    CRONTAB_WEEKDAY_SET
    CRONTAB_WEEKDAY_INDEX
    CRONTAB_WEEKDAY_RANGE
    CRONTAB_WEEKDAY_MAPPER
    mapCrontabSetNamesToRange
);

1;
