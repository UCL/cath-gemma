package Time::Seconds;

=head1 NAME

Time::Seconds - Append a TO_JSON method to the standard Time::Seconds package

See t/encode_json.t for an example use

=cut

=head2 TO_JSON

Return a simple string describing the Time::Seconds object (eg '25.536213s').

This isn't currently written with the hope of parsing that string back to a Time::Seconds object.

=cut

sub TO_JSON { my $time = shift; return $time . 's'; }

package main;

1;
