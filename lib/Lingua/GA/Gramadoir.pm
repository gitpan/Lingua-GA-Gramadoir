package Lingua::GA::Gramadoir;

use 5.008;
use strict;
use warnings;

use Carp;
use File::Spec;
use Storable;
use Memoize;
use Encode qw(decode from_to);
use String::Approx qw(amatch adist);
use Lingua::GA::Gramadoir::Languages;

our $VERSION = '0.50';
use vars qw(@FOCAIL %EILE %EARRAIDI %NOCOMBO %POS %GRAMS %IGNORE $lh);

memoize('tag_one_word', TIE => [ 'Memoize::ExpireLRU',
				CACHESIZE => 5000,
				]);

=head1 NAME

Lingua::GA::Gramadoir - Check the grammar of Irish language text

=head1 SYNOPSIS

  use Lingua::GA::Gramadoir;

  my $gr = new Lingua::GA::Gramadoir;

  my $errors = $gr->grammatical_errors( $text );
  foreach my $error (@$errors) {
  	# process $error appropriately
  }

=head1 DESCRIPTION

This module contains the code for segmentation, spell checking,
part-of-speech tagging, and grammar checking used by "An GramadE<oacute>ir",
an open-source grammar and style checker that can be used
with vim, emacs, OpenOffice, or through a command-line interface.
An GramadE<oacute>ir is intended as a platform for the development of 
sophisticated natural language processing tools for languages with
limited computational resources.

The Perl code contained in this module is generated automatically
from a higher-level representation of the grammatical rules
and should not be edited directly.  Anyone interested in helping
improve the lexicon or the rule sets should download the 
developers' pack from the An GramadE<oacute>ir web site:
L<http://borel.slu.edu/gramadoir/>.

=head1 CONSTRUCTOR

=over 4

=item new %PARAMS

Constructs an instance of the grammar checker and loads the lexicon
into memory.  It should only be called once.   Options may be specified
by passing a hash containing any of the following keys:

fix_spelling => 0

Suggest replacements for misspelled or unknown words.

use_ignore_file => 0

Read a file containing words to be ignored when checking spelling and grammar.

interface_language => ""

Specify the language of output messages
(B<not> necessarily the language of the text to be checked).
With the default value, Locale::Maketext attempts to determine
the correct language to use based on things like your
environment variables.

input_encoding => 'ISO-8859-1'

Specify the encoding for all texts passed to one of the module's exported
functions.   There is no currently no way to change the encoding of
the data returned by the exported functions (always encoded as perl strings).

=back

=cut

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $self = {
			fix_spelling => 0,
			use_ignore_file => 0,
			interface_language => '',
			input_encoding => 'ISO-8859-1',
			@_,
	};

	( my $datapath ) = __FILE__ =~ /(.*)\.pm/;
	%EILE = %{ retrieve( File::Spec->catfile( $datapath, 'eile.hash' ) )};
	%EARRAIDI = %{ retrieve( File::Spec->catfile( $datapath, 'earraidi.hash' ) ) };
	%NOCOMBO = %{ retrieve( File::Spec->catfile( $datapath, 'nocombo.hash' ) )};
	%POS = %{ retrieve( File::Spec->catfile( $datapath, 'pos.hash' ) ) };
	%GRAMS = %{ retrieve(File::Spec->catfile($datapath, '3grams.hash') ) };
	for my $i (0 .. 6) {
		push @FOCAIL, retrieve( File::Spec->catfile( $datapath, "focail$i.hash" ) );
	}

	if ($self->{'use_ignore_file'}) {
		my $homedir = $ENV{HOME} || $ENV{LOGDIR}; # || (getpwuid($>))[7];
		if (open (DATAFILE, File::Spec->catfile( $homedir, '.neamhshuim' ))) {
			while (<DATAFILE>) {
				chomp;
				$IGNORE{$_}++;
			}
		}
	}

	if ($self->{'interface_language'}) {
		$lh = Lingua::GA::Gramadoir::Languages->get_handle($self->{'interface_language'});
	}
	else {
		$lh = Lingua::GA::Gramadoir::Languages->get_handle();
	}
	croak 'Could not set interface language' unless $lh;

	return bless $self, $class;
}

sub gettext
{
	my $string = shift;
	my $arg = shift;

	$string =~ s/\[/~[/g;
	$string =~ s/\]/~]/g;
	$string =~ s/\%s/[_1]/;
	$string =~ s#\\/([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]+)\\/#/$1/#;
	$string =~ s#\\/\\([1-9])\\/#/[_$1]/#;

	return $lh->maketext($string, $arg);
}

##############################################################################

=head1 METHODS

=over

=item get_sentences TEXT

Splits the input TEXT up into sentences and returns a reference to an
array containing the sentences.

=cut

##############################################################################

# approximates "abairti" from bash version
# General philosophy is that it is *not* the job of the grammar checker
# to filter incoming texts (of, say, TeX or SGML markup).  On the other hand,
# SGML-like markup *must* be stripped so it doesn't interfere with
# the real work of the grammar checker.
sub get_sentences
{
	my ( $self, $text ) = @_;
	from_to($text, $self->{'input_encoding'}, 'ISO-8859-1');
	my $answer = get_sentences_real($text);
	foreach my $s (@$answer) {
		$s = decode('ISO-8859-1', $s);
	}
	return $answer;
}

sub get_sentences_real
{
	my $BD="\001";
	my $sentences;

	for ($_[0]) {
		s/<[^>]*>/ /g;  # naive; see comments above
		s/&/&amp;/g;    # this one first!
		s/</&lt;/g;
		s/>/&gt;/g;
		s/[\\$BD]//g;
		giorr ( $_ );
		s/([^\\][.?!][]"')}]*)[ \t\n]+/$1$BD/g;
		s/"/&quot;/g;   # &apos; ok  (note " in prev line)
		s/\s+/ /g;
		tr/\\//d;
		@$sentences = split /$BD/;
	}

	return $sentences;
}

# two arguments; first is word to be tagged, 2nd is string of grammatical bytes
sub add_grammar_tags
{
	my ( $self, $word, $grambytes ) = @_;

	my $ans;
	if ( length( $grambytes ) == 1) {
		my $tag = $POS{ord($grambytes)};
		$tag =~ m/^<([A-Z])/;
		$ans = $tag.$word."</".$1.">";
	}
	else {
		$ans = "<B><Z>";
		foreach my $byte (split //, $grambytes) {
			my $tag = $POS{ord($byte)};
			$tag =~ s/>$/\/>/;
			$ans = $ans.$tag;
		}
		$ans = $ans."</Z>".$word."</B>";
	}

	return $ans;
}

sub mylc {
	my ($string) = @_;
	$string =~ tr/A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}/a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}/;
	return $string;
}

sub mylcfirst {
	my ($string) = @_;
	$string =~ s/^(.)(.*)$/mylc($1).$2/e;
	return $string;
}

# look up in the hash tables FOCAIL, EILE, EARRAIDI consecutively
# same arguments, return conventions as tag_recurse, just no recursion!
sub lookup
{
	my ( $self, $original, $current, $level ) = @_;

	my $ans;
	for my $href ( @FOCAIL ) {
		if ( exists($href->{$current}) ) {
			if ( $level == -1 ) {
				my $codez = $href->{$current};
				my %tempseen;
				if ( $current =~ m/^[A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]/ ) {
					my $lower = mylcfirst($current);
					if ( exists($href->{$lower}) ) {
						foreach my $bee (split //, $href->{$current}.$href->{$lower}) {
							$tempseen{$bee}++;
						}
						$codez = join('', sort(keys %tempseen));
						if ( length( $codez ) > 1 ) {
							$codez =~ s/\177//;
						}
					}
				}
				$ans = $self->add_grammar_tags($original, $codez);
			}
			elsif ( $level == 0 ) {
				$ans = "<E msg=\"MOIRF{$current}\"><X>".$original."</X></E>";
			}
			elsif ( $level == 1 ) {
				$ans = "<E msg=\"CAIGHDEAN{$current}\"><X>".$original."</X></E>";
			}
			else {
				$ans = "<E msg=\"DROCHMHOIRF{$current}\"><X>".$original."</X></E>";
			}
			return $ans;
		}
	}
	if ( exists($EILE{$current}) ) {
		my $correction = $EILE{$current};
		if ( $level == -1 ) {
			$ans = "<E msg=\"CAIGHDEAN{$correction}\"><X>".$original."</X></E>";
		}
		elsif ( $level == 0 ) {
			$ans = "<E msg=\"CAIGHMOIRF{$correction}\"><X>".$original."</X></E>";
		}
		elsif ( $level == 1 ) {
			$ans = "<E msg=\"CAIGHDEAN{$current ($correction)}\"><X>".$original."</X></E>";
		}
		else {
			$ans = "<E msg=\"DROCHMHOIRF{$current ($correction)}\"><X>".$original."</X></E>";
		}
		return $ans;
	}
	if ( exists($EARRAIDI{$current}) ) {
		my $correction = $EARRAIDI{$current};
		if ( $level == -1 ) {
			$ans = "<E msg=\"MICHEART{$correction}\"><X>".$original."</X></E>";
		}
		else {
			$ans = "<E msg=\"MIMHOIRF{$current ($correction)}\"><X>".$original."</X></E>";
		}
		return $ans;
	}
	return "";
}

# note use of "tag_recurse" on the conjectural pieces below; 
# this is (primarily) to deal with capitalization of the halves.
# definitely *don't* want to call full tag on the two pieces or
# else *this* function will recurse 
sub tag_as_compound
{
	my ( $self, $word ) = @_;
	if ($self->{'fix_spelling'}) {
		if ($word =~ m/^([^-]+)-(.*)$/) {
			my $l = $1;
			my $r = $2;
			my $t1 = $self->tag_recurse( $l, $l, -1 );
			my $t2 = $self->tag_recurse( $r, $r, -1 );
			if ($t1 && $t2) {
				if ($t1 !~ m/<E/ && $t2 !~ m/<E/) {
					return "<E msg=\"COMHFHOCAL{$l+$r}\"><X>".$word."</X></E>";
				}
				else {
					return "<E msg=\"COMHCHAIGH{$l+$r}\"><X>".$word."</X></E>";
				}
			}
		}
		else {
			my $len = length($word);
			for (my $i = 3; $i < $len-2; $i++) { # i=len of left
				my $l = substr($word, 0, $i);
				my $r = substr($word, $i, $len - $i);
				if (!exists($NOCOMBO{$l}) &&
				    !exists($NOCOMBO{$r})) {
					my $tl = $self->tag_recurse($l,$l,-1);
					my $tr = $self->tag_recurse($r,$r,-1);
				    	if ( $tl && $tr ) {
						if ($tl !~ m/<E/ && $tr !~ m/<E/) {
							return "<E msg=\"COMHFHOCAL{$l+$r}\"><X>".$word."</X></E>";
						}
						else {
							return "<E msg=\"COMHCHAIGH{$l+$r}\"><X>".$word."</X></E>";
						}
					}
				}
			}
		}
	}
	return "";
}

sub tag_as_near_miss
{
	my ( $self, $word ) = @_;

	if ($self->{'fix_spelling'}) {
		my $wordlen = length($word);
		if ($wordlen > 2) {
			for my $href ( @FOCAIL ) {
				my %matches;
				my $dist = "1";
				if ($word =~ m/[A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]/) {
					$dist =~ s/$/ i/;
				}
				for (my $i = 0; $i < $wordlen-1; $i++) {
					my $perm = $word;
					$perm =~ s/(.{$i})(.)(.)/$1$3$2/;
					$matches{$perm}++ if (exists($href->{$perm}));
				}
				for (amatch($word, [ $dist, "I0S0" ], (keys %$href))) {
					$matches{$_}++ if (length($_)==$wordlen-1);
				}
				for (amatch($word, [ $dist, "D0S0" ], (keys %$href))) {
					$matches{$_}++ if (length($_)==$wordlen+1);
				}
				for (amatch($word, [ $dist, "D0I0" ], (keys %$href))) {
					$matches{$_}++ if (length($_)==$wordlen);
				}
				my $suggs = join(', ', (keys %matches));
				return "<E msg=\"ANAITHNID /$suggs/?\"><X>$word</X></E>" if $suggs;
			}
		}
	}
	return "";
}

sub find_bad_three_grams
{
	my ( $self, $word ) = @_;

	$word =~ s/^/</;
	$word =~ s/$/>/;
	my $end = length($word) - 2;
	for (my $i = 0; $i < $end; $i++) {
		my $cand = substr($word, $i, 3);
		if (!exists($GRAMS{$cand})) {
			$cand =~ tr/<>/^$/;
			$word =~ tr/<>//d;
			return "<E msg=\"GRAM{$cand}\"><X>$word</X></E>";
		}
	}
	return "";
}

# takes a single word as an argument and returns it tagged, without fail
# e.g. it will get something like <X>neamhword</X> if it is unknown
sub tag_one_word
{
	my ( $self, $word ) = @_;

	if ($self->{'use_ignore_file'}) {
		return "<Y>".$word."</Y>" if ( exists($IGNORE{$word}) );
	}
	my $ans = $self->tag_recurse($word, $word, -1);
	return $ans if $ans;
	$ans = $self->tag_as_near_miss($word);
	return $ans if $ans;
	$ans = $self->tag_as_compound($word);
	return $ans if $ans;
	$ans = $self->find_bad_three_grams($word);
	return $ans if $ans;
	return "<X>$word</X>";
}

# takes a sentence as input and returns the sentence with trivial markup
# around each token (in bash version this was part of abairti)
sub tokenize
{
	my ( $self, $sentence ) = @_;
	$sentence =~ s/([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]*)/<c>$1<\/c>/g;
	$sentence =~ s/(['-]+)<\/c>/<\/c>$1/g;
	$sentence =~ s/&<c>(quot|lt|gt|amp)<\/c>;/&$1;/g;
	return $sentence;
}

# takes the input TEXT and returns a reference to an array of sentences with 
# a preliminary XML markup consisting of all possible parts of speech
sub unchecked_xml
{
	my $self = $_[0];
	my $sentences = get_sentences_real($_[1]);
	my $answer;
	foreach my $sentence (@$sentences) {
		$sentence = $self->tokenize($sentence);
		$sentence =~ s/(<c>[^<]+<\/c>) \1/<E msg="DUBAILTE">$1 $1<\/E>/g;
		1 while ( $sentence =~ s/<c>([^<]*)<\/c>/$self->tag_one_word($1);/e );
		$sentence =~ s/^/<line> /;
		$sentence =~ s/$/ <\/line>/;
	}
	return $sentences;
}

##############################################################################

=item spell_check TEXT

Returns a reference to an array containing the misspelled words appearing
in the input text.

=cut

##############################################################################

sub spell_check
{
	my ( $self, $text ) = @_;
	from_to($text, $self->{'input_encoding'}, 'ISO-8859-1');
	my $sentences = $self->unchecked_xml($text);
	my $badwords;
	foreach my $s (@$sentences) {
		if ($s =~ m/<X>/) {
			$s =~ s/<[^X\/][^>]*>//g;
			$s =~ s/<\/[^X][^>]*>//g;
			$s =~ s/^[^<]*<X>//;
			$s =~ s/<\/X>[^<]*$//;
			$s =~ s/<\/X>[^<]*<X>/\n/g;
			$s = decode('ISO-8859-1', $s);
			push @$badwords,$s;
		}
	}
	return $badwords;
}


##############################################################################

=item add_tags TEXT

Takes the input TEXT and returns a reference to an array of sentences 
with (XML-style) *disambiguated* part-of-speech tags.  Does not do
any grammatical rule checking.

=cut

##############################################################################

sub add_tags
{
	my ( $self, $text ) = @_;
	from_to($text, $self->{'input_encoding'}, 'ISO-8859-1');
	my $answer = $self->add_tags_read($text);
	foreach my $s (@$answer) {
		$s = decode('ISO-8859-1', $s);
	}
	return $answer;
}

sub add_tags_real
{
	my $sentences = unchecked_xml(@_);
	foreach my $sentence (@$sentences) {
		comhshuite($sentence);
		aonchiall($sentence);
		aonchiall_deux($sentence);
		unigram($sentence);
	}
	return $sentences;
}


# Takes the input TEXT and returns a reference to an array of sentences
# containing full XML markup, including part of speech tags and marked
# up grammatical errors.   
# Called by grammatical_errors and xml_stream (the latter just adds an
# XML header/footer and dumps the array of sentences to a scalar).
sub xml_sentences
{
	my $sentences = add_tags_real(@_);
	foreach my $sentence (@$sentences) {
		rialacha ($sentence);
		eisceacht ($sentence);
	}
	return $sentences;
}

##############################################################################

=item xml_stream TEXT

Takes the input TEXT and returns it as well-formed XML (encoded as perl
strings, not utf-8) with full grammatical markup.   Error messages are not 
localized.  This function should only be exported for debugging/development
purposes.  Use "grammatical_errors" (which is basically "xml_stream" plus
some whittling down) as an interface with other programs.

=cut

##############################################################################
# bash version's vanilla_xml_output/aspell_xml_output
sub xml_stream
{
	my ( $self, $text ) = @_;
	from_to($text, $self->{'input_encoding'}, 'ISO-8859-1');
	my $answer='<?xml version="1.0" encoding="utf-8" standalone="no"?>';
	$answer = $answer."\n".'<!DOCTYPE teacs SYSTEM "/dtds/gramadoir.dtd">';
	$answer = $answer."\n<teacs>\n";
	my $sentences = $self->xml_sentences($text);
	$answer = $answer.join("\n", @$sentences);
	$answer = $answer."\n</teacs>\n";
	$answer = decode("ISO-8859-1", $answer);
	return $answer;
}

sub localize_me
{
	my ( $self, $msg ) = @_;

	my $msgid;
	for ($msg) {
		tr/_/ /;
		if (/ANAITHNID/) {
			$msgid = gettext('Unknown word');
			s/ANAITHNID/$msgid/;
		}
		if (/NEAMHCHOIT/) {
			$msgid = gettext('Valid word but extremely rare in actual usage');
			s/NEAMHCHOIT/$msgid/;
		}
		if (/INPHRASE{([^}]+)}/) {
			$msgid = gettext('Usually used in the set phrase \/\1\/', $1);
			s/INPHRASE{([^}]+)}/$msgid/;
		}
		if (/BACHOIR{([^}]+)}/) {
			$msgid = gettext('You should use \/\1\/ here instead', $1);
			s/BACHOIR{([^}]+)}/$msgid/;
		}
		if (/CAIGHDEAN{([^}]+)}/) {
			$msgid = gettext('Non-standard form of \/\1\/', $1);
			s/CAIGHDEAN{([^}]+)}/$msgid/;
		}
		if (/CAIGHMOIRF{([^}]+)}/) {
			$msgid = gettext('Derived from a non-standard form of \/\1\/', $1);
			s/CAIGHMOIRF{([^}]+)}/$msgid/;
		}
		if (/DROCHMHOIRF{([^}]+)}/) {
			$msgid = gettext('Derived incorrectly from the root \/\1\/', $1);
			s/DROCHMHOIRF{([^}]+)}/$msgid/;
		}
		if (/CLAOCHLU/) {
# TRANSLATORS: "Mutation" refers to either "lenition" or "eclipsis" (see below)
			$msgid = gettext('Initial mutation missing');
			s/CLAOCHLU/$msgid/;
		}
		if (/NISEIMHIU/) {
# TRANSLATORS: "Lenition" is the softening of an initial consonant in Irish.
# It is indicated in writing by the addition of an "h": e.g. "bean" -> "bhean"
			$msgid = gettext('Unnecessary lenition');
			s/NISEIMHIU/$msgid/;
		}
		if (/PREFIXH/) {
			$msgid = gettext('Prefix \/h\/ missing');
			s/PREFIXH/$msgid/;
		}
		if (/PREFIXT/) {
			$msgid = gettext('Prefix \/t\/ missing');
			s/PREFIXT/$msgid/;
		}
		if (/SEIMHIU/) {
			$msgid = gettext('Lenition missing');
			s/SEIMHIU/$msgid/;
		}
		if (/URU/) {
# TRANSLATORS: "Eclipsis" is, like lenition, a phonetic change applied to
# initial consonants in Irish.  It is indicated in writing by the addition
# of the eclipsing consonant as a prefix: e.g. "bean" -> "mbean"
			$msgid = gettext('Eclipsis missing');
			s/URU/$msgid/;
		}
		if (/DUBAILTE/) {
			$msgid = gettext('Repeated word');
			s/DUBAILTE/$msgid/;
		}
		if (/CUPLA/) {
			$msgid = gettext('Unusual combination of words');
			s/CUPLA/$msgid/;
		}
		if (/BREISCHEIM/) {
			$msgid = gettext('Comparative adjective required');
			s/BREISCHEIM/$msgid/;
		}
		if (/NIAITCH/) {
			$msgid = gettext('Unnecessary prefix \/h\/');
			s/NIAITCH/$msgid/;
		}
		if (/NITEE/) {
			$msgid = gettext('Unnecessary prefix \/t\/');
			s/NITEE/$msgid/;
		}
		if (/ONEART/) {
			$msgid = gettext('Unnecessary use of the definite article');
			s/ONEART/$msgid/;
		}
		if (/GENITIVE/) {
			$msgid = gettext('The genitive case is required here');
			s/GENITIVE/$msgid/;
		}
		if (/MOIRF{([^}]+)}/) {
			$msgid = gettext('Not in database but apparently formed from the root \/\1\/', $1);
			s/MOIRF{([^}]+)}/$msgid/;
		}
		if (/MICHEART{([^}]+)}/) {
			$msgid = gettext('Do you mean \/\1\/?', $1);
			s/MICHEART{([^}]+)}/$msgid/;
		}
		if (/MIMHOIRF{([^}]+)}/) {
			$msgid = gettext('Derived form of common misspelling \/\1\/?', $1);
			s/MIMHOIRF{([^}]+)}/$msgid/;
		}
		if (/COMHFHOCAL{([^}]+)}/) {
			$msgid = gettext('Not in database but may be a compound \/\1\/?', $1);
			s/COMHFHOCAL{([^}]+)}/$msgid/;
		}
		if (/COMHCHAIGH{([^}]+)}/) {
			$msgid = gettext('Not in database but may be a non-standard compound \/\1\/?', $1);
			s/COMHCHAIGH{([^}]+)}/$msgid/;
		}
		if (/GRAM{([^}]+)}/) {
			$msgid = gettext('Possibly a foreign word (the sequence \/\1\/ is highly improbable)', $1);
			s/GRAM{([^}]+)}/$msgid/;
		}
	}
	return $msg;
}

