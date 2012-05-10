=head1 NAME

AnyEvent::ReadLine::Gnu - event-based interface to Term::ReadLine::Gnu

=head1 SYNOPSIS

 use AnyEvent::ReadLine::Gnu;

 # works always, prints message to stdout
 AnyEvent::ReadLine::Gnu->print ("message\n");

 # now initialise readline
 my $rl = new AnyEvent::ReadLine::Gnu prompt => "hi> ", cb => sub {
    # called for each line entered by the user
    AnyEvent::ReadLine::Gnu->print ("you entered: $_[0]\n");
 };

 # asynchronously print something
 my $t = AE::timer 1, 1, sub {
    $rl->hide;
    print "async message 1\n"; # mind the \n
    $rl->show;

    # the same, but shorter:
    $rl->print ("async message 2\n");
 };

 # do other eventy stuff...
 AE::cv->recv;

=head1 DESCRIPTION

The L<Term::ReadLine> module family is bizarre (and you are encouraged not
to look at its sources unless you want to go blind). It does support
event-based operations, somehow, but it's hard to figure out.

It also has some utility functions for printing messages asynchronously,
something that, again, isn't obvious how to do.

This module has figured it all out for you, once and for all.

=over 4

=cut

package AnyEvent::ReadLine::Gnu;

use common::sense;
use AnyEvent;

BEGIN {
   # we try our best
   local $ENV{PERL_RL} = "Gnu";

   require Term::ReadLine;
   require Term::ReadLine::Gnu;
}

use base Term::ReadLine::;

our $VERSION = '0.1';

=item $rl = new AnyEvent::ReadLine::Gnu key => value...

Creates a new AnyEvent::ReadLine object.

Actually, it only configures readline and provides a convenient way to
call the show and hide methods, as well as readline methods - this is a
singleton.

The returned object is the standard L<Term::ReadLine::Gnu> object, all
methods that are documented (or working) for that module should work on
this object.

Once initialised, this module will also restore the terminal settings on a
normal program exit.

The following key-value pairs are supported:

=over 4

=item on_line => $cb->($string)

The only mandatory parameter - passes the callback that will receive lines
that are completed by the user.

=item prompt => $string

The prompt string to use, defaults to C<< >  >>.

=item name => $string

The readline application name, defaults to C<$0>.

=item in => $glob

The input filehandle (should be a glob): defaults to C<*STDIN>.

=item out => $glob

The output filehandle (should be a glob): defaults to C<*STDOUT>.

=back

=cut

our $self;
our $prompt;
our $cb;
our $hidden;
our $rw;
our ($in, $out);

our $saved_point;
our $saved_line;

sub new {
   my ($class, %arg) = @_;

   $in     = $arg{in}  || *STDIN;
   $out    = $arg{out} || *STDOUT;
   $prompt = $arg{prompt} || "> ";
   $cb     = $arg{on_line};

   $self = $class->SUPER::new ($arg{name} || $0, $in, $out);

   $self->CallbackHandlerInstall ($prompt, $cb);
   # set the unadorned prompt
   $self->rl_set_prompt ($prompt);

   $hidden = 1;
   $self->show;

   $self
}

=item $rl->hide

=item AnyEvent::ReadLine::Gnu->hide

These methods I<hide> the readline prompt and text. Basically, it removes
the readline feedback from your terminal.

It is safe to call even when AnyEvent::ReadLine::Gnu has not yet been
initialised.

This is immensely useful in an event-based program when you want to output
some stuff to the terminal without disturbing the prompt - just C<hide>
readline, output your thing, then C<show> it again.

Since user input will not be processed while readline is hidden, you
should call C<show> as soon as possible.

=cut

sub hide {
   return if !$self || $hidden++;

   undef $rw;

   $saved_point = $self->{point};
   $saved_line  = $self->{line_buffer};

   $self->rl_set_prompt ("");
   $self->{line_buffer} = "";
   $self->rl_redisplay;
}

=item $rl->show

=item AnyEvent::ReadLine::Gnu->show

Undos any hiding. Every call to C<hide> has to be followed to a call to
C<show>. The last call will redisplay the readline prompt, current input
line and cursor position. Keys entered while the prompt was hidden will be
processed again.

=cut

sub show {
   return if !$self || --$hidden;

   if (defined $saved_point) {
      $self->rl_set_prompt ($prompt);
      $self->{line_buffer} = $saved_line;
      $self->{point}       = $saved_point;
      $self->redisplay;
   }

   $rw = AE::io $in, 0, sub {
      $self->rl_callback_read_char;
   };
}

=item $rl->print ($string, ...)

=item AnyEvent::ReadLine::Gnu->print ($string, ...)

Prints the given strings to the terminal, by first hiding the readline,
printing the message, and showing it again.

This function cna be called even when readline has never been initialised.

The last string should end with a newline.

=cut

sub print {
   shift;

   hide;
   my $out = $out || *STDOUT;
   print $out @_;
   show;
}

END {
   return unless $self;

   $self->hide;
   $self->callback_handler_remove;
}

1;

=back

=head1 AUTHOR, CONTACT, SUPPORT

 Marc Lehmann <schmorp@schmorp.de>
 http://software.schmorp.de/pkg/AnyEvent-Readline-Gnu.html

=cut