##############################################################################

=item grammatical_errors TEXT

Returns the grammatical errors in the input TEXT as a reference to an array,
one error per element of the array, with each error given in a simple
XML format usable by other applications.  Error messages are localized
according to locale settings as determined by Locale::Maketext.

=cut

##############################################################################

# like the bash "xml_api"
sub grammatical_errors
{
	my ( $self, $text ) = @_;

	from_to($text, $self->{'input_encoding'}, 'ISO-8859-1');
	my $pristine = $text;  # so actually NOT pristine e.g. if input is utf8
	$pristine =~ s/^/ /;
	$pristine =~ s/\n/ \n /g;
	$pristine =~ s/$/ /;

	my $marked_up_sentences = $self->xml_sentences ($text);
	my $errors;  # array reference to return
  # endoflast is global offset in $pristine following the end of last error
	my $endoflast = 0;
	my $toy = 1;   # line number at position $endoflast; lines count from 1
	my $tox = -1;  # line position of end of last match (not like $+[0]!)

	foreach (@$marked_up_sentences) {
		if (/<E/) {
			my $plain = $_;
			$plain =~ s/<[^>]+>//g;
			$plain =~ s/^ *//;
			$plain =~ s/ *$//;
			my $buffered = " $plain ";
			while (m!(<E[^>]+>)(([^<]|<[^/]|</[^E])*)</E>!g) {
				my $thiserror = $1;
				my $errortext = $2;
				my $fromy;
				my $fromx;
				$errortext =~ s/<[^>]+>//g; # strip pos stuff
				my $errorregexp = $errortext;
				$thiserror =~ s/^<E/<E sentence="$plain" errortext="$errortext"/;
				$errorregexp =~ s/ /([\\s\\\\]|<[^>]+>)+/g;
				$errorregexp =~ s/^/(?<=[^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/;
				$errorregexp =~ s/$/(?=[^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/;
				$pristine =~ m!$errorregexp!gs;
				my $globs = $-[0];
				my $globe = $+[0];
				my $str = substr($pristine, $endoflast, $globs - $endoflast);
				$fromy = $toy + ($str =~ tr/\n/\n/);
				if ($fromy == $toy) {
					$fromx = $tox + 1 + ($globs - $endoflast);
				}
				else {
					$str =~ m/([^\n]+)$/s;
					$fromx = length ($1); 
				}
				$str = substr($pristine, $globs, $globe - $globs);
				$toy = $fromy + ($str =~ tr/\n/\n/); 
				if ($fromy == $toy) {
					$tox = $fromx + ($globe - $globs) - 1;
				}
				else {
					$str =~ m/([^\n]+)$/s;
					$tox = length ($1) - 1 ; 
				}
				$endoflast = $globe;
				$fromx--;
				my $toans = $tox - 1;  # keep tox for next err 
				$buffered =~ m!$errorregexp!g;
				my $offset = $-[0] - 1;
				$thiserror =~ s!^<E !<E offset="$offset" fromy="$fromy" fromx="$fromx" toy="$toy" tox="$toans" !;
				$thiserror = decode("ISO-8859-1", $thiserror);
				$thiserror =~ s! msg="([^"]+)"!" msg=\"".$self->localize_me($1)."\""!e;
				push @$errors, $thiserror;
			}
		}
	} # loop over sentences
	return $errors;
}

# functionally same as aonchiall; separate for profiling
sub aonchiall_deux
{
	return aonchiall(@_);
}

##############################################################################
#   The remaining functions are automatically generated using a high
#   level description of Irish grammar; see the An Gramadoir
#   developers' pack for more information...
#       http://borel.slu.edu/gramadoir/
##############################################################################
sub aonchiall
{
	for ($_[0]) {
	s/(<S>[Ii]<\/S> )<B><Z>(<[^>]*>)+<\/Z>(bhfuil)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(bhfuil)<\/B>()/$1<V p="xx" t="l\x{e1}ith">$3<\/V>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(raibh)<\/B>()/$1<V p="xx" t="caite">$3<\/V>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ff]aoin)<\/B>()/$1<S>$3<\/S>$4/g;
	s/(<S>[Ff]aoin<\/S> )<B><Z>(<[^>]*>)+<\/Z>(g?ch?\x{e9}ad)<\/B>()/$1<N pl="n" gnt="n">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(g?[Cc]h?\x{e9}ad)<\/B>( (<[\/A-DF-Z][^>]*>)+seo<\/[A-DF-Z]>)/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(g?[Cc]h?\x{e9}ad)<\/B>()/$1<A pl="n" gnt="n">$3<\/A>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Cc]heana)<\/B>()/$1<R>$3<\/R>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Mm]\x{e1}s)<\/B>()/$1<C>$3<\/C>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]b)<\/B>()/$1<V cop="y">$3<\/V>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(Ach)<\/B>()/$1<C>$3<\/C>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]ir)<\/B>()/$1<O>$3<\/O>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(Aire)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>((n-)?aire)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$3<\/N>$5/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(\x{e1}irithe)<\/B>()/$1<A>$3<\/A>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]lt)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]ma)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]s)<\/B>( <T>na<\/T>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]s)<\/B>( (<[\/A-DF-Z][^>]*>)+an<\/[A-DF-Z]>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]s)<\/B>( (<N[^>]*[^>]*>[^<]+<\/N>|<B><Z>(<N[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(ann)<\/B>()/$1<O>$3<\/O>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]n)<\/B>( (<V[^>]*[^>]*>[^<]+<\/V>|<B><Z>(<V[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<Q>$3<\/Q>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]n)<\/B>( (<[\/A-DF-Z][^>]*>)+amhlaidh<\/[A-DF-Z]>)/$1<Q>$3<\/Q>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]n)<\/B>( (<[\/A-DF-Z][^>]*>)+mar<\/[A-DF-Z]>)/$1<Q>$3<\/Q>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]n)<\/B>( (<P[^>]*[^>]*>t\x{e9}<\/P>|<B><Z>(<P[^>]*[^>]*>)+<\/Z>t\x{e9}<\/B>))/$1<T>$3<\/T>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]n)<\/B>( (<[PRSO][^>]*>[^<]+<\/[PRSO]>|<B><Z>(<[PRSO][^>]*>)+<\/Z>[^<]+<\/B>))/$1<Q>$3<\/Q>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]n)<\/B>( (<[\/A-DF-Z][^>]*>)+leis<\/[A-DF-Z]>)/$1<Q>$3<\/Q>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]n)<\/B>( (<[\/A-DF-Z][^>]*>)+m\x{f3}<\/[A-DF-Z]>)/$1<Q>$3<\/Q>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]n)<\/B>( (<[\/A-DF-Z][^>]*>)+de<\/[A-DF-Z]>)/$1<Q>$3<\/Q>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]n)<\/B>( (<[\/A-DF-Z][^>]*>)+faoi<\/[A-DF-Z]>)/$1<Q>$3<\/Q>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]n)<\/B>( (<[\/A-DF-Z][^>]*>)+fi\x{fa}<\/[A-DF-Z]>)/$1<Q>$3<\/Q>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]n)<\/B>( (<[^\/V][^>]*>[^<]+<\/[^V]>|<B><Z>(<[^V][^>]*>)+<\/Z>[^<]+<\/B>))/$1<T>$3<\/T>$4/g;
	s/(<S>[^<]+<\/S> )<B><Z>(<[^>]*>)+<\/Z>([Aa]n)<\/B>()/$1<T>$3<\/T>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]nuas)<\/B>()/$1<R>$3<\/R>$4/g;
	s/((<[\/A-DF-Z][^>]*>)+[Mm]ar<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>(aon)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$4<\/N>$5/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]on)<\/B>()/$1<A pl="n" gnt="n">$3<\/A>$4/g;
	s/((<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>(\x{e1}r)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$4<\/N>$5/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(\x{e1}r)<\/B>( <C>[^<]+<\/C>)/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(\x{e1}r)<\/B>( <T>[^<]+<\/T>)/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([\x{c1}\x{e1}]r)<\/B>()/$1<D>$3<\/D>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(ata)<\/B>()/$1<F>$3<\/F>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]t\x{e1})<\/B>()/$1<V p="xx" t="l\x{e1}ith">$3<\/V>$4/g;
	s/(<T>[Nn]a<\/T> )<B><Z>(<[^>]*>)+<\/Z>(ba)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Bb]a)<\/B>()/$1<V cop="y">$3<\/V>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(m?[Bb]h?aile)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Bb]haineann)<\/B>()/$1<V p="xx" t="l\x{e1}ith">$3<\/V>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Bb]h?arr)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Bb]h?eag)<\/B>()/$1<A pl="n" gnt="n">$3<\/A>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Bb]h\x{ed})<\/B>()/$1<V p="xx" t="caite">$3<\/V>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(g?[Cc]h?airde)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Cc]\x{e1}r)<\/B>( (<V[^>]*[^>]*>[^<]+<\/V>|<B><Z>(<V[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<Q>$3<\/Q>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Cc]\x{e1}r)<\/B>( (<[\/A-DF-Z][^>]*>)+([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/[A-DF-Z]>)/$1<Q>$3<\/Q>$4/g;
	s/(<T>na<\/T> )<B><Z>(<[^>]*>)+<\/Z>([Cc]\x{e9})<\/B>()/$1<N pl="n" gnt="y" gnd="f">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Cc][\x{c9}\x{e9}])<\/B>()/$1<Q>$3<\/Q>$4/g;
	s/((<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>([Cc]heathr\x{fa})<\/B>()/$1<A pl="n" gnt="n">$4<\/A>$5/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(g?[Cc]h?eathr\x{fa})<\/B>( (<N[^>]*[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>|<B><Z>(<N[^>]*[^>]*>)+<\/Z>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/B>))/$1<A pl="n" gnt="n">$3<\/A>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(g?[Cc]h?eathr\x{fa})<\/B>( (<N[^>]*h="y"[^>]*>[^<]+<\/N>|<B><Z>(<N[^>]*h="y"[^>]*>)+<\/Z>[^<]+<\/B>))/$1<A pl="n" gnt="n">$3<\/A>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(cheile)<\/B>()/$1<F>$3<\/F>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(cinn)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Cc]omhalta)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(g?ch?\x{f3}na\x{ed})<\/B>()/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/((<[\/A-DF-Z][^>]*>)+an<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>([Cc]huir)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$4<\/N>$5/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Cc]huir)<\/B>()/$1<V p="xx" t="caite">$3<\/V>$4/g;
	s/(<T>na<\/T> )<B><Z>(<[^>]*>)+<\/Z>(g[Cc]umann)<\/B>()/$1<N pl="y" gnt="y" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(g?[Cc]h?umann)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/((<[\/A-DF-Z][^>]*>)+[Aa]o?n<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>(d\x{e1})<\/B>()/$1<A pl="n" gnt="n">$4<\/A>$5/g;
	s/((<[\/A-DF-Z][^>]*>)+g?ch?\x{e9}ad<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>(d\x{e1})<\/B>()/$1<A pl="n" gnt="n">$4<\/A>$5/g;
	s/(<S>[Ss]a<\/S> )<B><Z>(<[^>]*>)+<\/Z>(d\x{e1})<\/B>()/$1<A pl="n" gnt="n">$3<\/A>$4/g;
	s/((<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>([Dd]\x{e1})<\/B>()/$1<A pl="n" gnt="n">$4<\/A>$5/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Dd]\x{e1})<\/B>( (<V[^>]*[^>]*>[^<]+<\/V>|<B><Z>(<V[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<C>$3<\/C>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Dd]\x{e1})<\/B>( (<N[^>]*[^>]*>[^<]+<\/N>|<B><Z>(<N[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<D>$3<\/D>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Dd]\x{e1})<\/B>( (<[\/A-DF-Z][^>]*>)+h[^<]+<\/[A-DF-Z]>)/$1<D>$3<\/D>$4/g;
	s/((<[\/A-DF-Z][^>]*>)+an<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>(d\x{e1}la)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$4<\/N>$5/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(D\x{e9})<\/B>()/$1<N pl="n" gnt="y" gnd="m">$3<\/N>$4/g;
	s/((<N[^>]*[^>]*>D\x{e9}<\/N>|<B><Z>(<N[^>]*[^>]*>)+<\/Z>D\x{e9}<\/B>) )<B><Z>()(<[^>]*>)*<N pl="n" gnt="y" gnd="m"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$8<\/N>$9/g;
	s/((<N[^>]*[^>]*>D\x{e9}<\/N>|<B><Z>(<N[^>]*[^>]*>)+<\/Z>D\x{e9}<\/B>) )<B><Z>()(<[^>]*>)*<N pl="n" gnt="y" gnd="f"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="f">$8<\/N>$9/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Dd]\x{e9}ag)<\/B>()/$1<N pl="n" gnt="n">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(n?[Dd]h?earna)<\/B>()/$1<V p="xx" t="caite">$3<\/V>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Dd]eir)<\/B>()/$1<V p="xx" t="l\x{e1}ith">$3<\/V>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Dd]eireadh)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(d\x{ed}o?bh)<\/B>()/$1<O>$3<\/O>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Dd]o)<\/B>( <T>na<\/T>)/$1<S>$3<\/S>$4/g;
	s/(<S>[^<]+<\/S> )<B><Z>(<[^>]*>)+<\/Z>(do)<\/B>()/$1<D>$3<\/D>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(do)<\/B>( <D>[^<]+<\/D>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(do)<\/B>( <Y>[^<]+<\/Y>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(do)<\/B>( (<[\/A-DF-Z][^>]*>)+gach<\/[A-DF-Z]>)/$1<S>$3<\/S>$4/g;
	s/((<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>(d\x{f3})<\/B>()/$1<N pl="n" gnt="n">$4<\/N>$5/g;
	s/((<[\/A-DF-Z][^>]*>)+an<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>(d\x{f3})<\/B>()/$1<A pl="n" gnt="n">$4<\/A>$5/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(Dh?\x{fa}n)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([\x{c9}\x{e9}])<\/B>()/$1<P>$3<\/P>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(h?\x{e9}asca)<\/B>()/$1<A>$3<\/A>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ff]aoi)<\/B>( <T>na<\/T>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ff]aoi)<\/B>( (<[\/A-DF-Z][^>]*>)+an<\/[A-DF-Z]>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ff]aoi)<\/B>( (<N[^>]*[^>]*>[^<]+<\/N>|<B><Z>(<N[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ff]eadh)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/(<T>na<\/T> )<B><Z>(<[^>]*>)+<\/Z>(bh[Ff]ear)<\/B>()/$1<N pl="y" gnt="y" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>((bh)?[Ff]h?ear)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$5/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ff]\x{e9}in)<\/B>()/$1<R>$3<\/R>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>((bh)?[Ff]uair)<\/B>()/$1<V p="xx" t="caite">$3<\/V>$5/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Gg]ach)<\/B>( (<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]>)/$1<N pl="n" gnt="n">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Gg]ach)<\/B>( (<[\/A-DF-Z][^>]*>)+ar<\/[A-DF-Z]>)/$1<N pl="n" gnt="n">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Gg]ach)<\/B>( (<[\/A-DF-Z][^>]*>)+is<\/[A-DF-Z]>)/$1<N pl="n" gnt="n">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Gg]ach)<\/B>()/$1<A pl="n" gnt="n">$3<\/A>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(g[Cc]inn)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Gg]o)<\/B>( (<A[^>]*[^>]*>[^<]+<\/A>|<B><Z>(<A[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<U>$3<\/U>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ii]onam)<\/B>()/$1<O>$3<\/O>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(iontach)<\/B>()/$1<A pl="n" gnt="n">$3<\/A>$4/g;
	s/()<B><Z>()<R.><A pl="n" gnt="n".><\/Z>([^<]+)<\/B>()/$1<R>$3<\/R>$4/g;
	s/((<[^\/ST][^>]*>[^<]+<\/[^ST]>|<B><Z>(<[^ST][^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>(<[^>]*>)+<\/Z>(theas)<\/B>()/$1<A pl="n" gnt="n">$5<\/A>$6/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ll]\x{e1}n)<\/B>( (<N[^>]*pl="y"[^>]*>[^<]+<\/N>|<B><Z>(<N[^>]*pl="y"[^>]*>)+<\/Z>[^<]+<\/B>))/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ll]\x{e1}n)<\/B>( <D>[^<]+<\/D>)/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ll]\x{e1}n)<\/B>( <S>de<\/S>)/$1<A pl="n" gnt="n">$3<\/A>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ll]\x{e9}inn)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ll]eis)<\/B>( <T>na<\/T>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ll]eis)<\/B>( (<[\/A-DF-Z][^>]*>)+an<\/[A-DF-Z]>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ll]eith)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ll]eo)<\/B>()/$1<O>$3<\/O>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Mm]\x{e1})<\/B>( (<V[^>]*[^>]*>[^<]+<\/V>|<B><Z>(<V[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<C>$3<\/C>$4/g;
	s/(<S>[^<]+<\/S> )<B><Z>(<[^>]*>)+<\/Z>(mh?aith)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$3<\/N>$4/g;
	s/(<T>na<\/T> )<B><Z>(<[^>]*>)+<\/Z>(mh?aith)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$3<\/N>$4/g;
	s/((<[\/A-DF-Z][^>]*>)+an<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>(mh?aith)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$4<\/N>$5/g;
	s/((<[\/A-DF-Z][^>]*>)+[Aa]on<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>(mh?aith)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$4<\/N>$5/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Mm]h?aith)<\/B>()/$1<A pl="n" gnt="n">$3<\/A>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Mm]ar)<\/B>( (<[\/A-DF-Z][^>]*>)+gheall<\/[A-DF-Z]>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Mm]h?\x{f3}r)<\/B>()/$1<A pl="n" gnt="n">$3<\/A>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Nn]\x{e1})<\/B>( (<V[^>]*[^>]*>[^<]+<\/V>|<B><Z>(<V[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<U>$3<\/U>$4/g;
	s/((<[\/A-DF-Z][^>]*>)+[Nn]\x{e1}<\/[A-DF-Z]> )<B><Z>()(<[^>]*>)*<V[^>]*t="ord".>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<V p="xx" t="ord">$6<\/V>$7/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Nn]\x{e1})<\/B>()/$1<C>$3<\/C>$4/g;
	s/()<B><Z>()<N pl="n" gnt="n" gnd="m" h="y".><V p="2\x{fa}" t="ord".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m" h="y">$3<\/N>$4/g;
	s/()<B><Z>()<N pl="n" gnt="n" gnd="f" h="y".><V p="2\x{fa}" t="ord".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f" h="y">$3<\/N>$4/g;
	s/((<N[^>]*[^>]*>Spiorad<\/N>|<B><Z>(<N[^>]*[^>]*>)+<\/Z>Spiorad<\/B>) )<B><Z>(<[^>]*>)+<\/Z>(Naomh)<\/B>()/$1<A pl="n" gnt="n">$5<\/A>$6/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Nn]aomh)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/((<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>([Nn]\x{ed})<\/B>()/$1<N pl="n" gnt="n" gnd="m">$4<\/N>$5/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Nn]\x{ed})<\/B>( (<[\/A-DF-Z][^>]*>)+nach<\/[A-DF-Z]>)/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Nn]\x{ed})<\/B>( (<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]>)/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/((<[\/A-DF-Z][^>]*>)+[Gg]ach<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>([Nn]\x{ed})<\/B>()/$1<N pl="n" gnt="n" gnd="m">$4<\/N>$5/g;
	s/((<[\/A-DF-Z][^>]*>)+[Aa]on<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>([Nn]\x{ed})<\/B>()/$1<N pl="n" gnt="n" gnd="m">$4<\/N>$5/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Nn]\x{ed})<\/B>( (<V[^>]*[^>]*>[^<]+<\/V>|<B><Z>(<V[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<U>$3<\/U>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Nn]\x{ed})<\/B>( (<A[^>]*[^>]*>m\x{f3}r<\/A>|<B><Z>(<A[^>]*[^>]*>)+<\/Z>m\x{f3}r<\/B>))/$1<V cop="y">$3<\/V>$4/g;
	s/(<C>[^<]+<\/C> )<B><Z>(<[^>]*>)+<\/Z>(n\x{ed})<\/B>( (<[^\/V][^>]*>[^<]+<\/[^V]>|<B><Z>(<[^V][^>]*>)+<\/Z>[^<]+<\/B>))/$1<V cop="y">$3<\/V>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Nn]\x{ed})<\/B>( (<N[^>]*[^>]*>[^<]+<\/N>|<B><Z>(<N[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<V cop="y">$3<\/V>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Nn]\x{ed})<\/B>( (<P[^>]*[^>]*>[^<]+<\/P>|<B><Z>(<P[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<V cop="y">$3<\/V>$4/g;
	s/((<[\/A-DF-Z][^>]*>)+an<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>(N\x{ed}l)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$4<\/N>$5/g;
	s/(<S>[^<]+<\/S> )<B><Z>(<[^>]*>)+<\/Z>(N\x{ed}l)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(N\x{ed}l)<\/B>()/$1<V p="xx" t="l\x{e1}ith">$3<\/V>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Nn]\x{ed}or)<\/B>()/$1<V cop="y">$3<\/V>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Nn]uair)<\/B>()/$1<C>$3<\/C>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(os)<\/B>()/$1<S>$3<\/S>$4/g;
	s/(<T>na<\/T> )<B><Z>(<[^>]*>)+<\/Z>([Rr]inne)<\/B>()/$1<N pl="n" gnt="y" gnd="f">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Rr]inne)<\/B>()/$1<V p="xx" t="caite">$3<\/V>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Rr]ithe)<\/B>()/$1<F>$3<\/F>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(San)<\/B>( (<[\/A-DF-Z][^>]*>)+[A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]>)/$1<N pl="n" gnt="n">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(San)<\/B>()/$1<S>$3<\/S>$4/g;
	s/(<T>na<\/T> )<B><Z>(<[^>]*>)+<\/Z>(s\x{ed})<\/B>()/$1<N pl="n" gnt="y" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(s\x{ed})<\/B>()/$1<P>$3<\/P>$4/g;
	s/((<[\/A-DF-Z][^>]*>)+\x{d3}<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>(S\x{e9})<\/B>()/$1<Y>$4<\/Y>$5/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ss]\x{e9})<\/B>( (<[\/A-DF-Z][^>]*>)+([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/[A-DF-Z]>)/$1<A pl="n" gnt="n">$3<\/A>$4/g;
	s/((<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z>(<[^>]*>)+<\/Z>(s\x{e9})<\/B>()/$1<A pl="n" gnt="n">$4<\/A>$5/g;
	s/((<P[^>]*[^>]*>s\x{ed}<\/P>|<B><Z>(<P[^>]*[^>]*>)+<\/Z>s\x{ed}<\/B>) <C>n\x{f3}<\/C> )<B><Z>(<[^>]*>)+<\/Z>(s\x{e9})<\/B>()/$1<P>$5<\/P>$6/g;
	s/((<[^\/V][^>]*>[^<]+<\/[^V]>|<B><Z>(<[^V][^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>(<[^>]*>)+<\/Z>([Ss]\x{e9})<\/B>()/$1<A pl="n" gnt="n">$5<\/A>$6/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ss]\x{e9})<\/B>()/$1<P>$3<\/P>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ss]iad)<\/B>()/$1<P>$3<\/P>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Tt]har)<\/B>()/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Tt]hart)<\/B>()/$1<R>$3<\/R>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(T[Hh][Ee])<\/B>()/$1<F>$3<\/F>$4/g;
	s/((<[^\/N][^>]*>[^<]+<\/[^N]>|<B><Z>(<[^N][^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>(<[^>]*>)+<\/Z>(the)<\/B>()/$1<F>$5<\/F>$6/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Tt][Hh][Ee])<\/B>( <X>[^<]+<\/X>)/$1<F>$3<\/F>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(theannta)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Tt]h?\x{ed})<\/B>()/$1<N pl="n" gnt="y" gnd="m">$3<\/N>$4/g;
	s/(<T>[^<]+<\/T> )<B><Z>(<[^>]*>)+<\/Z>([Tt]r\x{ed})<\/B>()/$1<A pl="n" gnt="n">$3<\/A>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Tt]r\x{ed})<\/B>( (<[\/A-DF-Z][^>]*>)+(bliana|cinn|fichid|seachtaine)<\/[A-DF-Z]>)/$1<A pl="n" gnt="n">$3<\/A>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Tt]r\x{ed})<\/B>()/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Tt]r\x{ed}d)<\/B>( <T>na<\/T>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Tt]r\x{ed}d)<\/B>( (<[\/A-DF-Z][^>]*>)+an<\/[A-DF-Z]>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Tt]r\x{ed}d)<\/B>()/$1<O>$3<\/O>$4/g;
	s/()<B><Z>()<N pl="n" gnt="n" gnd="m".><N pl="n" gnt="y" gnd="m".><A pl="n" gnt="n".><\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$3<\/A>$4/g;
	s/((<[\/A-DF-Z][^>]*>)+([Cc]ois|[Dd]\x{e1}la|[Ff]earacht|[Tt]impeall|[Tt]rasna)<\/[A-DF-Z]> <T>an<\/T> )<B><Z>()(<[^>]*>)*<N pl="n" gnt="y" gnd="m"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$8<\/N>$9/g;
	s/((<[\/A-DF-Z][^>]*>)+([Cc]ois|[Dd]\x{e1}la|[Ff]earacht|[Tt]impeall|[Tt]rasna)<\/[A-DF-Z]> <T>na<\/T> )<B><Z>()(<[^>]*>)*<N pl="n" gnt="y" gnd="f"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="f">$8<\/N>$9/g;
	s/((<[\/A-DF-Z][^>]*>)+([Cc]ois|[Dd]\x{e1}la|[Ff]earacht|[Tt]impeall|[Tt]rasna)<\/[A-DF-Z]> <T>na<\/T> )<B><Z>()(<[^>]*>)*<N pl="y" gnt="y" gnd="m"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="y" gnd="m">$8<\/N>$9/g;
	s/((<[\/A-DF-Z][^>]*>)+([Cc]ois|[Dd]\x{e1}la|[Ff]earacht|[Tt]impeall|[Tt]rasna)<\/[A-DF-Z]> <T>na<\/T> )<B><Z>()(<[^>]*>)*<N pl="y" gnt="y" gnd="f"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="y" gnd="f">$8<\/N>$9/g;
	s/(<S>[Gg]o dt\x{ed}<\/S> <T>an<\/T> )<B><Z>()(<[^>]*>)*<N pl="n" gnt="n" gnd="m"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$6<\/N>$7/g;
	s/(<S>[Gg]o dt\x{ed}<\/S> <T>na<\/T> )<B><Z>()(<[^>]*>)*<N pl="y" gnt="n" gnd="f"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$6<\/N>$7/g;
	s/(<S>[Gg]o dt\x{ed}<\/S> <T>na<\/T> )<B><Z>()(<[^>]*>)*<N pl="y" gnt="n" gnd="m"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$6<\/N>$7/g;
	s/(<S>[^< ]+ [^<]+<\/S> <T>an<\/T> )<B><Z>()(<[^>]*>)*<N pl="n" gnt="y" gnd="m"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$6<\/N>$7/g;
	s/(<S>[^< ]+ [^<]+<\/S> <T>na<\/T> )<B><Z>()(<[^>]*>)*<N pl="n" gnt="y" gnd="f"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="f">$6<\/N>$7/g;
	s/(<S>[^< ]+ [^<]+<\/S> <T>na<\/T> )<B><Z>()(<[^>]*>)*<N pl="y" gnt="y" gnd="m"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="y" gnd="m">$6<\/N>$7/g;
	s/(<S>[^< ]+ [^<]+<\/S> <T>na<\/T> )<B><Z>()(<[^>]*>)*<N pl="y" gnt="y" gnd="f"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="y" gnd="f">$6<\/N>$7/g;
	s/(<S>[^<]+<\/S> )<B><Z>()(<[^>]*>)*<N pl="n" gnt="n" gnd="m"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$6<\/N>$7/g;
	s/(<S>[^<]+<\/S> )<B><Z>()(<[^>]*>)*<N pl="n" gnt="n" gnd="f"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$6<\/N>$7/g;
	s/(<S>[^<]+<\/S> )<B><Z>()(<[^>]*>)*<N pl="y" gnt="n" gnd="f"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$6<\/N>$7/g;
	s/(<S>[^<]+<\/S> )<B><Z>()(<[^>]*>)*<N pl="y" gnt="n" gnd="m"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$6<\/N>$7/g;
	s/((<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>|<B><Z>(<N[^>]*pl="n" gnt="n"[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>()(<[^>]*>)*<N pl="n" gnt="y" gnd="m"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$8<\/N>$9/g;
	s/((<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>|<B><Z>(<N[^>]*pl="n" gnt="n"[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>()(<[^>]*>)*<N pl="n" gnt="y" gnd="f"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="f">$8<\/N>$9/g;
	s/()<B><Z>()<S.><R.>(<A pl="n" gnt="n".>)?<\/Z>([^<]+)<\/B>()/$1<R>$4<\/R>$5/g;
	s/((<N[^>]*pl="y"[^>]*>[^<]+<\/N>|<B><Z>(<N[^>]*pl="y"[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>()(<N pl="y"[^>]*>)*(<A[^>]*>)*<A pl="y" gnt="n".><\/Z>([^<]+)<\/B>()/$1<A pl="y" gnt="n">$7<\/A>$8/g;
	s/((<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>|<B><Z>(<N[^>]*pl="n" gnt="n"[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>()(<N pl="y"[^>]*>)*<A pl="n" gnt="n".>(<A[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$7<\/A>$8/g;
	s/((<A[^>]*pl="y"[^>]*>[^<]+<\/A>|<B><Z>(<A[^>]*pl="y"[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>()(<N pl="y"[^>]*>)*(<A[^>]*>)*<A pl="y" gnt="n".><\/Z>([^<]+)<\/B>()/$1<A pl="y" gnt="n">$7<\/A>$8/g;
	s/((<A[^>]*pl="n" gnt="y" gnd="f"[^>]*>[^<]+<\/A>|<B><Z>(<A[^>]*pl="n" gnt="y" gnd="f"[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>()(<N pl="y"[^>]*>)*(<A[^>]*>)*<A pl="n" gnt="y" gnd="f".>(<A[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="y" gnd="f">$8<\/A>$9/g;
	s/((<A[^>]*pl="n" gnt="y" gnd="m"[^>]*>[^<]+<\/A>|<B><Z>(<A[^>]*pl="n" gnt="y" gnd="m"[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>()(<N pl="y"[^>]*>)*(<A[^>]*>)*<A pl="n" gnt="y" gnd="m".>(<A[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="y" gnd="m">$8<\/A>$9/g;
	s/((<A[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/A>|<B><Z>(<A[^>]*pl="n" gnt="n"[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>()(<N pl="y"[^>]*>)*<A pl="n" gnt="n".>(<A[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$7<\/A>$8/g;
	s/(<T>[Nn]a<\/T> )<B><Z>()(<[^>]*>)*<N pl="y" gnt="n" gnd="f"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$6<\/N>$7/g;
	s/(<T>[Nn]a<\/T> )<B><Z>()(<[^>]*>)*<N pl="y" gnt="n" gnd="m"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$6<\/N>$7/g;
	s/(<S>[Ss]na<\/S> )<B><Z>()(<[^>]*>)*<N pl="y" gnt="n" gnd="f"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$6<\/N>$7/g;
	s/(<S>[Ss]na<\/S> )<B><Z>()(<[^>]*>)*<N pl="y" gnt="n" gnd="m"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$6<\/N>$7/g;
	s/((<[^\/S][^>]*>[^<]+<\/[^S]>|<B><Z>(<[^S][^>]*>)+<\/Z>[^<]+<\/B>) (<[\/A-DF-Z][^>]*>)+an<\/[A-DF-Z]> )<B><Z>()(<[^>]*>)*<N pl="n" gnt="y" gnd="m"( h="y")?.>(<[^>]*>)*<\/Z>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$9<\/N>$10/g;
	s/((<[\/A-DF-Z][^>]*>)+[Gg]o<\/[A-DF-Z]> )<B><Z>()(<N pl="y"[^>]*>)*<A pl="n" gnt="n".>(<A[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$6<\/A>$7/g;
	s/(<R>[Cc]homh<\/R> )<B><Z>()(<[^>]*>)*<A pl="n" gnt="n".>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$5<\/A>$6/g;
	s/(<R>[Cc]homh<\/R> )<B><Z>()(<[^>]*>)*<A pl="n" gnt="n" h="y".>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n" h="y">$5<\/A>$6/g;
	s/(<R>[Nn]\x{ed}os<\/R> )<B><Z>()(<N pl="y"[^>]*>)*(<[^>]*>)*<A pl="n" gnt="y" gnd="f".>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="y" gnd="f">$6<\/A>$7/g;
	s/(<R>[Nn]\x{ed}b<\/R> )<B><Z>()(<N pl="y"[^>]*>)*(<[^>]*>)*<A pl="n" gnt="y" gnd="f".>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="y" gnd="f">$6<\/A>$7/g;
	s/(<R>[Nn]\x{ed}ba<\/R> )<B><Z>()(<N pl="y"[^>]*>)*(<[^>]*>)*<A pl="n" gnt="y" gnd="f".>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="y" gnd="f">$6<\/A>$7/g;
	s/((<[\/A-DF-Z][^>]*>)+is<\/[A-DF-Z]> )<B><Z>()(<N pl="y"[^>]*>)*(<[^>]*>)*<A pl="n" gnt="y" gnd="f".>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="y" gnd="f">$7<\/A>$8/g;
	s/((<[\/A-DF-Z][^>]*>)+[Gg]o<\/[A-DF-Z]> )<B><Z>()(<N[^>]*>)+<A pl="n" gnt="n".>(<[AV][^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$6<\/A>$7/g;
	s/((<[\/A-DF-Z][^>]*>)+[Gg]o<\/[A-DF-Z]> )<B><Z>()(<N[^>]*>)+<A pl="n" gnt="n" h="y".>(<[AV][^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n" h="y">$6<\/A>$7/g;
	s/(<S>[^<]+<\/S> )<B><Z>()<N pl="n" gnt="n" gnd="m".>(<N pl="y" gnt="y" gnd="m".>)?<A pl="n" gnt="n".>(<[A-Z][^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$5<\/N>$6/g;
	s/(<T>[^<]+<\/T> )<B><Z>()<N pl="n" gnt="n" gnd="m".>(<N pl="y" gnt="y" gnd="m".>)?<A pl="n" gnt="n".>(<[A-Z][^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$5<\/N>$6/g;
	s/((<[\/A-DF-Z][^>]*>)+[Aa]<\/[A-DF-Z]> )<B><Z>()<N pl="n" gnt="n" gnd="m".>(<N pl="y" gnt="y" gnd="m".>)?<A pl="n" gnt="n".>(<[A-Z][^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$6<\/N>$7/g;
	s/((<N[^>]*[^>]*>[^<]+<\/N>|<B><Z>(<N[^>]*[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>()<N pl="n" gnt="n" gnd="m".>(<N pl="y" gnt="y" gnd="m".>)?<A pl="n" gnt="n".>(<[A-Z][^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$7<\/A>$8/g;
	s/(<S>[^<]+<\/S> )<B><Z>()<N pl="n" gnt="n" gnd="f".><A pl="n" gnt="n".>(<[A-Z][^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$4<\/N>$5/g;
	s/(<T>[^<]+<\/T> )<B><Z>()<N pl="n" gnt="n" gnd="f".><A pl="n" gnt="n".>(<[A-Z][^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$4<\/N>$5/g;
	s/((<[\/A-DF-Z][^>]*>)+[Aa]<\/[A-DF-Z]> )<B><Z>()<N pl="n" gnt="n" gnd="f".><A pl="n" gnt="n".>(<[A-Z][^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$5<\/N>$6/g;
	s/((<N[^>]*[^>]*>[^<]+<\/N>|<B><Z>(<N[^>]*[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>()<N pl="n" gnt="n" gnd="f".><A pl="n" gnt="n".>(<[A-Z][^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A>$6<\/A>$7/g;
	s/(<S>[^<]+<\/S> )<B><Z>()<N pl="n" gnt="n" gnd="m".>(<V p=".."[^>]*>)+<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$4<\/N>$5/g;
	s/(<T>[^<]+<\/T> )<B><Z>()<N pl="n" gnt="n" gnd="m".>(<V p=".."[^>]*>)+<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$4<\/N>$5/g;
	s/((<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z>()<N pl="n" gnt="n" gnd="m".>(<V p=".."[^>]*>)+<\/Z>([^<]+)<\/B>( (<P[^>]*[^>]*>[^<]+<\/P>|<B><Z>(<P[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<V p="xx" t="caite">$5<\/V>$6/g;
	s/((<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z>()<N pl="n" gnt="n" gnd="m".>(<V p=".."[^>]*>)+<\/Z>([^<]+)<\/B>( (<[\/A-DF-Z][^>]*>)+s\x{e9}<\/[A-DF-Z]>)/$1<V p="xx" t="caite">$5<\/V>$6/g;
	s/((<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z>()<N pl="n" gnt="n" gnd="m".>(<V p=".."[^>]*>)+<\/Z>([^<]+)<\/B>( (<N[^>]*[^>]*>[^<]+<\/N>|<B><Z>(<N[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<V p="xx" t="caite">$5<\/V>$6/g;
	s/((<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z>()<N pl="n" gnt="n" gnd="m".>(<V p=".."[^>]*>)+<\/Z>([^<]+)<\/B>( <Y>[^<]+<\/Y>)/$1<V p="xx" t="caite">$5<\/V>$6/g;
	s/((<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z>()<N pl="n" gnt="n" gnd="m".>(<V p=".."[^>]*>)+<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$5<\/N>$6/g;
	s/((<V[^>]*[^>]*>[^<]+<\/V>|<B><Z>(<V[^>]*[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>()<N pl="n" gnt="n" gnd="m".>(<V p=".."[^>]*>)+<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$6<\/N>$7/g;
	s/(<S>[^<]+<\/S> )<B><Z>()<N pl="n" gnt="n" gnd="f".>(<V p=".."[^>]*>)+<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$4<\/N>$5/g;
	s/(<T>[^<]+<\/T> )<B><Z>()<N pl="n" gnt="n" gnd="f".>(<V p=".."[^>]*>)+<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$4<\/N>$5/g;
	s/((<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z>()<N pl="n" gnt="n" gnd="f".>(<V p=".."[^>]*>)+<\/Z>([^<]+)<\/B>( (<P[^>]*[^>]*>[^<]+<\/P>|<B><Z>(<P[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<V p="xx" t="caite">$5<\/V>$6/g;
	s/((<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z>()<N pl="n" gnt="n" gnd="f".>(<V p=".."[^>]*>)+<\/Z>([^<]+)<\/B>( (<[\/A-DF-Z][^>]*>)+s\x{e9}<\/[A-DF-Z]>)/$1<V p="xx" t="caite">$5<\/V>$6/g;
	s/((<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z>()<N pl="n" gnt="n" gnd="f".>(<V p=".."[^>]*>)+<\/Z>([^<]+)<\/B>( (<N[^>]*[^>]*>[^<]+<\/N>|<B><Z>(<N[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<V p="xx" t="caite">$5<\/V>$6/g;
	s/((<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z>()<N pl="n" gnt="n" gnd="f".>(<V p=".."[^>]*>)+<\/Z>([^<]+)<\/B>( <Y>[^<]+<\/Y>)/$1<V p="xx" t="caite">$5<\/V>$6/g;
	s/((<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z>()<N pl="n" gnt="n" gnd="f".>(<V p=".."[^>]*>)+<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$5<\/N>$6/g;
	s/((<V[^>]*[^>]*>[^<]+<\/V>|<B><Z>(<V[^>]*[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>()<N pl="n" gnt="n" gnd="f".>(<V p=".."[^>]*>)+<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$6<\/N>$7/g;
	s/(<C>[^<]+<\/C> )<B><Z>()<N pl="n" gnt="n" gnd="m".><V p="saor" t="caite".><V p="3\x{fa}" t="ord".>(<V p="3\x{fa}" t="gn\x{e1}th".><V pl="y" p="2\x{fa}" t="gn\x{e1}th".>)?<\/Z>([^<]+)<\/B>()/$1<V p="saor" t="caite">$4<\/V>$5/g;
	s/((<[\/A-DF-Z][^>]*>)+[\x{d3}\x{f3}]<\/[A-DF-Z]> )<B><Z>()<N pl="n" gnt="n" gnd="m".><V p="saor" t="caite".><V p="3\x{fa}" t="ord".>(<V p="3\x{fa}" t="gn\x{e1}th".><V pl="y" p="2\x{fa}" t="gn\x{e1}th".>)?<\/Z>(([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*)<\/B>()/$1<V p="saor" t="caite">$5<\/V>$7/g;
	s/((<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z>()<N pl="n" gnt="n" gnd="m".><V p="saor" t="caite".><V p="3\x{fa}" t="ord".>(<V p="3\x{fa}" t="gn\x{e1}th".><V pl="y" p="2\x{fa}" t="gn\x{e1}th".>)?<\/Z>(([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*)<\/B>()/$1<V p="saor" t="caite">$5<\/V>$7/g;
	s/((<V[^>]*cop="y"[^>]*>[^<]+<\/V>|<B><Z>(<V[^>]*cop="y"[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>()<N pl="n" gnt="n" gnd="m".><V p="saor" t="caite".><V p="3\x{fa}" t="ord".>(<V p="3\x{fa}" t="gn\x{e1}th".><V pl="y" p="2\x{fa}" t="gn\x{e1}th".>)?<\/Z>(([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*)<\/B>()/$1<V p="saor" t="caite">$6<\/V>$8/g;
	s/()<B><Z>()<R.><N pl="n" gnt="n".><\/Z>([^<]+)<\/B>()/$1<R>$3<\/R>$4/g;
	s/()<B><Z>()<S.><D.><\/Z>([^<][^<][^<]+)<\/B>( (<V[^>]*[^>]*>[^<]+<\/V>|<B><Z>(<V[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<S>$3<\/S>$4/g;
	s/()<B><Z>()<S.><D.><\/Z>([^<][^<][^<]+)<\/B>()/$1<D>$3<\/D>$4/g;
	s/()<B><Z>()<N pl="y" gnt="n".><N pl="y" gnt="n" gnd="m".><\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$3<\/N>$4/g;
	s/()<B><Z>()<Y.>(<[^>]*>)+<\/Z>([^<]+)<\/B>()/$1<Y>$4<\/Y>$5/g;
	s/()<B><Z>()<N pl="n" gnt="n" gnd="m".>(<V [^>]*t="foshuit".>)+<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$4<\/N>$5/g;
	s/()<B><Z>()<N pl="y" gnt="n" gnd="m".>(<V [^>]*t="foshuit".>)+<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$4<\/N>$5/g;
	s/()<B><Z>()<N pl="y" gnt="n" gnd="f".>(<V [^>]*t="foshuit".>)+<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$4<\/N>$5/g;
	s/()<B><Z>()<N pl="y" gnt="n".><N pl="y" gnt="n" gnd="f".><\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$3<\/N>$4/g;
	s/()<B><Z>()<V pl="y" p="1\x{fa}" t="l\x{e1}ith".><V pl="y" p="1\x{fa}" t="foshuit".><\/Z>([^<]+)<\/B>()/$1<V pl="y" p="1\x{fa}" t="l\x{e1}ith">$3<\/V>$4/g;
	s/()<B><Z>()<N pl="n" gnt="y" gnd="f".>(<V [^>]*t="foshuit".>)+<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="f">$4<\/N>$5/g;
	s/()<B><Z>()<A pl="y" gnt="n".>(<V [^>]*t="foshuit".>)+<\/Z>([^<]+)<\/B>()/$1<A pl="y" gnt="n">$4<\/A>$5/g;
	s/()<B><Z>()<N pl="n" gnt="y" gnd=".".><A pl="n" gnt="n".>(<A [^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A>$4<\/A>$5/g;
	s/((<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]> )<B><Z>()(<[^>]*>)*<N pl="n" gnt="y" gnd="m"( h="y")?.><N pl="y" gnt="n" gnd="m"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$8<\/N>$9/g;
	s/((<[\/A-DF-Z][^>]*>)+[Gg]ach<\/[A-DF-Z]> )<B><Z>()(<[^>]*>)*<N pl="n" gnt="y" gnd="m"( h="y")?.><N pl="y" gnt="n" gnd="m"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$8<\/N>$9/g;
	s/((<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]> )<B><Z>()(<[^>]*>)*<N pl="n" gnt="n" gnd="m"( h="y")?.><N pl="y" gnt="y" gnd="m"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$8<\/N>$9/g;
	s/((<[^\/N][^>]*>[^<]+<\/[^N]>|<B><Z>(<[^N][^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>()<N pl="n" gnt="y" gnd="m"( h="y")?.><N pl="y" gnt="n" gnd="m"( h="y")?.><\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$7<\/N>$8/g;
	s/()<B><Z>()<N pl="n" gnt="y" gnd="m"( h="y")?.><N pl="y" gnt="n" gnd="m"( h="y")?.><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$5<\/N>$6/g;
	s/(<T>na<\/T> )<B><Z>()<N pl="n" gnt="n" gnd="m"( h="y")?.><N pl="y" gnt="y" gnd="m"( h="y")?.><\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="y" gnd="m">$5<\/N>$6/g;
	s/()<B><Z>()<N pl="n" gnt="n" gnd="m"( h="y")?.><N pl="y" gnt="y" gnd="m"( h="y")?.><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$5<\/N>$6/g;
	s/(<T>na<\/T> )<B><Z>()<N pl="n" gnt="n" gnd="f".><N pl="y" gnt="y" gnd="f".><\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="y" gnd="f">$3<\/N>$4/g;
	s/()<B><Z>()<N pl="n" gnt="n" gnd="f".><N pl="y" gnt="y" gnd="f".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$3<\/N>$4/g;
	s/((<N[^>]*[^>]*>[^<]+<\/N>|<B><Z>(<N[^>]*[^>]*>)+<\/Z>[^<]+<\/B>) <T>[Aa]n<\/T> )<B><Z>()<N pl="n" gnt="n" gnd="f".><N pl="n" gnt="y" gnd="m".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$5<\/N>$6/g;
	s/(<T>[Aa]n<\/T> )<B><Z>()<N pl="n" gnt="n" gnd="f".><N pl="n" gnt="y" gnd="m".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$3<\/N>$4/g;
	s/((<[^\/N][^>]*>[^<]+<\/[^N]>|<B><Z>(<[^N][^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>()<N pl="n" gnt="n" gnd="f".><N pl="n" gnt="y" gnd="m".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$5<\/N>$6/g;
	s/(<S>[^<]+<\/S> <T>[Aa]n<\/T> )<B><Z>()<N pl="n" gnt="n" gnd="m".><N pl="n" gnt="y" gnd="m".>(<V [^>]*t="foshuit".>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$4<\/N>$5/g;
	s/(<T>[Aa]n<\/T> )<B><Z>()<N pl="n" gnt="n" gnd="m".><N pl="n" gnt="y" gnd="m".>(<V [^>]*t="foshuit".>)*<\/Z>(([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$4<\/N>$6/g;
	s/(<T>[Aa]n<\/T> )<B><Z>()<N pl="n" gnt="n" gnd="m".><N pl="n" gnt="y" gnd="m".>(<V [^>]*t="foshuit".>)*<\/Z>(([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$4<\/N>$6/g;
	s/((<[^\/T][^>]*>[^<]+<\/[^T]>|<B><Z>(<[^T][^>]*>)+<\/Z>[^<]+<\/B>) (<N[^>]*[^>]*>[^<]+<\/N>|<B><Z>(<N[^>]*[^>]*>)+<\/Z>[^<]+<\/B>) <T>[Aa]n<\/T> )<B><Z>()<N pl="n" gnt="n" gnd="m".><N pl="n" gnt="y" gnd="m".>(<V [^>]*t="foshuit".>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$8<\/N>$9/g;
	s/()<B><Z>()<N pl="n" gnt="n" gnd="m".><N pl="n" gnt="y" gnd="m".>(<V [^>]*t="foshuit".>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$4<\/N>$5/g;
	s/(<T>na<\/T> )<B><Z>()<N pl="y" gnt="n" gnd="m"( h="y")?.><N pl="y" gnt="y" gnd="m"( h="y")?.><\/Z>((n(-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|bh[fF])[^<]*)<\/B>()/$1<N pl="y" gnt="y" gnd="m">$5<\/N>$8/g;
	s/()<B><Z>()<N pl="y" gnt="n" gnd="m"( h="y")?.><N pl="y" gnt="y" gnd="m"( h="y")?.><\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$5<\/N>$6/g;
	s/(<T>na<\/T> )<B><Z>()<N pl="y" gnt="n" gnd="f"( h="y")?.><N pl="y" gnt="y" gnd="f"( h="y")?.>(<A pl="n" gnt="y" gnd="f".>)?<\/Z>((n(-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|bh[fF])[^<]*)<\/B>()/$1<N pl="y" gnt="y" gnd="f">$6<\/N>$9/g;
	s/()<B><Z>()<N pl="y" gnt="n" gnd="f"( h="y")?.><N pl="y" gnt="y" gnd="f"( h="y")?.>(<A pl="n" gnt="y" gnd="f".>)?<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$6<\/N>$7/g;
	s/(<T>na<\/T> )<B><Z>()(<[^>]*>)*<N pl="n" gnt="y" gnd="f"( h="y")?.>(<[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="f">$6<\/N>$7/g;
	s/((<[^\/N][^>]*>[^<]+<\/[^N]>|<B><Z>(<[^N][^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>()<N pl="n" gnt="n" gnd="f"( h="y")?.><N pl="n" gnt="y" gnd="f"( h="y")?.><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$7<\/N>$8/g;
	s/()<B><Z>()<S.><C.><\/Z>([^<]+)<\/B>( (<[NP][^>]*>[^<]+<\/[NP]>|<B><Z>(<[NP][^>]*>)+<\/Z>[^<]+<\/B>))/$1<S>$3<\/S>$4/g;
	s/()<B><Z>()<S.><C.><\/Z>([^<]+)<\/B>( <T>na<\/T>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>()<S.><C.><\/Z>([^<]+)<\/B>( (<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>()<S.><C.><\/Z>([^<]+)<\/B>( (<[\/A-DF-Z][^>]*>)+seo<\/[A-DF-Z]>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>()<S.><C.><\/Z>([^<]+)<\/B>( (<[\/A-DF-Z][^>]*>)+sin<\/[A-DF-Z]>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>()<S.><C.><\/Z>([^<]+)<\/B>()/$1<C>$3<\/C>$4/g;
	s/()<B><Z>()<U.><C.><Q.><V cop="y".><\/Z>([^<]+)<\/B>( (<V[^>]*[^>]*>[^<]+<\/V>|<B><Z>(<V[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<U>$3<\/U>$4/g;
	s/()<B><Z>()<U.><C.><Q.><V cop="y".><\/Z>([^<]+)<\/B>()/$1<V cop="y">$3<\/V>$4/g;
	s/()<B><Z>()<V p="saor" t="caite".><V p="3\x{fa}" t="ord".><V p="3\x{fa}" t="gn\x{e1}th".><V pl="y" p="2\x{fa}" t="gn\x{e1}th".><\/Z>(([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+)<\/B>()/$1<V p="xx" t="gn\x{e1}th">$3<\/V>$5/g;
	s/()<B><Z>()<V p="3\x{fa}" t="ord".><V p="3\x{fa}" t="gn\x{e1}th".><V pl="y" p="2\x{fa}" t="gn\x{e1}th".><\/Z>([^<]+)<\/B>()/$1<V p="xx" t="gn\x{e1}th">$3<\/V>$4/g;
	s/()<B><Z>()<V pl="y" p="[13]\x{fa}" t="ord".><V pl="y" p="[13]\x{fa}" t="gn\x{e1}th".><\/Z>([^<]+)<\/B>()/$1<V p="xx" t="gn\x{e1}th">$3<\/V>$4/g;
	s/()<B><Z>()(<V[^>]* t="caite".>)*(<V p="2\x{fa}" t="ord".>)?(<V[^>]* t="caite".>)*<\/Z>([^<]+)<\/B>()/$1<V p="xx" t="caite">$6<\/V>$7/g;
	s/()<B><Z>()(<V[^>]* t="l\x{e1}ith".>)+<\/Z>([^<]+)<\/B>()/$1<V p="xx" t="l\x{e1}ith">$4<\/V>$5/g;
	s/()<B><Z>()(<V[^>]* t="f\x{e1}ist".>)+<\/Z>([^<]+)<\/B>()/$1<V p="xx" t="f\x{e1}ist">$4<\/V>$5/g;
	s/()<B><Z>()(<V[^>]* t="coinn".>)+<\/Z>([^<]+)<\/B>()/$1<V p="xx" t="coinn">$4<\/V>$5/g;
	s/()<B><Z>()(<V p="saor" t="ord".>)?<V p="saor" t="l\x{e1}ith".>(<V p="saor" t="foshuit".>)?<\/Z>([^<]+)<\/B>()/$1<V p="saor" t="l\x{e1}ith">$5<\/V>$6/g;
	s/()<B><Z>()<V p="saor" t="caite".><V p="3\x{fa}" t="ord".><\/Z>([^<]+)<\/B>()/$1<V p="saor" t="caite">$3<\/V>$4/g;
	s/()<B><Z>()<V p="1\x{fa}" t="ord".><V p="1\x{fa}" t="l\x{e1}ith".><\/Z>([^<]+)<\/B>()/$1<V p="1\x{fa}" t="l\x{e1}ith">$3<\/V>$4/g;
	s/()<B><Z>()(<V[^>]* t="foshuit".>)+<\/Z>([^<]+)<\/B>()/$1<V p="xx" t="foshuit">$4<\/V>$5/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]r)<\/B>( (<[\/A-DF-Z][^>]*>)+s[\x{e9}\x{ed}]<\/[A-DF-Z]>)/$1<V cop="y">$3<\/V>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]r)<\/B>( (<P[^>]*[^>]*>[^<]+<\/P>|<B><Z>(<P[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<V cop="y">$3<\/V>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]r)<\/B>( (<V[^>]*t="caite"[^>]*>[^<]+<\/V>|<B><Z>(<V[^>]*t="caite"[^>]*>)+<\/Z>[^<]+<\/B>))/$1<Q>$3<\/Q>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa]r)<\/B>()/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Dd]e)<\/B>( (<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]>)/$1<O>$3<\/O>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Dd]e)<\/B>( (<[CSR][^>]*>[^<]+<\/[CSR]>|<B><Z>(<[CSR][^>]*>)+<\/Z>[^<]+<\/B>))/$1<O>$3<\/O>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Dd]e)<\/B>()/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(gur)<\/B>( (<V[^>]*[^>]*>[^<]+<\/V>|<B><Z>(<V[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<C>$3<\/C>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(gur)<\/B>()/$1<V cop="y">$3<\/V>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(\x{d3})<\/B>( (<[\/A-DF-Z][^>]*>)+[A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]>)/$1<Y>$3<\/Y>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(\x{d3})<\/B>( <Y>[^<]+<\/Y>)/$1<Y>$3<\/Y>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([\x{d3}\x{f3}])<\/B>( (<V[^>]*[^>]*>[^<]+<\/V>|<B><Z>(<V[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<C>$3<\/C>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([\x{d3}\x{f3}])<\/B>()/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(N\x{ed})<\/B>( (<[\/A-DF-Z][^>]*>)+[A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]>)/$1<Y>$3<\/Y>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(N\x{ed})<\/B>( <Y>[^<]+<\/Y>)/$1<Y>$3<\/Y>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(N\x{ed})<\/B>()/$1<V cop="y">$3<\/V>$4/g;
	s/(<S>[^<]+<\/S> )<B><Z>()<P.><A pl="n" gnt="n".>(<A pl="n" gnt="y" gnd="m".>)?<\/Z>([^<]+)<\/B>()/$1<P>$4<\/P>$5/g;
	s/(<Q>[^<]+<\/Q> )<B><Z>()<P.><A pl="n" gnt="n".>(<A pl="n" gnt="y" gnd="m".>)?<\/Z>([^<]+)<\/B>()/$1<P>$4<\/P>$5/g;
	s/((<V[^>]*[^>]*>[^<]+<\/V>|<B><Z>(<V[^>]*[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>()<P.><A pl="n" gnt="n".>(<A pl="n" gnt="y" gnd="m".>)?<\/Z>([^<]+)<\/B>()/$1<P>$6<\/P>$7/g;
	s/(<C>[^<]+<\/C> )<B><Z>()<P.><A pl="n" gnt="n".>(<A pl="n" gnt="y" gnd="m".>)?<\/Z>([^<]+)<\/B>()/$1<P>$4<\/P>$5/g;
	s/()<B><Z>()<P.><A pl="n" gnt="n".>(<A pl="n" gnt="y" gnd="m".>)?<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$4<\/A>$5/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa])<\/B>( (<V[^>]*[^>]*>[^<]+<\/V>|<B><Z>(<V[^>]*[^>]*>)+<\/Z>[^<]+<\/B>))/$1<U>$3<\/U>$4/g;
	s/(<C>[Nn]uair<\/C> )<B><Z>(<[^>]*>)+<\/Z>([Aa])<\/B>()/$1<U>$3<\/U>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa])<\/B>( (<[\/A-DF-Z][^>]*>)+h[^<]+<\/[A-DF-Z]>)/$1<D>$3<\/D>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa])<\/B>( (<N[^>]*[^>]*>(n(-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|bh[fF])[^<]*<\/N>|<B><Z>(<N[^>]*[^>]*>)+<\/Z>(n(-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|bh[fF])[^<]*<\/B>))/$1<D>$3<\/D>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa])<\/B>( (<N[^>]*pl="y"[^>]*>[^<]+<\/N>|<B><Z>(<N[^>]*pl="y"[^>]*>)+<\/Z>[^<]+<\/B>))/$1<D>$3<\/D>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa])<\/B>( (<[\/A-DF-Z][^>]*>)+chlog<\/[A-DF-Z]>)/$1<U>$3<\/U>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa])<\/B>( (<[\/A-DF-Z][^>]*>)+ch\x{f3}ir<\/[A-DF-Z]>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa])<\/B>( (<[\/A-DF-Z][^>]*>)+dh\x{ed}th<\/[A-DF-Z]>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa])<\/B>( (<[\/A-DF-Z][^>]*>)+[^<]*(a[dm]h|i[nr]t|\x{e1}il|\x{fa})<\/[A-DF-Z]>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa])<\/B>( (<[\/A-DF-Z][^>]*>)+(bheith|cheannach|chur|dh\x{ed}ol|dhul|fhoghlaim|iompar|oscailt|r\x{e1}|roinnt|scr\x{ed}obh|theacht)<\/[A-DF-Z]>)/$1<S>$3<\/S>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Aa])<\/B>()/$1<D>$3<\/D>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>(d\x{f3})<\/B>()/$1<O>$3<\/O>$4/g;
	s/()<B><Z>(<[^>]*>)+<\/Z>([Ll]eis)<\/B>()/$1<O>$3<\/O>$4/g;
	s/()<B><Z>()<S.><O.><\/Z>([^<]+)<\/B>( <S>[^<]+<\/S>)/$1<O>$3<\/O>$4/g;
	s/()<B><Z>()<S.><O.><\/Z>([^<]+)<\/B>()/$1<S>$3<\/S>$4/g;
	}
}

sub comhshuite
{
	for ($_[0]) {
	s/(<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ch\x{e9}ile)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(l\x{e1}n)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(thiarcais)<\/[A-DF-Z]>/<I>$2 $4<\/I>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]gus)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(araile)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(aghaidh)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ais)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(athl\x{e1}imh)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(atr\x{e1}th)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bith)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bh\x{ed}thin)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bun)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ch\x{fa}l)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dearglasadh)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(deargmheisce)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(fad)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(f\x{e1}il)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(feadh)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(fud)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(leith)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(leithligh)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(liobarna)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(lorg)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(maos)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(nd\x{f3}igh)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(neamhchead)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(n\x{f3}s)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(si\x{fa}l)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(son)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(strae)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(tinneall)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(uairibh)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]rna)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(mh\x{e1}rach)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r\x{fa})<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(am\x{e1}rach)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r\x{fa})<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(anuraidh)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r\x{fa})<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ar\x{e9}ir)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Aa]r\x{fa})<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(inn\x{e9})<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+(m?[Bb]h?eo)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(beathach)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+(m?[Bb]h?\x{f3}\x{ed}n)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(D\x{e9})<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="f">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+(m?[Bb]h?r\x{ed}n)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(\x{f3}g)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+(m?[Bb]h?uaileam)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(sciath)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Cc]\x{e1}r)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bith)<\/[A-DF-Z]>/<Q>$2 $4<\/Q>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Cc]eannann)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(c\x{e9}anna)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Cc]heannann)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ch\x{e9}anna)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Cc]iolar)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(chiot)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="f">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Dd]h\x{e1})<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ch\x{e9}ad)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Tt]r\x{ed})<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ch\x{e9}ad)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Cc]eithre)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ch\x{e9}ad)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Cc]\x{fa}ig)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ch\x{e9}ad)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ss]\x{e9})<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ch\x{e9}ad)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+(g?[Cc]h?odladh)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(grif\x{ed}n)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="m">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+(g?[Cc]h?othrom)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(na)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+[Ff]\x{e9}inne<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="m">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Cc]hun)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(cinn)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Cc]hun)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(tosaigh)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Dd]ar)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(nd\x{f3}igh)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Dd][e\x{e1}])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bh\x{ed}thin)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Dd]\x{e1})<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(\x{e9}is)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Dd]allach)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dubh)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Dd]arb)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ainm)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bharr)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(chois)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ch\x{f3}ir)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dheasca)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dh\x{ed}obh\x{e1}il)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ghlanmheabhair)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(r\x{e9}ir)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(sciot\x{e1}n)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(thairbhe)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(thaisme)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+(h[Aa]on)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(d\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Dd]\x{f3})<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dh\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Tt]r\x{ed})<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(d\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Cc]eathair)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(d\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Cc]\x{fa}ig)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(d\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ss]\x{e9})<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(d\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ss]eacht)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(d\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Oo]cht)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(d\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Nn]aoi)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(d\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bhr\x{e1}id)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bhun)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(cheann)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(choinne)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(deara)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dh\x{e9}in)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dheoidh)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(l\x{e1}nseol)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(l\x{e1}thair)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+(Fear)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(Manach)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ff]\x{ed}orchaoin)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(f\x{e1}ilte)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ff]uta)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+([Ff]ata)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]ach)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(re)<\/[A-DF-Z]>/<A>$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]liog)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(gleag)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(br\x{e1}ch)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ceann)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(deo)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(d\x{ed}reach)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dt\x{ed})<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(feillbhinn)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(f\x{f3}ill)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(fras)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(h\x{e1}irithe)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(h\x{e9}ag)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(h\x{e9}asca)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(hioml\x{e1}n)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(l\x{e9}ir)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(leith)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(luath)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(minic)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(nuige)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(treis)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+(Hong)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(Cong)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bhf\x{e1}ch)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bhfad)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bhfeac)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bhfeidhm)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bhfeighil)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bhfianaise)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bhfochair)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bhfogas)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bhfolach)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dtaisce)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dteagmh\x{e1}il)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dteannta)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dt\x{f3}lamh)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dtr\x{e1}tha)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dtreis)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dtreo)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dtuilleama\x{ed})<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(gcaitheamh)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(gceartl\x{e1}r)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(gc\x{e9}in)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(gceist)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(gcionn)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(gcoinne)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(gc\x{f3}ir)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(gcoitinne)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(gcomhair)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(gcomhchlos)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(gcomhthr\x{e1}th)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(gc\x{f3}na\x{ed})<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(gcosamar)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(gcr\x{ed}ch)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(gcuideachta)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(l\x{e1}r)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(l\x{e1}thair)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(l\x{e9}ig)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(leith)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(mbliana)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(mbun)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(measc)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(nd\x{e1}ir\x{ed}re)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ndiaidh)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ngach)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ngan)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(rith)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(s\x{e1}inn)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(aghaidh)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(aice)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(aicearracht)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(airde)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(airicis)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(\x{e1}it)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ann)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(\x{e9}adan)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(\x{e9}ind\x{ed})<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(\x{e9}ineacht)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(imeacht)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ionad)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii]na)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(aice)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii]na)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ch?olgsheasamh)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ii]na)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(steillbheatha)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+(h?Inis)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(M\x{f3}r)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="f">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ll]e)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ch\x{e9}ile)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ll]e)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(cois)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ll]e)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(deireanas)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ll]e)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(feice\x{e1}il)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ll]e)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(haghaidh)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ll]e)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(hais)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ll]e)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(linn)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ll]i\x{fa}tar)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(\x{e9}atar)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+(Loch)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(Garman)<\/[A-DF-Z]>/<Y>$2 $4<\/Y>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ll]u\x{ed})<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(gaidhte)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="m">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ll]uthairt)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(lathairt)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Mm]h?ac)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(siobh\x{e1}in)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="m">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+(Mh?aigh)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(Eo)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Mm]ar)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dhea)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Mm]eacan)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ragaim)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="m">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Mm]ugadh)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(magadh)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+(na)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bhfud)<\/[A-DF-Z]>/<N pl="y" gnt="y" gnd="m">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Nn]\x{ed})<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(hamh\x{e1}in)<\/[A-DF-Z]>/<U>$2 $4<\/U>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Nn]\x{ed})<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(hamhlaidh)<\/[A-DF-Z]>/<U>$2 $4<\/U>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Nn]\x{ed})<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(hansa)<\/[A-DF-Z]>/<U>$2 $4<\/U>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Nn]i\x{fa}dar)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ne\x{e1}dar)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([\x{d3}\x{f3}])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(chianaibh)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([\x{d3}\x{f3}])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(dheas)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([\x{d3}\x{f3}])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(thuaidh)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([\x{d3}\x{f3}])<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(shin)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Oo]s)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(cionn)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Oo]s)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(coinne)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Oo]s)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(comhair)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Pp]linc)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(pleainc)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Rr]aiple)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(h\x{fa}ta)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Rr]ibe)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(r\x{f3}ib\x{e9}is)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="m">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Rr]ib\x{ed})<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(r\x{f3}ib\x{e9}is)<\/[A-DF-Z]>/<N pl="y" gnt="n" gnd="m">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+(Ros)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(Com\x{e1}in)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+(Ros)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(Muc)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Rr]uaille)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(buaille)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ss]a)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(treis)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ss]a)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(tsl\x{e1}nchruinne)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ss]an)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(\x{e1}ireamh)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ss]an)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(fhaopach)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ss]aochan)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(c\x{e9}ille)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="m">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ss]cun)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(scan)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ss]eo)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(caite)<\/[A-DF-Z]>/<A pl="n" gnt="n">$2 $4<\/A>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ss]i\x{fa}n)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(sinc\x{ed}n)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ss]pior)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(spear)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ss]teig)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(meig)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Ss]\x{fa}m)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(s\x{e1}m)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Tt]h?amhach)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(t\x{e1}isc)<\/[A-DF-Z]>/<N pl="n" gnt="n">$2 $4<\/N>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Tt]ar)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(\x{e9}is)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(ceann)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(f\x{f3}ir)<\/[A-DF-Z]>/<R>$2 $4<\/R>/g;
	s/(<[\/A-DF-Z][^>]*>)+([Tt]r\x{ed})<\/[A-DF-Z]> (<[\/A-DF-Z][^>]*>)+(bh\x{ed}thin)<\/[A-DF-Z]>/<S>$2 $4<\/S>/g;
	}
}

sub eisceacht
{
	for ($_[0]) {
	s/<E[^>]*>((<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+<\/N>) (<A[^>]*[^>]*>[^< ]+ [^<]+<\/A>))<\/E>/$1/g;
	s/<E[^>]*>(<U>[Aa]<\/U> (<V[^>]*t="caite"[^>]*>(nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<U>[Aa]<\/U> (<V[^>]*t="caite"[^>]*>(d\x{fa}i?r|rai?bh|fuai?r|fhac|dheach|dhearna)[^<]*<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<U>[Aa]<\/U> (<V[^>]*t="[flo][^o][^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<U>[Aa]<\/U> (<V[^>]*[^>]*>[Dd](eir|\x{e9}ar)[^<]*<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<D>[^<]*[A\x{c1}a\x{e1}]<\/D> (<N[^>]*h="y"[^>]*>[^<]+<\/N>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[^<]+<\/[A-DF-Z]> <[A-DF-Z][^>]*>[Aa]n<\/[A-DF-Z]> <[A-DF-Z][^>]*>m\x{e9}id<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<Q>[Aa]n<\/Q> (<A[^>]*[^>]*>[Mm]\x{f3}<\/A>))<\/E>/$1/g;
	s/<E[^>]*>(<T>[Aa]n<\/T> (<P[^>]*[^>]*>[Tt]\x{e9}<\/P>))<\/E>/$1/g;
	s/<E[^>]*>(<Q>[Aa]n<\/Q> (<V[^>]*t="caite"[^>]*>(nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>ar<\/[A-DF-Z]> <[A-DF-Z][^>]*>ar<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[^<]+<\/[A-DF-Z]> <[A-DF-Z][^>]*>bheith<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>bheith<\/[A-DF-Z]> <[A-DF-Z][^>]*>[^<]+<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Cc]\x{e1}<\/[A-DF-Z]> <[A-DF-Z][^>]*>(mhinice|fhad|mh\x{e9}ad)<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<Q>[Cc]\x{e1}<\/Q> (<N[^>]*h="y"[^>]*>[^<]+<\/N>))<\/E>/$1/g;
	s/<E[^>]*>(<Q>[Cc]\x{e1}<\/Q> (<V[^>]*t="caite"[^>]*>(nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Cc]\x{e9}<\/[A-DF-Z]> <[A-DF-Z][^>]*>ea<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>((<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+<\/N>) <[A-DF-Z][^>]*>c\x{e9}ad<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>([Cc]\x{e9}|[Nn]\x{ed}|[Ll]e|[Pp]\x{e9})<\/[A-DF-Z]> (<P[^>]*h="y"[^>]*>[^<]+<\/P>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>g?[Cc]h?eithre<\/[A-DF-Z]> <[A-DF-Z][^>]*>hairde<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<Q>[Cc]\x{e9}n<\/Q> (<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>t([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/N>))<\/E>/$1/g;
	s/<E[^>]*>(<U>[Cc]ha<\/U> (<V[^>]*t="caite"[^>]*>(raibh|dt\x{e1}inig|dtug|ndearnadh|gcuala|bhfuair)<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<U>[Cc]ha<\/U> (<V[^>]*t="[flo][^o][^>]*>([CcFfGgMmPpSs]h|[Bb]h[^fF])[^<]+<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Cc]homh<\/[A-DF-Z]> (<A[^>]*h="y"[^>]*>[^<]+<\/A>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>ciar\x{f3}g<\/[A-DF-Z]> <[A-DF-Z][^>]*>ciar\x{f3}g<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>deo<\/[A-DF-Z]> <[A-DF-Z][^>]*>deo<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Dd]ara<\/[A-DF-Z]> (<N[^>]*h="y"[^>]*>[^<]+<\/N>))<\/E>/$1/g;
	s/<E[^>]*>((<A[^>]*[^>]*>[^<][^<]*[^m]\x{fa}<\/A>) (<N[^>]*h="y"[^>]*>[^<]+<\/N>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Dd]h\x{e1}<\/[A-DF-Z]> (<N[^>]*h="y"[^>]*>[^<]+<\/N>))<\/E>/$1/g;
	s/<E[^>]*>((<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>[^<]+<\/N>) (<A[^>]*[^>]*>[Dd]h\x{e1}<\/A>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>do<\/[A-DF-Z]> <[A-DF-Z][^>]*>do<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[^<]+<\/[A-DF-Z]> <[A-DF-Z][^>]*>d\x{fa}(irt|ra[dm]ar|radh)<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>\x{e9}<\/[A-DF-Z]> <[A-DF-Z][^>]*>\x{e9}<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>fada<\/[A-DF-Z]> <[A-DF-Z][^>]*>fada<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[^<]+<\/[A-DF-Z]> <[A-DF-Z][^>]*>gach<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Gg]an<\/[A-DF-Z]> <[A-DF-Z][^>]*>fhios<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[^<]+<\/[A-DF-Z]> (<V[^>]*t="[flo][^o][^>]*>[Gg]heo[^<]+<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<S>[Gg]o dt\x{ed}<\/S> <T>[^<]+<\/T> (<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> <[A-DF-Z][^>]*>ch\x{e9}ile<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> (<A[^>]*h="y"[^>]*>[^<]+<\/A>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> (<N[^>]*h="y"[^>]*>[^<]+<\/N>))<\/E>/$1/g;
	s/<E[^>]*>(<C>[Gg]o<\/C> (<V[^>]*t="caite"[^>]*>(nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<S>[Ii]n<\/S> <D>[Bb]hur<\/D>)<\/E>/$1/g;
	s/<E[^>]*>(<S>[Ii]n<\/S> <[A-DF-Z][^>]*>[Dd]h\x{e1}<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Ll]e<\/[A-DF-Z]> <[A-DF-Z][^>]*>(bhur|[Cc]h\x{e9}ile|dh\x{e1})<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<S>([Ll]e|[Ss]na)<\/S> (<N[^>]*h="y"[^>]*>[^<]+<\/N>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>leor<\/[A-DF-Z]> <[A-DF-Z][^>]*>leor<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Mm]\x{e1}<\/[A-DF-Z]> (<V[^>]*t="[flo][^o][^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Mm]\x{e1}<\/[A-DF-Z]> (<V[^>]*t="[flo][^o][^>]*>[Dd](eir|\x{e9}ar)[^<]*<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Mm]\x{e1}<\/[A-DF-Z]> <[A-DF-Z][^>]*>t\x{e1}(i[dm]|imid|thar)?<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>m\x{e9}<\/[A-DF-Z]> <[A-DF-Z][^>]*>m\x{e9}<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>milli\x{fa}n<\/[A-DF-Z]> <[A-DF-Z][^>]*>milli\x{fa}n<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>m\x{f3}r<\/[A-DF-Z]> <[A-DF-Z][^>]*>m\x{f3}r<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<C>[Mm]ura<\/C> (<V[^>]*t="caite"[^>]*>(nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<T>[Nn]a<\/T> (<N[^>]*h="y"[^>]*>[^<]+<\/N>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Nn]\x{e1}<\/[A-DF-Z]> <[A-DF-Z][^>]*>is<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Nn]\x{e1}<\/[A-DF-Z]> <[A-DF-Z][^>]*>at\x{e1}(i[dm]|imid|thar)?<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Nn]\x{e1}<\/[A-DF-Z]> (<V[^>]*t="ord"[^>]*>h[^<]+<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Nn]ach<\/[A-DF-Z]> (<V[^>]*t="caite"[^>]*>(nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Nn]\x{ed}<\/[A-DF-Z]> <[A-DF-Z][^>]*>ba<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Nn]\x{ed}<\/[A-DF-Z]> (<V[^>]*t="caite"[^>]*>(bhfuai?r|d\x{fa}i?r|rai?bh|fhac|dheach|dhearna)[^<]*<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Nn]\x{ed}<\/[A-DF-Z]> (<V[^>]*[^>]*>bhfaigh[^<]+<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Nn]\x{ed}<\/[A-DF-Z]> (<V[^>]*t="[flo][^o][^>]*>[Dd](eir|\x{e9}ar)[^<]*<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Nn]\x{ed}<\/[A-DF-Z]> (<V[^>]*t="[flo][^o][^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Nn]\x{ed}<\/[A-DF-Z]> <[A-DF-Z][^>]*>hionann<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<C>[\x{d3}\x{f3}]<\/C> (<V[^>]*t="[flo][^o][^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/V>))<\/E>/$1/g;
	s/<E[^>]*>(<C>[\x{d3}\x{f3}]<\/C> <[A-DF-Z][^>]*>t\x{e1}(i[dm]|imid|thar)?<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[Ss]a<\/[A-DF-Z]> <[A-DF-Z][^>]*>m\x{e9}id<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>((<N[^>]*[^>]*>[Bb]h?eirte?<\/N>) (<N[^>]*[^>]*>[^<]+<\/N>) <[A-DF-Z][^>]*>seo<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>((<N[^>]*[^>]*>[^<]+<\/N>) <[A-DF-Z][^>]*>seo<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>sin<\/[A-DF-Z]> <[A-DF-Z][^>]*>sin<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>((<N[^>]*[^>]*>[Bb]h?eirte?<\/N>) (<N[^>]*[^>]*>[^<]+<\/N>) <[A-DF-Z][^>]*>sin<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>((<N[^>]*[^>]*>[^<]+<\/N>) <[A-DF-Z][^>]*>sin<\/[A-DF-Z]>)<\/E>/$1/g;
	s/<E[^>]*>(<C>[Ss]ula<\/C> (<V[^>]*t="caite"[^>]*>(nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>))<\/E>/$1/g;
	s/<E[^>]*>((<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>[^<]+<\/N>) (<A[^>]*[^>]*>[Tt]hoir<\/A>))<\/E>/$1/g;
	s/<E[^>]*>((<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>[^<]+<\/N>) (<A[^>]*[^>]*>[Tt]huasluaite<\/A>))<\/E>/$1/g;
	s/<E[^>]*>(<[A-DF-Z][^>]*>[^<]+<\/[A-DF-Z]> (<N[^>]*h="y"[^>]*>huaire<\/N>))<\/E>/$1/g;
	}
}

# analogue of "escape_punc" in bash version
sub giorr
{
	for ($_[0]) {
	s/^/ /;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9-][0-9])([.?!])/$1\\$2/g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9-][0-9][0-9])([.?!])/$1\\$2/g;
	s/(\...)([.?!])/$1\\$2/g;
	s/\.(ie|uk)\\([.?!])/.$1$2/g;
	s/(\..)([.?!])/$1\\$2/g;
	s/(\.)([.?!])/$1\\$2/g;
	s/([IVX][IVX])([.?!])/$1\\$2/g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-][A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-])([.?!])/$1\\$2/g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-][\x{e9}\x{ed}])\\([.?!])/$1$2/g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Aib)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Ath)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Beal)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]bl)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]B[nr])\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-][Cc]aib)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]c[cf])\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]C[dho])\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Cho)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]cit)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Dr)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Ea[gn])\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]etc)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Feabh)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Fig)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]F\x{f3}mh)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Fr)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]gCo)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]hor)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-][Ii]bid)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-][Ii]ml)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Inc)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]\x{cd}ocht)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Jr)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-][Ll][cg]h)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Ltd)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]L\x{fa}n)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]M\x{e1}r)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Meith)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]M[rs])\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Mrs)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-][Nn]o)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Noll)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]op)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]pp)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]rl)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Samh)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]sbh)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]S[crt])\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-][Ss][hpq])\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]srl)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]taesp)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]tAth)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]teil)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Teo)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]tr)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]tSr)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]tUas)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-]Uas)\./$1\\./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}'-][Uu]imh)\./$1\\./g;
	s/^ //;
	}
}

sub rialacha
{
	for ($_[0]) {
	s/(?<![<>])(<X>[^<]+<\/X>)(?![<>])/<E msg="ANAITHNID">$1<\/E>/g;
	s/(?<![<>])(<F>[^<]+<\/F>)(?![<>])/<E msg="NEAMHCHOIT">$1<\/E>/g;
	s/(?<![<>])(<S>[^< ]+ [^<]+<\/S> <T>[^<]+<\/T> (<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="GENITIVE">$1<\/E>/g;
	s/(?<![<>])(<S>([Cc]ois|[Dd]\x{e1}la|[Ff]earacht|[Tt]impeall|[Tt]rasna)<\/S> <T>[^<]+<\/T> (<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="GENITIVE">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[^<]+<\/[A-DF-Z]> (<A[^>]*h="y"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="NIAITCH">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[^<]+<\/[A-DF-Z]> (<P[^>]*h="y"[^>]*>[^<]+<\/P>))(?![<>])/<E msg="NIAITCH">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[^<]+<\/[A-DF-Z]> (<N[^>]*h="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="NIAITCH">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*[^>]*>[^<][^<]*[^m]\x{fa}<\/A>) (<N[^>]*[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*[^>]*>[Dd]ara<\/A>) (<N[^>]*[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[^<]+<\/[A-DF-Z]> (<V[^>]*t="ord"[^>]*>h[^<]+<\/V>))(?![<>])/<E msg="NIAITCH">$1<\/E>/g;
	s/(?<![<>])((<[^\/T][^>]*>[^<]+<\/[^T]>) (<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>t([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/N>))(?![<>])/<E msg="NITEE">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[^<]+<\/[A-DF-Z]> (<V[^>]*t="[flo][^o][^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/V>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+<\/N>) (<A[^>]*[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/A>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>) (<A[^>]*[^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/A>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>([^BbCcDdFfGgMmPpTt]|[Ss][^lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]*<\/N>) (<A[^>]*[^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/A>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*pl="y"[^>]*>[^<]*[e\x{e9}i\x{ed}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}<]+<\/N>) (<A[^>]*[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/A>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>a<\/S> (<N[^>]*[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<U>[Aa]<\/U> (<V[^>]*( p=.[^s]|t=..[^a])[^>]*>[BbCcDdFfGgPpTt][^hcCpPtT'][^<]*<\/V>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])((<V[^>]*[^>]*>[Aa]b<\/V>) <[A-DF-Z][^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]ch<\/S> (<N[^>]*[^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]ch<\/S> <T>an<\/T> (<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa][grs]<\/S> <T>an<\/T> (<N[^>]*[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa][gs]<\/S> (<N[^>]*[^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]mhail<\/S> (<N[^>]*[^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]mhail<\/S> <T>an<\/T> (<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<Q>[Aa]n<\/Q> (<V[^>]*[^>]*>([cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]+<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<Q>[Aa]n<\/Q> (<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{ar}">$1<\/E>/g;
	s/(?<![<>])((<[^\/S][^>]*>[^<]+<\/[^S]>) <T>an<\/T> (<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>([BbCcFfGgMmPp][^h']|bh[fF])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])((<[^\/S][^>]*>[^<]+<\/[^S]>) <T>an<\/T> (<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<T>[Aa]n<\/T> (<N[^>]*pl="n" gnt="y" gnd="m"[^>]*>([BbCcFfGgMmPp][^h']|bh[fF])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<T>[Aa]n<\/T> (<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]+<\/N>))(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<T>[Aa]n<\/T> (<N[^>]*pl="n" gnt="y" gnd="m"[^>]*>[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]+<\/N>))(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<T>[Aa]n<\/T> (<N[^>]*pl="n" gnt="y" gnd="f"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="BACHOIR{na}">$1<\/E>/g;
	s/(?<![<>])(<T>[Aa]n<\/T> (<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="BACHOIR{na}">$1<\/E>/g;
	s/(?<![<>])(<T>[^<]+<\/T> (<N[^>]*gnt="n"[^>]*>[^<]+<\/N>) <T>[^<]+<\/T> (<N[^>]*gnt="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="ONEART">$1<\/E>/g;
	s/(?<![<>])(<T>[^<]+<\/T> (<N[^>]*gnt="n"[^>]*>[^<]+<\/N>) (<A[^>]*[^>]*>gach<\/A>) (<N[^>]*gnt="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="ONEART">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Aa]on<\/[A-DF-Z]> (<N[^>]*[^>]*>([BbCcFfGgMmPp][^h']|bh[fF])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<Q>[Aa]r<\/Q> (<V[^>]*t="caite"[^>]*>(d\x{fa}i?r|rai?bh|fuai?r|fhac|dheach|dhearna)[^<]*<\/V>))(?![<>])/<E msg="BACHOIR{an}">$1<\/E>/g;
	s/(?<![<>])(<Q>[Aa]r<\/Q> (<V[^>]*( p=.[^s]|t=..[^a])[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<D>[\x{c1}\x{e1}]r<\/D> (<A[^>]*[^>]*>dh\x{e1}<\/A>) (<N[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<D>[\x{c1}\x{e1}]r<\/D> (<N[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])((<V[^>]*[^>]*>[Aa]rbh<\/V>) <[A-DF-Z][^>]*>[Ff][^h][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<D>[Aa]rna<\/D> <[A-DF-Z][^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])((<V[^>]*[^>]*>[Bb]a<\/V>) (<[^\/SP][^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/[^SP]>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])((<V[^>]*[^>]*>[Bb]a<\/V>) (<[AN][^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/[AN]>))(?![<>])/<E msg="BACHOIR{b+uascham\x{f3}g}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Bb]eirt<\/N>) (<N[^>]*[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Bb]h?eirte?<\/N>) (<N[^>]*[^>]*>[^<]+<\/N>) (<A[^>]*[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/A>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<D>[Bb]hur<\/D> <[A-DF-Z][^>]*>dh\x{e1}<\/[A-DF-Z]> (<N[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<D>[Bb]hur<\/D> <[A-DF-Z][^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e1}<\/Q> (<V[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e1}<\/Q> (<N[^>]*[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e1}<\/Q> (<N[^>]*[^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e1}<\/Q> (<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{c\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e1}r<\/Q> (<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{c\x{e1}}">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e1}r<\/Q> (<V[^>]*t="caite"[^>]*>(d\x{fa}i?r|rai?bh|fuai?r|fhac|dheach|dhearna)[^<]*<\/V>))(?![<>])/<E msg="BACHOIR{c\x{e1}}">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e1}r<\/Q> (<V[^>]*( p=.[^s]|t=..[^a])[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e9}<\/Q> <R>[Aa]r bith<\/R>)(?![<>])/<E msg="BACHOIR{cib\x{e9}}">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e9}<\/Q> (<N[^>]*[^>]*>bith<\/N>))(?![<>])/<E msg="BACHOIR{cib\x{e9}}">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e9}<\/Q> (<N[^>]*[^>]*>rud<\/N>))(?![<>])/<E msg="BACHOIR{c\x{e9}ard}">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e9}<\/Q> (<P[^>]*[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/P>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e9}<\/Q> <T>an<\/T>)(?![<>])/<E msg="BACHOIR{c\x{e9}n}">$1<\/E>/g;
	s/(?<![<>])(<T>[^<]+<\/T> (<A[^>]*[^>]*>c\x{e9}ad<\/A>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]na<\/S> (<A[^>]*[^>]*>c\x{e9}ad<\/A>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<D>[Aa]<\/D> (<A[^>]*[^>]*>c\x{e9}ad<\/A>) (<N[^>]*[^>]*>([BbCcFfGgMmPp][^h']|bh[fF])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Cc]eithre<\/[A-DF-Z]> <[A-DF-Z][^>]*>uaire?<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{huaire}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Cc]eithre<\/[A-DF-Z]> (<N[^>]*pl="n" gnt="n"[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e9}n<\/Q> (<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]ha<\/U> <[A-DF-Z][^>]*>([BbCcFfGgMmPp][^h']|bh[fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]ha<\/U> <[A-DF-Z][^>]*>[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]ha<\/U> <[A-DF-Z][^>]*>([tT]|d[^Tt'])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]ha<\/U> <[A-DF-Z][^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{chan}">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]ha<\/U> (<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{char}">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]har<\/U> (<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{cha}">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]har<\/U> (<V[^>]*t="caite"[^>]*>(d\x{fa}i?r|rai?bh|fuai?r|fhac|dheach|dhearna)[^<]*<\/V>))(?![<>])/<E msg="BACHOIR{cha}">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]har<\/U> (<V[^>]*( p=.[^s]|t=..[^a])[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]ha<\/U> <[A-DF-Z][^>]*>ar<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{char}">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]ha<\/U> <[A-DF-Z][^>]*>arbh<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{charbh}">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*[^>]*>[Cc]h\x{e9}ad<\/A>) (<N[^>]*[^>]*>([BbCcFfGgMmPp][^h']|bh[fF])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<R>[Cc]homh<\/R> (<A[^>]*[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/A>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<S>[Cc]huig<\/S> <T>an<\/T> (<N[^>]*[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Cc]huig<\/S> (<N[^>]*[^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Cc]hun<\/[A-DF-Z]> (<N[^>]*[^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Cc]\x{fa}ig<\/[A-DF-Z]> (<N[^>]*pl="n" gnt="n"[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<C>[Dd]\x{e1}<\/C> (<V[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<S>[Dd]ar<\/S> <T>an<\/T> (<N[^>]*[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Dd]ar<\/S> (<N[^>]*[^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<D>[Dd]\x{e1}r<\/D> <[A-DF-Z][^>]*>dh\x{e1}<\/[A-DF-Z]> (<N[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<D>[Dd]\x{e1}r<\/D> <[A-DF-Z][^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])((<V[^>]*[^>]*>n?[Dd]h?\x{e9}anadh<\/V>))(?![<>])/<E msg="CAIGHDEAN{rinneadh, d\x{e9}anamh}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>D\x{e9}<\/[A-DF-Z]> <[A-DF-Z][^>]*>Aoine<\/[A-DF-Z]>)(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]eich<\/[A-DF-Z]> (<N[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd][eo]<\/[A-DF-Z]> (<N[^>]*[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd][eo]n<\/[A-DF-Z]> (<N[^>]*[^>]*>([BbCcFfGgMmPp][^h']|bh[fF])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]e<\/[A-DF-Z]> <T>an<\/T>)(?![<>])/<E msg="BACHOIR{den}">$1<\/E>/g;
	s/(?<![<>])((<[^\/D][^>]*>[^<]+<\/[^D]>) <[A-DF-Z][^>]*>[Dd]h\x{e1}<\/[A-DF-Z]> <[A-DF-Z][^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]o<\/[A-DF-Z]> <T>an<\/T>)(?![<>])/<E msg="BACHOIR{don}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd][eo]<\/[A-DF-Z]> (<N[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/N>))(?![<>])/<E msg="BACHOIR{d+uascham\x{f3}g}">$1<\/E>/g;
	s/(?<![<>])(<S>[Dd]e<\/S> <[A-DF-Z][^>]*>ar<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{d\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]o<\/[A-DF-Z]> <[A-DF-Z][^>]*>a<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{d\x{e1}}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]o<\/[A-DF-Z]> <[A-DF-Z][^>]*>ar<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{d\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd][eo]<\/[A-DF-Z]> <[A-DF-Z][^>]*>\x{e1}r<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{d\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]\x{f3}<\/[A-DF-Z]> <[A-DF-Z][^>]*>d\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<D>[Dd]o<\/D> <[A-DF-Z][^>]*>dh\x{e1}<\/[A-DF-Z]> <[A-DF-Z][^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ff]aoi<\/S> (<N[^>]*[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ff]aoi<\/S> <T>an<\/T>)(?![<>])/<E msg="BACHOIR{faoin}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Ff]aoi<\/[A-DF-Z]> <[A-DF-Z][^>]*>a<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{faoina}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Ff]aoi<\/[A-DF-Z]> <[A-DF-Z][^>]*>\x{e1}r<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{faoin\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ff]aoin<\/S> (<N[^>]*[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<D>[Ff]aoin\x{e1}r<\/D> <[A-DF-Z][^>]*>dh\x{e1}<\/[A-DF-Z]> (<N[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<D>[Ff]aoin\x{e1}r<\/D> <[A-DF-Z][^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>Fh?\x{e9}ile<\/[A-DF-Z]> <Y>[BCDFGMPST]h[^<]+<\/Y>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*[^>]*>firinne<\/A>))(?![<>])/<E msg="NEAMHCHOIT">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>fr\x{ed}d<\/N>))(?![<>])/<E msg="CAIGHDEAN{tr\x{ed}, tr\x{ed}d}">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> (<N[^>]*[^>]*>[DdFfSsTt]h[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> <Y>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/Y>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> <T>an<\/T> (<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> (<[AN][^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[AN]>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> (<V[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> (<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{gur}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> (<N[^>]*[^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> <T>[^<]+<\/T>)(?![<>])/<E msg="BACHOIR{go dt\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]o dt\x{ed}<\/S> (<N[^>]*[^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<C>[Gg]ur<\/C> (<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{go}">$1<\/E>/g;
	s/(?<![<>])(<C>[Gg]ur<\/C> (<V[^>]*t="caite"[^>]*>(d\x{fa}i?r|rai?bh|fuai?r|fhac|dheach|dhearna)[^<]*<\/V>))(?![<>])/<E msg="BACHOIR{go}">$1<\/E>/g;
	s/(?<![<>])(<C>[Gg]ur<\/C> (<V[^>]*( p=.[^s]|t=..[^a])[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])((<V[^>]*[^>]*>[Gg]urbh<\/V>) <[A-DF-Z][^>]*>[Ff][^h][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> (<N[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> <D>[Bb]hur<\/D>)(?![<>])/<E msg="BACHOIR{in bhur}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> <[A-DF-Z][^>]*>[Dd]h\x{e1}<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{in dh\x{e1}}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> <[A-DF-Z][^>]*>[Aa]n<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{sa}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> <[A-DF-Z][^>]*>[Nn]a<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{sna}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> <[A-DF-Z][^>]*>a<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{ina}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> <[A-DF-Z][^>]*>ar<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{inar}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> <D>\x{e1}r<\/D>)(?![<>])/<E msg="BACHOIR{in\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]n<\/S> <[A-DF-Z][^>]*>[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{i}">$1<\/E>/g;
	s/(?<![<>])(<D>[Ii]n\x{e1}r<\/D> <[A-DF-Z][^>]*>dh\x{e1}<\/[A-DF-Z]> (<N[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<D>[Ii]n\x{e1}r<\/D> <[A-DF-Z][^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]onsar<\/S> <T>an<\/T> (<N[^>]*[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]e<\/S> (<N[^>]*[^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]e<\/S> <T>an<\/T>)(?![<>])/<E msg="BACHOIR{leis an}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]e<\/S> <T>na<\/T>)(?![<>])/<E msg="BACHOIR{leis na}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]e<\/S> <[A-DF-Z][^>]*>a<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{lena}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]e<\/S> <[A-DF-Z][^>]*>ar<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{lenar}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]e<\/S> <[A-DF-Z][^>]*>\x{e1}r<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{len\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]e<\/S> (<[ANP][^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[ANP]>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]eis<\/S> <T>an<\/T> (<N[^>]*[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<D>[Ll]en\x{e1}r<\/D> <[A-DF-Z][^>]*>dh\x{e1}<\/[A-DF-Z]> (<N[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<D>[Ll]en\x{e1}r<\/D> <[A-DF-Z][^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<C>[Mm]\x{e1}<\/C> (<V[^>]*( p=.[^s]|t=..[^a])[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Mm]ar<\/S> (<N[^>]*[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<D>[Mm]o<\/D> <[A-DF-Z][^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{m+uascham\x{f3}g}">$1<\/E>/g;
	s/(?<![<>])(<D>[Mm]o<\/D> <[A-DF-Z][^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<D>[Mm]o<\/D> <[A-DF-Z][^>]*>dh\x{e1}<\/[A-DF-Z]> <[A-DF-Z][^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<C>[Mm]ura<\/C> (<V[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<C>[Mm]ura<\/C> (<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{murar}">$1<\/E>/g;
	s/(?<![<>])(<C>[Mm]urach<\/C> (<N[^>]*[^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<C>[Mm]urar<\/C> (<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{mura}">$1<\/E>/g;
	s/(?<![<>])(<C>[Mm]urar<\/C> (<V[^>]*t="caite"[^>]*>(d\x{fa}i?r|rai?bh|fuai?r|fhac|dheach|dhearna)[^<]*<\/V>))(?![<>])/<E msg="BACHOIR{mura}">$1<\/E>/g;
	s/(?<![<>])(<C>[Mm]urar<\/C> (<V[^>]*( p=.[^s]|t=..[^a])[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<T>na<\/T> (<N[^>]*pl="y" gnt="y"[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<T>na<\/T> (<N[^>]*pl="n" gnt="y" gnd="f"[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<T>na<\/T> (<N[^>]*pl="y" gnt="n"[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{e1}<\/[A-DF-Z]> (<V[^>]*[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/V>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{e1}<\/[A-DF-Z]> (<N[^>]*[^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]ach<\/[A-DF-Z]> (<V[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]ach<\/[A-DF-Z]> (<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{n\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])((<[^\/Y][^>]*>[Nn]aoi<\/[^Y]>) (<N[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>Naomh<\/N>) <[A-DF-Z][^>]*>[BCDFGMPST]h[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{e1}r<\/[A-DF-Z]> (<V[^>]*t=".[^a][^s][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{nach}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{e1}r<\/[A-DF-Z]> (<[AN][^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/[AN]>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{e1}r<\/[A-DF-Z]> (<V[^>]*( p=.[^s]|t=..[^a])[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])((<V[^>]*[^>]*>[Nn]\x{e1}rbh<\/V>) <[A-DF-Z][^>]*>[Ff][^h][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<U>[Nn]\x{ed}<\/U> (<V[^>]*[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{ed}<\/[A-DF-Z]> (<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{n\x{ed}or}">$1<\/E>/g;
	s/(?<![<>])((<V[^>]*[^>]*>[Nn]\x{ed}<\/V>) (<P[^>]*[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/P>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}ba?<\/R> (<A[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="BREISCHEIM">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}ba?<\/R> (<A[^>]*pl="n" gnt="y" gnd="m"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="BREISCHEIM">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}ba?<\/R> (<A[^>]*pl="y"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="BREISCHEIM">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}ba?<\/R> (<[^\/A][^>]*>[^<]+<\/[^A]>))(?![<>])/<E msg="BREISCHEIM">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}ba<\/R> (<A[^>]*pl="n" gnt="y" gnd="f"[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/A>))(?![<>])/<E msg="BACHOIR{n\x{ed}b}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}ba<\/R> (<A[^>]*pl="n" gnt="y" gnd="f"[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/A>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{ed}or<\/[A-DF-Z]> (<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{n\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{ed}or<\/[A-DF-Z]> (<V[^>]*t="caite"[^>]*>(d\x{fa}i?r|rai?bh|fuai?r|fhac|dheach|dhearna)[^<]*<\/V>))(?![<>])/<E msg="BACHOIR{n\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{ed}or<\/[A-DF-Z]> (<[AN][^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/[AN]>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{ed}or<\/[A-DF-Z]> (<V[^>]*( p=.[^s]|t=..[^a])[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])((<V[^>]*[^>]*>[Nn]\x{ed}orbh<\/V>) <[A-DF-Z][^>]*>[Ff][^h][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}os<\/R> (<A[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="BREISCHEIM">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}os<\/R> (<A[^>]*pl="n" gnt="y" gnd="m"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="BREISCHEIM">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}os<\/R> (<A[^>]*pl="y"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="BREISCHEIM">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}os<\/R> (<[^\/A][^>]*>[^<]+<\/[^A]>))(?![<>])/<E msg="BREISCHEIM">$1<\/E>/g;
	s/(?<![<>])(<C>[\x{d3}\x{f3}]<\/C> (<V[^>]*( p=.[^s]|t=..[^a])[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[\x{d3}\x{f3}]<\/S> (<N[^>]*[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[\x{d3}\x{f3}]<\/S> <T>an<\/T>)(?![<>])/<E msg="BACHOIR{\x{f3}n}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Oo]cht<\/[A-DF-Z]> (<N[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<S>[\x{d3}\x{f3}]n<\/S> (<N[^>]*[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[\x{d3}\x{f3}]n?<\/S> <[A-DF-Z][^>]*>a<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{\x{f3}na}">$1<\/E>/g;
	s/(?<![<>])(<S>[\x{d3}\x{f3}]n?<\/S> <[A-DF-Z][^>]*>ar<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{\x{f3}nar}">$1<\/E>/g;
	s/(?<![<>])(<S>[\x{d3}\x{f3}]n?<\/S> <[A-DF-Z][^>]*>\x{e1}r<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{\x{f3}n\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<D>[\x{d3}\x{f3}]n\x{e1}r<\/D> <[A-DF-Z][^>]*>dh\x{e1}<\/[A-DF-Z]> (<N[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<D>[\x{d3}\x{f3}]n\x{e1}r<\/D> <[A-DF-Z][^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Oo]s<\/[A-DF-Z]> (<N[^>]*[^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])((<P[^>]*[^>]*>[Pp]\x{e9}<\/P>) (<P[^>]*[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/P>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<S>[Rr]oimh<\/S> <T>an<\/T> (<N[^>]*[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Rr]oimh<\/S> (<N[^>]*[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]a<\/S> <[A-DF-Z][^>]*>([BbCcGgMmPp][^h']|bh[fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]a<\/S> (<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]+<\/N>))(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>San<\/N>) <[A-DF-Z][^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]an<\/S> <[A-DF-Z][^>]*>[Ff][^h][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]a<\/S> <[A-DF-Z][^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{san}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]an<\/S> <[A-DF-Z][^>]*>[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}Ff][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{sa}">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*[^>]*>[Ss]\x{e9}<\/A>) <[A-DF-Z][^>]*>uaire?<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{huaire}">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*[^>]*>[Ss]\x{e9}<\/A>) (<N[^>]*pl="n" gnt="n"[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]eachas<\/S> (<N[^>]*[^>]*>([CcDdFfGgMmPpSsTt]h|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]eachas<\/S> <T>an<\/T> (<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Ss]eacht<\/[A-DF-Z]> (<N[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]na<\/S> (<N[^>]*pl="y" gnt="n"[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<C>[Ss]ula<\/C> <[A-DF-Z][^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<C>[Ss]ula<\/C> (<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{sular}">$1<\/E>/g;
	s/(?<![<>])(<C>[Ss]ular<\/C> (<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{sula}">$1<\/E>/g;
	s/(?<![<>])(<C>[Ss]ular<\/C> (<V[^>]*t="caite"[^>]*>(d\x{fa}i?r|rai?bh|fuai?r|fhac|dheach|dhearna)[^<]*<\/V>))(?![<>])/<E msg="BACHOIR{sula}">$1<\/E>/g;
	s/(?<![<>])(<C>[Ss]ular<\/C> (<V[^>]*( p=.[^s]|t=..[^a])[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Tt]har<\/[A-DF-Z]> <T>an<\/T> (<N[^>]*[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Tt]r\x{ed}<\/[A-DF-Z]> <[A-DF-Z][^>]*>uaire?<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{huaire}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> (<[^\/U][^>]*>a<\/[^U]>))(?![<>])/<E msg="BACHOIR{tr\x{ed}na}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> <[A-DF-Z][^>]*>ar<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{tr\x{ed}nar}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> <T>an<\/T>)(?![<>])/<E msg="BACHOIR{tr\x{ed}d an}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> <D>\x{e1}r<\/D>)(?![<>])/<E msg="BACHOIR{tr\x{ed}n\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Tt]r\x{ed}<\/[A-DF-Z]> (<N[^>]*pl="n" gnt="n"[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}d<\/S> <T>an<\/T> (<N[^>]*[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}d<\/S> <T>na<\/T>)(?![<>])/<E msg="BACHOIR{tr\x{ed} na}">$1<\/E>/g;
	s/(?<![<>])(<D>[Tt]r\x{ed}n\x{e1}r<\/D> <[A-DF-Z][^>]*>dh\x{e1}<\/[A-DF-Z]> (<N[^>]*[^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<D>[Tt]r\x{ed}n\x{e1}r<\/D> <[A-DF-Z][^>]*>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|d[^Tt']|g[^Cc]|b[^Pph]|bh[^fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<S>[Uu]m<\/S> (<N[^>]*[^>]*>([BbCcDdFfGgMmPpTt][^h']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Uu]m<\/S> <T>an<\/T> (<N[^>]*[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<T>[^<]+<\/T> (<A[^>]*pl="y"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<T>[^<]+<\/T> (<[^\/AFNXY][^>]*>[^<]+<\/[^AFNXY]>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<R>[^<]+<\/R> (<A[^>]*pl="y"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<Q>[^<]+<\/Q> (<A[^>]*pl="n" gnt="y" gnd="f"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<Q>[^<]+<\/Q> (<A[^>]*pl="y"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<Q>[^<]+<\/Q> <Q>[^<]+<\/Q>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<Q>[^<]+<\/Q> (<N[^>]*GS[^>]*>[^<]+<\/N>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])((<P[^>]*[^>]*>[^<]+<\/P>) (<A[^>]*pl="y"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])((<P[^>]*[^>]*>[^<]+<\/P>) (<A[^>]*pl="n" gnt="y" gnd="f"[^>]*>([^b]|b[^'])[^<]+<\/A>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])((<O[^>]*[^>]*>[^<]+<\/O>) (<A[^>]*pl="y"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])((<O[^>]*[^>]*>[^<]+<\/O>) (<A[^>]*pl="n" gnt="y" gnd="f"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*pl="n" gnt="y" gnd="m"[^>]*>[^<]+<\/N>) (<A[^>]*pl="n" gnt="y" gnd="f"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*pl="n" gnt="y" gnd="f"[^>]*>[^<]+<\/N>) (<A[^>]*pl="n" gnt="y" gnd="m"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<D>[^<]+<\/D> (<A[^>]*pl="y"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<D>[^<]+<\/D> <C>[^<]+<\/C>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<D>[^<]+<\/D> <D>[^<]+<\/D>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<D>[^<]+<\/D> (<O[^>]*[^>]*>[^<]+<\/O>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<D>[^<]+<\/D> (<P[^>]*[^>]*>[^<]+<\/P>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<D>[^<]+<\/D> <Q>[^<]+<\/Q>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<D>[^<]+<\/D> <T>[^<]+<\/T>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*pl="y"[^>]*>[^<]+<\/A>) (<A[^>]*pl="n" gnt="y" gnd="f"[^>]*>([^b]|b[^'])[^<]+<\/A>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*pl="n" gnt="y" gnd="f"[^>]*>[^<]+<\/A>) (<A[^>]*pl="y"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/A>) (<A[^>]*pl="n" gnt="y" gnd="f"[^>]*>[^<]+<\/A>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Aa]ice<\/N>))(?![<>])/<E msg="INPHRASE{in aice}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Aa]icearracht<\/N>))(?![<>])/<E msg="INPHRASE{in aicearracht}">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*[^>]*>h?[Aa]raile<\/A>))(?![<>])/<E msg="INPHRASE{agus araile}">$1<\/E>/g;
	s/(?<![<>])(<R>[Aa]r\x{fa}<\/R>)(?![<>])/<E msg="INPHRASE{ar\x{fa} am\x{e1}rach,anuraidh,ar\x{e9}ir,inn\x{e9}}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Aa]thl\x{e1}imh<\/N>))(?![<>])/<E msg="INPHRASE{ar athl\x{e1}imh}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Aa]tr\x{e1}th<\/N>))(?![<>])/<E msg="INPHRASE{ar atr\x{e1}th}">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*[^>]*>m?[Bb]h?eathach<\/A>))(?![<>])/<E msg="INPHRASE{beo beathach}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>m?[Bb]h?ith<\/N>))(?![<>])/<E msg="INPHRASE{ar bith, c\x{e1}r bith}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Bb]h?\x{ed}thin<\/N>))(?![<>])/<E msg="INPHRASE{tr\x{ed} bh\x{ed}thin, de bh\x{ed}thin}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>m?[Bb]h?\x{f3}\x{ed}n<\/N>))(?![<>])/<E msg="INPHRASE{b\x{f3}\x{ed}n D\x{e9}}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Bb]r\x{e1}ch<\/N>))(?![<>])/<E msg="INPHRASE{go br\x{e1}ch}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>m?[Bb]h?r\x{ed}n<\/N>))(?![<>])/<E msg="INPHRASE{br\x{ed}n \x{f3}g}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>m?[Bb]h?uaileam<\/N>))(?![<>])/<E msg="INPHRASE{buaileam sciath}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>g?[Cc]h?eannann<\/N>))(?![<>])/<E msg="INPHRASE{ceannann c\x{e9}anna}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>g[Cc]eartl\x{e1}r<\/N>))(?![<>])/<E msg="INPHRASE{i gceartl\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>g[Cc]\x{e9}in<\/N>))(?![<>])/<E msg="INPHRASE{i gc\x{e9}in}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>g[Cc]oitinne<\/N>))(?![<>])/<E msg="INPHRASE{i gcoitinne}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>g[Cc]r\x{ed}ch<\/N>))(?![<>])/<E msg="INPHRASE{i gcr\x{ed}ch}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>g?[Cc]h?ianaibh<\/N>))(?![<>])/<E msg="INPHRASE{\x{f3} chianaibh}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>g?[Cc]h?iolar<\/N>))(?![<>])/<E msg="INPHRASE{ciolar chiot}">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]hiot<\/U>)(?![<>])/<E msg="INPHRASE{ciolar chiot}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>g?[Cc]h?olgsheasamh<\/N>))(?![<>])/<E msg="INPHRASE{ina cholgsheasamh}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>g?[Cc]h?omhchlos<\/N>))(?![<>])/<E msg="INPHRASE{i gcomhchlos}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>g?[Cc]h?omhthr\x{e1}th<\/N>))(?![<>])/<E msg="INPHRASE{i gcomhthr\x{e1}th}">$1<\/E>/g;
	s/(?<![<>])(<S>[Dd]arb<\/S>)(?![<>])/<E msg="INPHRASE{darb ainm}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>n?[Dd]h?allach<\/N>))(?![<>])/<E msg="INPHRASE{dallach dubh}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>n?[Dd]h?eara<\/N>))(?![<>])/<E msg="INPHRASE{faoi deara}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Dd]hea<\/N>))(?![<>])/<E msg="INPHRASE{mar dhea}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>n?[Dd]h?earglasadh<\/N>))(?![<>])/<E msg="INPHRASE{ar dearglasadh}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>n?[Dd]h?eargmheisce<\/N>))(?![<>])/<E msg="INPHRASE{ar deargmheisce}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Dd]eo<\/N>))(?![<>])/<E msg="INPHRASE{go deo}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Dd]heoidh<\/N>))(?![<>])/<E msg="INPHRASE{faoi dheoidh}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>nd\x{f3}igh<\/N>))(?![<>])/<E msg="INPHRASE{ar nd\x{f3}igh}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[\x{c9}\x{e9}]atar<\/N>))(?![<>])/<E msg="INPHRASE{li\x{fa}tar \x{e9}atar}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[\x{c9}\x{e9}]ind\x{ed}<\/N>))(?![<>])/<E msg="INPHRASE{in \x{e9}ind\x{ed}}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[\x{c9}\x{e9}]ineacht<\/N>))(?![<>])/<E msg="INPHRASE{in \x{e9}ineacht}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[\x{c9}\x{e9}]is<\/N>))(?![<>])/<E msg="INPHRASE{tar \x{e9}is, d\x{e1} \x{e9}is}">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*[^>]*>(bh)?[Ff]h?\x{e1}ch<\/A>))(?![<>])/<E msg="INPHRASE{i bhf\x{e1}ch}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>(bh)?[Ff]h?aopach<\/N>))(?![<>])/<E msg="INPHRASE{san fhaopach}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>bh[Ff]ud<\/N>))(?![<>])/<E msg="INPHRASE{ar fud na bhfud}">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*[^>]*>[Ff]eilbhinn<\/A>))(?![<>])/<E msg="INPHRASE{go feillbhinn}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Ff]\x{ed}orchaoin<\/N>))(?![<>])/<E msg="INPHRASE{f\x{ed}orchaoin f\x{e1}ilte}">$1<\/E>/g;
	s/(?<![<>])((bh)?[Ff]h?ogas)(?![<>])/<E msg="INPHRASE{i bhfogas}">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*[^>]*>[Ff]\x{f3}ill<\/A>))(?![<>])/<E msg="INPHRASE{go f\x{f3}ill}">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*[^>]*>[Ff]ras<\/A>))(?![<>])/<E msg="INPHRASE{go fras}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Ff][ua]ta<\/N>))(?![<>])/<E msg="INPHRASE{futa fata}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Ff]ud<\/N>))(?![<>])/<E msg="INPHRASE{ar fud}">$1<\/E>/g;
	s/(?<![<>])(<R>[Gg]aidhte<\/R>)(?![<>])/<E msg="INPHRASE{lu\x{ed} gaidhte}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>n?[Gg]h?arman<\/N>))(?![<>])/<E msg="INPHRASE{Loch Garman}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>n?[Gg]h?lanmheabhair<\/N>))(?![<>])/<E msg="INPHRASE{de ghlanmheabhair}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Gg]leag<\/N>))(?![<>])/<E msg="INPHRASE{gliog gleag}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Gg]rif\x{ed}n<\/N>))(?![<>])/<E msg="INPHRASE{codladh grif\x{ed}n}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>h\x{e1}irithe<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{go h\x{e1}irithe}">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*[^>]*>hamh\x{e1}in<\/A>))(?![<>])/<E msg="INPHRASE{n\x{ed} hamh\x{e1}in}">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*[^>]*>hamhlaidh<\/A>))(?![<>])/<E msg="INPHRASE{n\x{ed} hamhlaidh}">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*[^>]*>hansa<\/A>))(?![<>])/<E msg="INPHRASE{n\x{ed} hansa}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[HC]ong<\/N>))(?![<>])/<E msg="INPHRASE{Hong Cong}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Hh]\x{fa}ta<\/N>))(?![<>])/<E msg="INPHRASE{raiple h\x{fa}ta}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Ll]\x{e1}nseol<\/N>))(?![<>])/<E msg="INPHRASE{faoi l\x{e1}nseol}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Ll]\x{e9}ig<\/N>))(?![<>])/<E msg="INPHRASE{i l\x{e9}ig}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Ll]eithligh<\/N>))(?![<>])/<E msg="INPHRASE{ar leithligh}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Ll]iobarna<\/N>))(?![<>])/<E msg="INPHRASE{ar liobarna}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>li\x{fa}tar<\/N>))(?![<>])/<E msg="INPHRASE{li\x{fa}tar \x{e9}atar}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Ll]uthairt<\/N>))(?![<>])/<E msg="INPHRASE{luthairt lathairt}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Mm]aos<\/N>))(?![<>])/<E msg="INPHRASE{ar maos}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Mm]h\x{e1}rach<\/N>))(?![<>])/<E msg="INPHRASE{arna mh\x{e1}rach}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Mm]ugadh<\/N>))(?![<>])/<E msg="INPHRASE{mugadh magadh}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>nd\x{e1}ir\x{ed}re<\/N>))(?![<>])/<E msg="INPHRASE{i nd\x{e1}ir\x{ed}re}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Nn]eamhchead<\/N>))(?![<>])/<E msg="INPHRASE{ar neamhchead}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>n[gG]ach<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{i ngach}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>n[gG]an<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{i ngan}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Nn][ie][\x{e1}\x{fa}]dar<\/N>))(?![<>])/<E msg="INPHRASE{ni\x{fa}dar ne\x{e1}dar}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]uige<\/R>)(?![<>])/<E msg="INPHRASE{go nuige}">$1<\/E>/g;
	s/(?<![<>])(<R>[Pp]l(ea)?inc<\/R>)(?![<>])/<E msg="INPHRASE{plinc pleainc}">$1<\/E>/g;
	s/(?<![<>])(<U>[Rr]agaim<\/U>)(?![<>])/<E msg="INPHRASE{meacan ragaim}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Rr]aiple<\/N>))(?![<>])/<E msg="INPHRASE{raiple h\x{fa}ta}">$1<\/E>/g;
	s/(?<![<>])(<U>[Rr]e<\/U>)(?![<>])/<E msg="INPHRASE{gach re}">$1<\/E>/g;
	s/(?<![<>])(<U>[Rr]\x{f3}ib\x{e9}is<\/U>)(?![<>])/<E msg="INPHRASE{ribe r\x{f3}ib\x{e9}is}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[RrBb]uaille<\/N>))(?![<>])/<E msg="INPHRASE{ruaille buaille}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Ss]\x{e1}inn<\/N>))(?![<>])/<E msg="INPHRASE{i s\x{e1}inn}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Ss]aochan<\/N>))(?![<>])/<E msg="INPHRASE{saochan c\x{e9}ille}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>t?sh?l\x{e1}nchruinne<\/N>))(?![<>])/<E msg="INPHRASE{sa tsl\x{e1}nchruinne}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Ss]ciot\x{e1}n<\/N>))(?![<>])/<E msg="INPHRASE{de sciot\x{e1}n}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Ss]c[ua]n<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{scun scan}">$1<\/E>/g;
	s/(?<![<>])((<A[^>]*[^>]*>[Ss]hin<\/A>))(?![<>])/<E msg="INPHRASE{\x{f3} shin}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Ss]inc\x{ed}n<\/N>))(?![<>])/<E msg="INPHRASE{si\x{fa}n sinc\x{ed}n}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Ss]iobh\x{e1}i?n<\/N>))(?![<>])/<E msg="INPHRASE{mac siobh\x{e1}in}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Ss]i\x{fa}n<\/N>))(?![<>])/<E msg="INPHRASE{si\x{fa}n sinc\x{ed}n}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Ss]p[ie][oa]r<\/N>))(?![<>])/<E msg="INPHRASE{spior spear}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Ss]teig<\/N>))(?![<>])/<E msg="INPHRASE{steig meig}">$1<\/E>/g;
	s/(?<![<>])(<N>[Ss]teillbheatha)(?![<>])/<E msg="INPHRASE{ina steillbheatha}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Ss]trae<\/N>))(?![<>])/<E msg="INPHRASE{ar strae}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Ss][\x{fa}\x{e1}]m<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{s\x{fa}m s\x{e1}m}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>d[Tt]aisce<\/N>))(?![<>])/<E msg="INPHRASE{i dtaisce}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>d[Tt]eagmh\x{e1}il<\/N>))(?![<>])/<E msg="INPHRASE{i dteagmh\x{e1}il}">$1<\/E>/g;
	s/(?<![<>])(<S>d[Tt]\x{ed}<\/S>)(?![<>])/<E msg="INPHRASE{go dt\x{ed}}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>d[Tt]\x{f3}lamh<\/N>))(?![<>])/<E msg="INPHRASE{i dt\x{f3}lamh}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>d[Tt]r\x{e1}tha<\/N>))(?![<>])/<E msg="INPHRASE{i dtr\x{e1}tha}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>d[Tt]reis<\/N>))(?![<>])/<E msg="INPHRASE{i dtreis}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>d[Tt]uilleama\x{ed}<\/N>))(?![<>])/<E msg="INPHRASE{i dtuilleama\x{ed}}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Tt]h?amhach<\/N>))(?![<>])/<E msg="INPHRASE{tamhach t\x{e1}isc}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Tt]hiarcais<\/N>))(?![<>])/<E msg="INPHRASE{a thiarcais}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Tt]inneall<\/N>))(?![<>])/<E msg="INPHRASE{ar tinneall}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Tt]reis<\/N>))(?![<>])/<E msg="INPHRASE{go treis, sa treis}">$1<\/E>/g;
	s/(?<![<>])((<N[^>]*[^>]*>[Uu]airibh<\/N>))(?![<>])/<E msg="INPHRASE{ar uairibh}">$1<\/E>/g;
	}
}

sub unigram
{
	for ($_[0]) {
	s/<V( pl="y")? p=".." t="([^"]*)"/<V p="xx" t="$2"/g;
	s/<B><Z>(<[^>]*>)*<S.>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<S>$3<\/S>/g;
	s/<B><Z>(<[^>]*>)*<N pl="n" gnt="n" gnd="m".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="n" gnt="n" gnd="m">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<N pl="n" gnt="n" gnd="f".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="n" gnt="n" gnd="f">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<T.>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<T>$3<\/T>/g;
	s/<B><Z>(<[^>]*>)*<A pl="n" gnt="n".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<A pl="n" gnt="n">$3<\/A>/g;
	s/<B><Z>(<[^>]*>)*<C.>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<C>$3<\/C>/g;
	s/<B><Z>(<[^>]*>)*<P.>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<P>$3<\/P>/g;
	s/<B><Z>(<[^>]*>)*<V p="xx" t="l\x{e1}ith".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<V p="xx" t="l\x{e1}ith">$3<\/V>/g;
	s/<B><Z>(<[^>]*>)*<V p="xx" t="caite".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<V p="xx" t="caite">$3<\/V>/g;
	s/<B><Z>(<[^>]*>)*<U.>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<U>$3<\/U>/g;
	s/<B><Z>(<[^>]*>)*<N pl="y" gnt="n" gnd="m".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="y" gnt="n" gnd="m">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<R.>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<R>$3<\/R>/g;
	s/<B><Z>(<[^>]*>)*<O.>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<O>$3<\/O>/g;
	s/<B><Z>(<[^>]*>)*<D.>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<D>$3<\/D>/g;
	s/<B><Z>(<[^>]*>)*<V cop="y".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<V cop="y">$3<\/V>/g;
	s/<B><Z>(<[^>]*>)*<N pl="n" gnt="y" gnd="f".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="n" gnt="y" gnd="f">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<N pl="n" gnt="y" gnd="m".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="n" gnt="y" gnd="m">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<N pl="y" gnt="n" gnd="f".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="y" gnt="n" gnd="f">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<N pl="n" gnt="n".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="n" gnt="n">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<A pl="y" gnt="n".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<A pl="y" gnt="n">$3<\/A>/g;
	s/<B><Z>(<[^>]*>)*<A.>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<A>$3<\/A>/g;
	s/<B><Z>(<[^>]*>)*<A pl="n" gnt="y" gnd="f".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<A pl="n" gnt="y" gnd="f">$3<\/A>/g;
	s/<B><Z>(<[^>]*>)*<Q.>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<Q>$3<\/Q>/g;
	s/<B><Z>(<[^>]*>)*<V p="xx" t="coinn".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<V p="xx" t="coinn">$3<\/V>/g;
	s/<B><Z>(<[^>]*>)*<V p="xx" t="f\x{e1}ist".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<V p="xx" t="f\x{e1}ist">$3<\/V>/g;
	s/<B><Z>(<[^>]*>)*<V p="saor" t="caite".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<V p="saor" t="caite">$3<\/V>/g;
	s/<B><Z>(<[^>]*>)*<N pl="n" gnt="y" gnd="f" h="y".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="n" gnt="y" gnd="f" h="y">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<V p="saor" t="l\x{e1}ith".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<V p="saor" t="l\x{e1}ith">$3<\/V>/g;
	s/<B><Z>(<[^>]*>)*<V p="xx" t="ord".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<V p="xx" t="ord">$3<\/V>/g;
	s/<B><Z>(<[^>]*>)*<F.>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<F>$3<\/F>/g;
	s/<B><Z>(<[^>]*>)*<N pl="y" gnt="y" gnd="m".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="y" gnt="y" gnd="m">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<A pl="n" gnt="y" gnd="m".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<A pl="n" gnt="y" gnd="m">$3<\/A>/g;
	s/<B><Z>(<[^>]*>)*<A pl="n" gnt="n" h="y".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<A pl="n" gnt="n" h="y">$3<\/A>/g;
	s/<B><Z>(<[^>]*>)*<O em="y".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<O em="y">$3<\/O>/g;
	s/<B><Z>(<[^>]*>)*<N pl="n" gnt="n" gnd="f" h="y".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="n" gnt="n" gnd="f" h="y">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<V p="saor" t="coinn".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<V p="saor" t="coinn">$3<\/V>/g;
	s/<B><Z>(<[^>]*>)*<V p="saor" t="f\x{e1}ist".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<V p="saor" t="f\x{e1}ist">$3<\/V>/g;
	s/<B><Z>(<[^>]*>)*<V p="xx" t="gn\x{e1}th".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<V p="xx" t="gn\x{e1}th">$3<\/V>/g;
	s/<B><Z>(<[^>]*>)*<N pl="y" gnt="y" gnd="f".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="y" gnt="y" gnd="f">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<N pl="n" gnt="n" gnd="m" h="y".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="n" gnt="n" gnd="m" h="y">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<P h="y".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<P h="y">$3<\/P>/g;
	s/<B><Z>(<[^>]*>)*<N pl="n" gnt="n" h="y".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="n" gnt="n" h="y">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<I.>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<I>$3<\/I>/g;
	s/<B><Z>(<[^>]*>)*<N pl="y" gnt="y".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="y" gnt="y">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<N pl="y" gnt="n".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="y" gnt="n">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<N pl="y" gnt="n" gnd="m" h="y".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="y" gnt="n" gnd="m" h="y">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<N pl="y" gnt="n" gnd="f" h="y".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="y" gnt="n" gnd="f" h="y">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<V p="xx" t="foshuit".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<V p="xx" t="foshuit">$3<\/V>/g;
	s/<B><Z>(<[^>]*>)*<V p="saor" t="gn\x{e1}th".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<V p="saor" t="gn\x{e1}th">$3<\/V>/g;
	s/<B><Z>(<[^>]*>)*<N pl="n" gnt="y" gnd="m" h="y".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="n" gnt="y" gnd="m" h="y">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<N pl="y" gnt="n" h="y".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<N pl="y" gnt="n" h="y">$3<\/N>/g;
	s/<B><Z>(<[^>]*>)*<V p="saor" t="ord".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<V p="saor" t="ord">$3<\/V>/g;
	s/<B><Z>(<[^>]*>)*<V p="saor" t="foshuit".>(<[^>]*>)*<\/Z>([^<]*)<\/B>/<V p="saor" t="foshuit">$3<\/V>/g;
	}
}

# recursive helper function for "tag_one_word".  
# ** This function is generated automatically from a higher level 
#    description of Irish morphology ** 
#
#  Takes three arguments; original word to be tagged; the current
#  decomposed version for lookup (and possible further decomp)
#  and a "level" which determines whether, if a match is found,
#  whether it should be untagged (-1), tagged as OK but noting decomp (0),
#  tagged as non-standard (1), or tagged as a misspelling (2).
#
#   Returns the word tagged appropriately if a match is found, returns
#   false ("") if the recursion bottoms out with no matches
sub tag_recurse
{
	my ( $self, $original, $current, $level ) = @_;

	my $ans = $self->lookup( $original, $current, $level );
	return $ans if $ans;
	my $newcurrent;
	if ( $current =~ m/^BP/ ) {
		($newcurrent = $current) =~ s/^BP/"bP"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^BHF/ ) {
		($newcurrent = $current) =~ s/^BHF/"bhF"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^DT/ ) {
		($newcurrent = $current) =~ s/^DT/"dT"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^GC/ ) {
		($newcurrent = $current) =~ s/^GC/"gC"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^MB/ ) {
		($newcurrent = $current) =~ s/^MB/"mB"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^ND/ ) {
		($newcurrent = $current) =~ s/^ND/"nD"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^NG/ ) {
		($newcurrent = $current) =~ s/^NG/"nG"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^TS/ ) {
		($newcurrent = $current) =~ s/^TS/"tS"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/ ) {
		($newcurrent = $current) =~ s/^([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/"".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}
	
	if ( $current =~ m/^([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])/ ) {
		($newcurrent = $current) =~ s/^([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])/"".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}
 	
	if ( $current =~ m/-([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])/ ) {
		($newcurrent = $current) =~ s/-([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])/"-".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}
 	
	if ( $current =~ m/^b'([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}F])/ ) {
		($newcurrent = $current) =~ s/^b'([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}F])/"b'".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^bP([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/ ) {
		($newcurrent = $current) =~ s/^bP([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/"bp".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}
	
	if ( $current =~ m/^bP/ ) {
		($newcurrent = $current) =~ s/^bP/"bp"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}
	
	if ( $current =~ m/^bhF([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/ ) {
		($newcurrent = $current) =~ s/^bhF([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/"bhf".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^bhF/ ) {
		($newcurrent = $current) =~ s/^bhF/"bhf"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^d'([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}F])/ ) {
		($newcurrent = $current) =~ s/^d'([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}F])/"d'".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^dT([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/ ) {
		($newcurrent = $current) =~ s/^dT([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/"dt".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^dT/ ) {
		($newcurrent = $current) =~ s/^dT/"dt"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^gC([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/ ) {
		($newcurrent = $current) =~ s/^gC([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/"gc".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^gC/ ) {
		($newcurrent = $current) =~ s/^gC/"gc"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^h([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/ ) {
		($newcurrent = $current) =~ s/^h([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/"h$1".mylc($2).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}
	
	if ( $current =~ m/^h([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])/ ) {
		($newcurrent = $current) =~ s/^h([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])/"h".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^m'([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}F])/ ) {
		($newcurrent = $current) =~ s/^m'([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}F])/"m'".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^mB([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/ ) {
		($newcurrent = $current) =~ s/^mB([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/"mb".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^mB/ ) {
		($newcurrent = $current) =~ s/^mB/"mb"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^n([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/ ) {
		($newcurrent = $current) =~ s/^n([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/"n$1".mylc($2).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^n([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])/ ) {
		($newcurrent = $current) =~ s/^n([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])/"n-".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^nD([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/ ) {
		($newcurrent = $current) =~ s/^nD([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/"nd".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^nD/ ) {
		($newcurrent = $current) =~ s/^nD/"nd"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^nG([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/ ) {
		($newcurrent = $current) =~ s/^nG([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/"ng".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^nG/ ) {
		($newcurrent = $current) =~ s/^nG/"ng"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^tS([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/ ) {
		($newcurrent = $current) =~ s/^tS([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/"ts".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^tS/ ) {
		($newcurrent = $current) =~ s/^tS/"ts"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^t([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/ ) {
		($newcurrent = $current) =~ s/^t([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}'-]+)$/"t$1".mylc($2).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}
	
	if ( $current =~ m/^t([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])/ ) {
		($newcurrent = $current) =~ s/^t([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])/"t-".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > -1) ? $level : -1);
		return $ans if $ans;
	}

	if ( $current =~ m/^h?an-([bcfgmp]h)/ ) {
		($newcurrent = $current) =~ s/^h?an-([bcfgmp]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^h?an-([bcfgmp][^h])/ ) {
		($newcurrent = $current) =~ s/^h?an-([bcfgmp][^h])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 2) ? $level : 2);
		return $ans if $ans;
	}

	if ( $current =~ m/^h?an-([^bcfgmp][^h])/ ) {
		($newcurrent = $current) =~ s/^h?an-([^bcfgmp][^h])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^h?an-([^bcfgmp]h)/ ) {
		($newcurrent = $current) =~ s/^h?an-([^bcfgmp]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 2) ? $level : 2);
		return $ans if $ans;
	}
    
	if ( $current =~ m/^dea-([bcdfgmpt]h)/ ) {
		($newcurrent = $current) =~ s/^dea-([bcdfgmpt]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^dea-([bcdfgmpt][^h])/ ) {
		($newcurrent = $current) =~ s/^dea-([bcdfgmpt][^h])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 2) ? $level : 2);
		return $ans if $ans;
	}

	if ( $current =~ m/^dea-(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^dea-(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^dea-(s[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^dea-(s[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 2) ? $level : 2);
		return $ans if $ans;
	}

	if ( $current =~ m/^dea-(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/ ) {
		($newcurrent = $current) =~ s/^dea-(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}
    
	if ( $current =~ m/^dea-([^bcdfgmpst])/ ) {
		($newcurrent = $current) =~ s/^dea-([^bcdfgmpst])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^ain([de\x{e9}i\x{ed}lnrst])/ ) {
		($newcurrent = $current) =~ s/^ain([de\x{e9}i\x{ed}lnrst])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^ain([bcfgmp]h)/ ) {
		($newcurrent = $current) =~ s/^ain([bcfgmp]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^ath([^bcdfgmpst])/ ) {
		($newcurrent = $current) =~ s/^ath([^bcdfgmpst])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^ath([bcdfgmp]h)/ ) {
		($newcurrent = $current) =~ s/^ath([bcdfgmp]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^ath(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^ath(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^ath(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/ ) {
		($newcurrent = $current) =~ s/^ath(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^comh([^bcdfgmnpst])/ ) {
		($newcurrent = $current) =~ s/^comh([^bcdfgmnpst])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^comh([bcdfgpt]h)/ ) {
		($newcurrent = $current) =~ s/^comh([bcdfgpt]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^comh(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^comh(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^comh(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/ ) {
		($newcurrent = $current) =~ s/^comh(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^c\x{f3}(mh[a\x{e1}o\x{f3}u\x{fa}])/ ) {
		($newcurrent = $current) =~ s/^c\x{f3}(mh[a\x{e1}o\x{f3}u\x{fa}])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^c\x{f3}i(mh[e\x{e9}i\x{ed}])/ ) {
		($newcurrent = $current) =~ s/^c\x{f3}i(mh[e\x{e9}i\x{ed}])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^comh-mh/ ) {
		($newcurrent = $current) =~ s/^comh-mh/"mh"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^c\x{f3}(n[a\x{e1}o\x{f3}u\x{fa}])/ ) {
		($newcurrent = $current) =~ s/^c\x{f3}(n[a\x{e1}o\x{f3}u\x{fa}])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^c\x{f3}i(n[e\x{e9}i\x{ed}])/ ) {
		($newcurrent = $current) =~ s/^c\x{f3}i(n[e\x{e9}i\x{ed}])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^do-([aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/ ) {
		($newcurrent = $current) =~ s/^do-([aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^do([lnr])/ ) {
		($newcurrent = $current) =~ s/^do([lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^do([bcdfgmpt]h)/ ) {
		($newcurrent = $current) =~ s/^do([bcdfgmpt]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^do(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^do(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^do(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/ ) {
		($newcurrent = $current) =~ s/^do(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^droch([^bcdfgmpst])/ ) {
		($newcurrent = $current) =~ s/^droch([^bcdfgmpst])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^droch-(ch)/ ) {
		($newcurrent = $current) =~ s/^droch-(ch)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^droch([bdfgmpt]h)/ ) {
		($newcurrent = $current) =~ s/^droch([bdfgmpt]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^droch(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^droch(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^droch(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/ ) {
		($newcurrent = $current) =~ s/^droch(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^f\x{ed}or([^bcdfgmprst])/ ) {
		($newcurrent = $current) =~ s/^f\x{ed}or([^bcdfgmprst])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^f\x{ed}or-(r)/ ) {
		($newcurrent = $current) =~ s/^f\x{ed}or-(r)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^f\x{ed}or([bcdfgmpt]h)/ ) {
		($newcurrent = $current) =~ s/^f\x{ed}or([bcdfgmpt]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^f\x{ed}or(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^f\x{ed}or(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^f\x{ed}or(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/ ) {
		($newcurrent = $current) =~ s/^f\x{ed}or(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^for([^bcdfgmprst])/ ) {
		($newcurrent = $current) =~ s/^for([^bcdfgmprst])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^for-(r)/ ) {
		($newcurrent = $current) =~ s/^for-(r)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^for([bcdfgmpt]h)/ ) {
		($newcurrent = $current) =~ s/^for([bcdfgmpt]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^for(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^for(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^for(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/ ) {
		($newcurrent = $current) =~ s/^for(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^fo-([aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/ ) {
		($newcurrent = $current) =~ s/^fo-([aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^fo([lnr])/ ) {
		($newcurrent = $current) =~ s/^fo([lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^fo([bcdfgmpt]h)/ ) {
		($newcurrent = $current) =~ s/^fo([bcdfgmpt]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^fo(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^fo(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^fo(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/ ) {
		($newcurrent = $current) =~ s/^fo(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^frith([^bcdfgmpst])/ ) {
		($newcurrent = $current) =~ s/^frith([^bcdfgmpst])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^fri(t[^h])/ ) {
		($newcurrent = $current) =~ s/^fri(t[^h])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^frith([bcdfgmp]h)/ ) {
		($newcurrent = $current) =~ s/^frith([bcdfgmp]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^frith(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^frith(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^frith(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/ ) {
		($newcurrent = $current) =~ s/^frith(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^iar([^bcdfgmprst])/ ) {
		($newcurrent = $current) =~ s/^iar([^bcdfgmprst])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^iar-(r)/ ) {
		($newcurrent = $current) =~ s/^iar-(r)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^iar([bcdfgmpt]h)/ ) {
		($newcurrent = $current) =~ s/^iar([bcdfgmpt]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^iar(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^iar(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^iar(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/ ) {
		($newcurrent = $current) =~ s/^iar(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^il([^bcfgmp])/ ) {
		($newcurrent = $current) =~ s/^il([^bcfgmp])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^il([bcfgmp]h)/ ) {
		($newcurrent = $current) =~ s/^il([bcfgmp]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^im([^bcdfgmpst])/ ) {
		($newcurrent = $current) =~ s/^im([^bcdfgmpst])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^im([bcdfgmpt]h)/ ) {
		($newcurrent = $current) =~ s/^im([bcdfgmpt]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^im(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^im(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^im(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/ ) {
		($newcurrent = $current) =~ s/^im(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^in([^bcfgmp])/ ) {
		($newcurrent = $current) =~ s/^in([^bcfgmp])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^in-(n)/ ) {
		($newcurrent = $current) =~ s/^in-(n)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^in([bcfgmp]h)/ ) {
		($newcurrent = $current) =~ s/^in([bcfgmp]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^m\x{ed}-([aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/ ) {
		($newcurrent = $current) =~ s/^m\x{ed}-([aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^m\x{ed}([aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/ ) {
		($newcurrent = $current) =~ s/^m\x{ed}([aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 2) ? $level : 2);
		return $ans if $ans;
	}
  
	if ( $current =~ m/^m\x{ed}([lnr])/ ) {
		($newcurrent = $current) =~ s/^m\x{ed}([lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^m\x{ed}([bcdfgmpt]h)/ ) {
		($newcurrent = $current) =~ s/^m\x{ed}([bcdfgmpt]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^m\x{ed}(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^m\x{ed}(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^m\x{ed}(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/ ) {
		($newcurrent = $current) =~ s/^m\x{ed}(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^pr\x{ed}omh([^bcdfgmpst])/ ) {
		($newcurrent = $current) =~ s/^pr\x{ed}omh([^bcdfgmpst])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^pr\x{ed}omh([bcdfgpt]h)/ ) {
		($newcurrent = $current) =~ s/^pr\x{ed}omh([bcdfgpt]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^pr\x{ed}omh-(mh)/ ) {
		($newcurrent = $current) =~ s/^pr\x{ed}omh-(mh)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^pr\x{ed}omh(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^pr\x{ed}omh(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^pr\x{ed}omh(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/ ) {
		($newcurrent = $current) =~ s/^pr\x{ed}omh(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^r\x{e9}amh([^bcdfgmpst])/ ) {
		($newcurrent = $current) =~ s/^r\x{e9}amh([^bcdfgmpst])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^r\x{e9}amh([bcdfgpt]h)/ ) {
		($newcurrent = $current) =~ s/^r\x{e9}amh([bcdfgpt]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^r\x{e9}amh-(mh)/ ) {
		($newcurrent = $current) =~ s/^r\x{e9}amh-(mh)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^r\x{e9}amh(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^r\x{e9}amh(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^r\x{e9}amh(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/ ) {
		($newcurrent = $current) =~ s/^r\x{e9}amh(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^r\x{f3}-([aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/ ) {
		($newcurrent = $current) =~ s/^r\x{f3}-([aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^r\x{f3}([aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/ ) {
		($newcurrent = $current) =~ s/^r\x{f3}([aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 2) ? $level : 2);
		return $ans if $ans;
	}

	if ( $current =~ m/^r\x{f3}([lnr])/ ) {
		($newcurrent = $current) =~ s/^r\x{f3}([lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^r\x{f3}([bcdfgmpt]h)/ ) {
		($newcurrent = $current) =~ s/^r\x{f3}([bcdfgmpt]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^r\x{f3}(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^r\x{f3}(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^r\x{f3}(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/ ) {
		($newcurrent = $current) =~ s/^r\x{f3}(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^sain([^bcdfgmpst])/ ) {
		($newcurrent = $current) =~ s/^sain([^bcdfgmpst])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^sain([bcdfgmpt]h)/ ) {
		($newcurrent = $current) =~ s/^sain([bcdfgmpt]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^sain(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^sain(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^sain(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/ ) {
		($newcurrent = $current) =~ s/^sain(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^so-([aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/ ) {
		($newcurrent = $current) =~ s/^so-([aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^so([lnr])/ ) {
		($newcurrent = $current) =~ s/^so([lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^so([bcdfgmpt]h)/ ) {
		($newcurrent = $current) =~ s/^so([bcdfgmpt]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^so(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/ ) {
		($newcurrent = $current) =~ s/^so(sh[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnr])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^so(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/ ) {
		($newcurrent = $current) =~ s/^so(s[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}lnrh])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^tras([^bcfgmnps])/ ) {
		($newcurrent = $current) =~ s/^tras([^bcfgmnps])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}
   
	if ( $current =~ m/^tras([bcfgmp]h)/ ) {
		($newcurrent = $current) =~ s/^tras([bcfgmp]h)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^tras-(s)/ ) {
		($newcurrent = $current) =~ s/^tras-(s)/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^(cil|gig|is|meig|micr|pic|teil)ea-?([^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+[aou\x{e1}\x{f3}\x{fa}])/ ) {
		($newcurrent = $current) =~ s/^(cil|gig|is|meig|micr|pic|teil)ea-?([^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+[aou\x{e1}\x{f3}\x{fa}])/"$2"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^(cil|gig|is|meig|micr|pic|teil)i-?([^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+[ei\x{e9}\x{ed}])/ ) {
		($newcurrent = $current) =~ s/^(cil|gig|is|meig|micr|pic|teil)i-?([^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+[ei\x{e9}\x{ed}])/"$2"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^(ant|f\x{f3}t|nan|par|pol|ultr)a-?([^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+[aou\x{e1}\x{f3}\x{fa}])/ ) {
		($newcurrent = $current) =~ s/^(ant|f\x{f3}t|nan|par|pol|ultr)a-?([^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+[aou\x{e1}\x{f3}\x{fa}])/"$2"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^(ant|f\x{f3}t|nan|par|pol|ultr)ai-?([^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+[ei\x{e9}\x{ed}])/ ) {
		($newcurrent = $current) =~ s/^(ant|f\x{f3}t|nan|par|pol|ultr)ai-?([^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+[ei\x{e9}\x{ed}])/"$2"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^(eachtar|freas|\x{ed}os|neas|r\x{e9}alt|tob|uas|uath)-?([^-])/ ) {
		($newcurrent = $current) =~ s/^(eachtar|freas|\x{ed}os|neas|r\x{e9}alt|tob|uas|uath)-?([^-])/"$2"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/achai?s$/ ) {
		($newcurrent = $current) =~ s/achai?s$/"ach"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/acht$/ ) {
		($newcurrent = $current) =~ s/acht$/"ach"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/\x{ed}ocht$/ ) {
		($newcurrent = $current) =~ s/\x{ed}ocht$/"\x{ed}och"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/([aou\x{e1}\x{f3}\x{fa}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+)-?san$/ ) {
		($newcurrent = $current) =~ s/([aou\x{e1}\x{f3}\x{fa}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+)-?san$/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/([ei\x{e9}\x{ed}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+)-?sean$/ ) {
		($newcurrent = $current) =~ s/([ei\x{e9}\x{ed}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+)-?sean$/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/([aou\x{e1}\x{f3}\x{fa}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+)-?sa$/ ) {
		($newcurrent = $current) =~ s/([aou\x{e1}\x{f3}\x{fa}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+)-?sa$/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/([ei\x{e9}\x{ed}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+)-?se$/ ) {
		($newcurrent = $current) =~ s/([ei\x{e9}\x{ed}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+)-?se$/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/([aou\x{e1}\x{f3}\x{fa}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+)-?na$/ ) {
		($newcurrent = $current) =~ s/([aou\x{e1}\x{f3}\x{fa}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+)-?na$/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/([ei\x{e9}\x{ed}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+)-?ne$/ ) {
		($newcurrent = $current) =~ s/([ei\x{e9}\x{ed}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}-]+)-?ne$/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^aith/ ) {
		($newcurrent = $current) =~ s/^aith/"ath"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^eadar/ ) {
		($newcurrent = $current) =~ s/^eadar/"idir"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^dh'/ ) {
		($newcurrent = $current) =~ s/^dh'/"d'"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^h-/ ) {
		($newcurrent = $current) =~ s/^h-/"h"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^n-([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])/ ) {
		($newcurrent = $current) =~ s/^n-([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])/"n-".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^t-([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])/ ) {
		($newcurrent = $current) =~ s/^t-([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])/"t-".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^ana-/ ) {
		($newcurrent = $current) =~ s/^ana-/"an-"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}
    
	if ( $current =~ m/^ion/ ) {
		($newcurrent = $current) =~ s/^ion/"in"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^\x{f3}ig/ ) {
		($newcurrent = $current) =~ s/^\x{f3}ig/"\x{f3}g"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^\x{f3}sd/ ) {
		($newcurrent = $current) =~ s/^\x{f3}sd/"\x{f3}st"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^sg/ ) {
		($newcurrent = $current) =~ s/^sg/"sc"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^uaith/ ) {
		($newcurrent = $current) =~ s/^uaith/"uath"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/^\x{fa}ir/ ) {
		($newcurrent = $current) =~ s/^\x{fa}ir/"\x{fa}r"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/a\x{ed}le$/ ) {
		($newcurrent = $current) =~ s/a\x{ed}le$/"a\x{ed}ola"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}
    
	if ( $current =~ m/aibh$/ ) {
		($newcurrent = $current) =~ s/aibh$/"a"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}
    
	if ( $current =~ m/([^a])ibh$/ ) {
		($newcurrent = $current) =~ s/([^a])ibh$/"$1e"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}
    
	if ( $current =~ m/fa[ds]$/ ) {
		($newcurrent = $current) =~ s/fa[ds]$/"faidh"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/fea[ds]$/ ) {
		($newcurrent = $current) =~ s/fea[ds]$/"fidh"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/\x{f3}[ds]$/ ) {
		($newcurrent = $current) =~ s/\x{f3}[ds]$/"\x{f3}idh"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/eo[ds]$/ ) {
		($newcurrent = $current) =~ s/eo[ds]$/"eoidh"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/fai[rs]$/ ) {
		($newcurrent = $current) =~ s/fai[rs]$/"faidh"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/fi[rs]$/ ) {
		($newcurrent = $current) =~ s/fi[rs]$/"fidh"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/\x{f3}is$/ ) {
		($newcurrent = $current) =~ s/\x{f3}is$/"\x{f3}idh"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/eois$/ ) {
		($newcurrent = $current) =~ s/eois$/"eoidh"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/(...)eas$/ ) {
		($newcurrent = $current) =~ s/(...)eas$/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/(..[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])as$/ ) {
		($newcurrent = $current) =~ s/(..[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])as$/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/(...)\x{ed}os$/ ) {
		($newcurrent = $current) =~ s/(...)\x{ed}os$/"$1igh"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/(...)ai[rs]$/ ) {
		($newcurrent = $current) =~ s/(...)ai[rs]$/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/(..[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])i[rs]$/ ) {
		($newcurrent = $current) =~ s/(..[^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])i[rs]$/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/(...)\x{ed}s$/ ) {
		($newcurrent = $current) =~ s/(...)\x{ed}s$/"$1igh"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/ains$/ ) {
		($newcurrent = $current) =~ s/ains$/"ann"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/ins$/ ) {
		($newcurrent = $current) =~ s/ins$/"eann"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/\x{ed}ns$/ ) {
		($newcurrent = $current) =~ s/\x{ed}ns$/"\x{ed}onn"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/anns$/ ) {
		($newcurrent = $current) =~ s/anns$/"ann"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/\x{ed}onns$/ ) {
		($newcurrent = $current) =~ s/\x{ed}onns$/"\x{ed}onn"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 1) ? $level : 1);
		return $ans if $ans;
	}

	if ( $current =~ m/([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])/ ) {
		($newcurrent = $current) =~ s/([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])/"".mylc($1).""/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 2) ? $level : 2);
		return $ans if $ans;
	}
	
	if ( $current =~ m/([ei\x{e9}\x{ed}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]+)\x{ed}n\x{ed}?$/ ) {
		($newcurrent = $current) =~ s/([ei\x{e9}\x{ed}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]+)\x{ed}n\x{ed}?$/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}
	
	if ( $current =~ m/([aou\x{e1}\x{f3}\x{fa}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]+)\x{ed}n\x{ed}?$/ ) {
		($newcurrent = $current) =~ s/([aou\x{e1}\x{f3}\x{fa}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]+)\x{ed}n\x{ed}?$/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 2) ? $level : 2);
		return $ans if $ans;
	}
	
	if ( $current =~ m/^bp([^h])/ ) {
		($newcurrent = $current) =~ s/^bp([^h])/"p$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^bhf([^h])/ ) {
		($newcurrent = $current) =~ s/^bhf([^h])/"f$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^dt([^h])/ ) {
		($newcurrent = $current) =~ s/^dt([^h])/"t$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^gc([^h])/ ) {
		($newcurrent = $current) =~ s/^gc([^h])/"c$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^mb([^h])/ ) {
		($newcurrent = $current) =~ s/^mb([^h])/"b$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^nd([^h])/ ) {
		($newcurrent = $current) =~ s/^nd([^h])/"d$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^ng([^h])/ ) {
		($newcurrent = $current) =~ s/^ng([^h])/"g$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^ts([^h])/ ) {
		($newcurrent = $current) =~ s/^ts([^h])/"s$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^([bcdfgmp])h/ ) {
		($newcurrent = $current) =~ s/^([bcdfgmp])h/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^th([^s])/ ) {
		($newcurrent = $current) =~ s/^th([^s])/"t$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}
   
	if ( $current =~ m/^sh([lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/ ) {
		($newcurrent = $current) =~ s/^sh([lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/"s$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	if ( $current =~ m/^[bdm]'([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/ ) {
		($newcurrent = $current) =~ s/^[bdm]'([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}
	
	if ( $current =~ m/^[nt]-([aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/ ) {
		($newcurrent = $current) =~ s/^[nt]-([aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/"$1"/e;
		$ans = $self->tag_recurse($original, $newcurrent, ($level > 0) ? $level : 0);
		return $ans if $ans;
	}

	return "";
}



1;

__END__

=back

=head1 HISTORY

=over 4

=item *
0.50

First Perl version.

=back

=head1 SEE ALSO

=over 4

=item *
L<http://borel.slu.edu/gramadoir/>

=item *
L<Locale::Maketext>

=item *
L<perl(1)>

=back

=head1 BUGS

The grammar checker does not attempt a full parse of the input
sentences nor does it attempt to exploit any semantic information.
There are, therefore, certain constructs that cannot be dealt with
correctly.  For instance, in Irish the possessive adjective "a" mutates the
word which follows differently depending on whether it means
"his", "her", or "their".

=head1 AUTHOR

Kevin P. Scannell, E<lt>scannell@slu.eduE<gt>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 Kevin P. Scannell

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
