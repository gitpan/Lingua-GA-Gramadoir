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

our $VERSION = '0.60';
use vars qw(@FOCAIL @MORPH %EILE %EARRAIDI %NOCOMBO %POS %GRAMS %MESSAGES %IGNORE $lh);

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

unigram_tagging => 1

Resolve ambiguous part of speech according to frequency.  This should
be set to false only for debugging purposes because the pattern matching
for grammatical errors relies on complete disambiguation.

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
			unigram_tagging => 1,
			interface_language => '',
			input_encoding => 'ISO-8859-1',
			@_,
	};

	if ($self->{'interface_language'}) {
		$lh = Lingua::GA::Gramadoir::Languages->get_handle($self->{'interface_language'});
	}
	else {
		$lh = Lingua::GA::Gramadoir::Languages->get_handle();
	}
	croak 'Could not set interface language' unless $lh;

	( my $datapath ) = __FILE__ =~ /(.*)\.pm/;
	my $ref;
	my $errormsg = gettext('%s: problem reading the database\n',
				gettext('An Gramadoir'));
	eval {$ref = retrieve(File::Spec->catfile($datapath, 'eile.hash'))};
	croak $errormsg if ($@ or !$ref);
	%EILE = %$ref;
	eval {$ref = retrieve(File::Spec->catfile($datapath, 'earraidi.hash'))};
	croak $errormsg if ($@ or !$ref);
	%EARRAIDI = %$ref;
	eval {$ref = retrieve(File::Spec->catfile($datapath, 'nocombo.hash'))};
	croak $errormsg if ($@ or !$ref);
	%NOCOMBO = %$ref;
	eval {$ref = retrieve(File::Spec->catfile($datapath, 'pos.hash'))};
	croak $errormsg if ($@ or !$ref);
	%POS = %$ref;
	eval {$ref = retrieve(File::Spec->catfile($datapath, '3grams.hash'))};
	croak $errormsg if ($@ or !$ref);
	%GRAMS = %$ref;
	eval {$ref = retrieve(File::Spec->catfile($datapath, 'messages.hash'))};
	croak $errormsg if ($@ or !$ref);
	%MESSAGES = %$ref;
	for my $i (0 .. 6) {
		eval {$ref = retrieve(File::Spec->catfile($datapath, "focail$i.hash" ) )};
		croak $errormsg if ($@ or !$ref);
		push @FOCAIL, $ref;
	}
	eval {$ref = retrieve(File::Spec->catfile($datapath, 'morph.hash'))};
	croak $errormsg if ($@ or !$ref);
	@MORPH = @$ref;
	foreach my $rule (@MORPH) {
		my $patt = $rule->{'patt'};
		$rule->{'compiled'} = qr/$patt/;
		$patt = $rule->{'rootpos'};
		if ($patt =~ m/^<\.([+*])?>$/) {
			$rule->{'poscompiled'} = '';   # for speed
		}
		else {
			$patt =~ s/\./[^>]/g;
			$patt =~ s/>$/\/?>/;
			$rule->{'poscompiled'} = qr/$patt/;
		}
	}

	if ($self->{'use_ignore_file'}) {
		my $homedir = $ENV{HOME} || $ENV{LOGDIR}; # || (getpwuid($>))[7];
		if (open (DATAFILE, File::Spec->catfile( $homedir, '.neamhshuim' ))) {
			while (<DATAFILE>) {
				chomp;
				carp gettext('%s: `%s\' corrupted at %s\n', 
					gettext('An Gramadoir'), ".neamhshuim", $.) if /[^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]/;
				$IGNORE{$_}++;
			}
		}
	}

	return bless $self, $class;
}

sub gettext
{
	my ( $string, @rest ) = @_;

	$string =~ s/\[/~[/g;
	$string =~ s/\]/~]/g;
	$string =~ s/\%s/[_1]/;
	$string =~ s/\%s/[_2]/;
	$string =~ s/\%s/[_3]/;
	$string =~ s/\\n$/\n/;
	$string =~ s#\\/\\([1-9])\\/#/[_$1]/#;
	$string =~ s#\\/([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]+)\\/#/$1/#;

	return $lh->maketext($string, @rest);
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
	return undef unless defined $text;
	eval {from_to($text,$self->{'input_encoding'},'ISO-8859-1') };
# TRANSLATORS: "conversion" here means conversion between character encodings
	croak gettext('conversion from %s is not supported', 
			$self->{'input_encoding'}) if $@;
	my $answer = get_sentences_real($text);
	foreach my $s (@$answer) {
		$s = decode('ISO-8859-1', $s);
	}
	return $answer;
}

my $BD="\001";
my $NOBD="\002";
sub get_sentences_real
{
	my $sentences = [];

	for ($_[0]) {
		s/<[^>]*>/ /g;  # naive; see comments above
		s/\\[tnvfr]/ /g;
		s/&/&amp;/g;    # this one first!
		s/</&lt;/g;
		s/>/&gt;/g;
		s/$NOBD//g;
		s/$BD//g;
		giorr ( $_ );
		s/([^$NOBD][.?!][]"')}]*)[ \t\n]+/$1$BD/g;
		s/"/&quot;/g;   # &apos; ok  (note " in prev line)
		s/\s+/ /g;
		s/$NOBD//g;
		@$sentences = split /$BD/;
	}

	return $sentences;
}

# two arguments; first is word to be tagged, 2nd is string of grammatical bytes
sub add_grammar_tags
{
	my ( $self, $word, $grambytes ) = @_;

	my $ans;
	my $num = length( $grambytes );
	if ( $num == 1) {
		my $tag = $POS{ord($grambytes)};
		if (defined($tag)) {
			$tag =~ m/^<([A-Z])/;
			$ans = $tag.$word."</".$1.">";
		}
		else {
			carp gettext('%s: illegal grammatical code\n',
					gettext('An Gramadoir'));
			$ans = "<U>$word</U>";
		}
	}
	elsif ( $num > 1 ) {
		$ans = "<B><Z>";
		foreach my $byte (split //, $grambytes) {
			my $tag = $POS{ord($byte)};
			if (defined($tag)) {
				$tag =~ s/>$/\/>/;
				$ans = $ans.$tag;
			}
			else {
				carp gettext('%s: illegal grammatical code\n',
					gettext('An Gramadoir'));
			}
		}
		$ans = $ans."</Z>".$word."</B>";
	}
	else {
		carp gettext('%s: no grammar codes: %s\n',
			gettext('An Gramadoir'), "x");    # recode word?
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
# same arguments, return conventions as tag_recurse, except
# no maximum depth set since this doesn't recurse.
sub lookup
{
	my ( $self, $original, $current, $level, $rootpos ) = @_;

	my $ans;
	for my $href ( @FOCAIL ) {
		if ( exists($href->{$current}) ) {
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
			foreach my $patt (@$rootpos) {
				return "STOP" unless ($ans =~ m/$patt/);
			}
			if ( $level == 0 ) {
				$ans = "<E msg=\"MOIRF{$current}\"><X>".$original."</X></E>";
			}
			elsif ( $level == 1 ) {
				$ans = "<E msg=\"CAIGHDEAN{$current}\"><X>".$original."</X></E>";
			}
			elsif ( $level == 2 ) {
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
	if ($word =~ m/^([^-]+)-(.*)$/) {
		my $l = $1;
		my $r = $2;
		my $t1 = $self->tag_recurse( $l, $l, -1, [], 2 );
		my $t2 = $self->tag_recurse( $r, $r, -1, [], 2 );
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
				my $tl = $self->tag_recurse($l,$l,-1,[],2);
				my $tr = $self->tag_recurse($r,$r,-1,[],2);
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
				return "<E msg=\"MOLADH{$suggs}\"><X>$word</X></E>" if $suggs;
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
	return "<A>".$word."</A>" if ($word =~ /^[0-9,'-]+$/);
	my $ans = $self->tag_recurse($word, $word, -1, [], 6);
	return $ans if $ans;
	$ans = $self->tag_as_compound($word);
	return $ans if $ans;
	$ans = $self->tag_as_near_miss($word);
	return $ans if $ans;
	$ans = $self->find_bad_three_grams($word);
	return $ans if $ans;
	return "<X>$word</X>";
}

##############################################################################

=item tokenize TEXT

Splits the input TEXT up into orthographic words and returns a reference to an
array containing the words.

=cut

##############################################################################

sub tokenize
{
	my ( $self, $text ) = @_;
	return undef unless defined $text;
	eval {from_to($text,$self->{'input_encoding'},'ISO-8859-1') };
	croak gettext('conversion from %s is not supported', 
			$self->{'input_encoding'}) if $@;

	my $answer = [];
	my $sentences = get_sentences_real($text);
	foreach my $sentence (@$sentences) {
		$sentence = $self->tokenize_real($sentence);
		push @$answer, $1 while ($sentence =~ m/<c>([^<]*)<\/c>/g);
	}
	foreach my $s (@$answer) {
		$s = decode('ISO-8859-1', $s);
	}
	return $answer;
}


# takes a sentence as input and returns the sentence with trivial markup
# around each token (in bash version this was part of abairti)
sub tokenize_real
{
	my ( $self, $sentence ) = @_;
	my $answer="";
	foreach my $chunk (split / /,$sentence) {
		unless ($chunk =~ /^(?:(?:https?|ftp):\/\/|www\.)/) {
			$chunk =~ s/([A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9][A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]*)/<c>$1<\/c>/g;
			$chunk =~ s/(['-]+)<\/c>/<\/c>$1/g;
			$chunk =~ s/&<c>(quot|lt|gt|amp)<\/c>;/&$1;/g;
		}
		$answer .= " " if $answer;
		$answer .= $chunk;
	}
	return $answer;
}

# takes the input TEXT and returns a reference to an array of sentences with 
# a preliminary XML markup consisting of all possible parts of speech
sub unchecked_xml
{
	my $self = $_[0];
	my $sentences = get_sentences_real($_[1]);
	foreach my $sentence (@$sentences) {
		$sentence = $self->tokenize_real($sentence);
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

# current behavior is to report <F> words as misspellings, which 
# matches the behavior of aspell-ga since I exclude such words entirely
# from that package.  Just change FX -> X below to accept these words.
# In reality though, if this becomes irritating, it probably means 
# that the "misspelled" words in question should actually not be <F>...
sub spell_check
{
	my ( $self, $text ) = @_;
	return undef unless defined $text;
	eval {from_to($text,$self->{'input_encoding'},'ISO-8859-1') };
	croak gettext('conversion from %s is not supported', 
			$self->{'input_encoding'}) if $@;
	my $sentences = $self->unchecked_xml($text);
	my $badwords = [];
	foreach my $s (@$sentences) {
		if ($s =~ m/<[FX]>/) {
			$s =~ s/<[^FX\/][^>]*>//g;
			$s =~ s/<\/[^FX][^>]*>//g;
			$s =~ s/^[^<]*<[FX]>//;
			$s =~ s/<\/[FX]>[^<]*$//;
			$s =~ s/<\/[FX]>[^<]*<[FX]>/\n/g;
			$s = decode('ISO-8859-1', $s);
			push @$badwords,$s;
		}
	}
	return $badwords;
}

##############################################################################

=item all_possible_tags WORD

Takes the input WORD and returns it with (XML-style) markup 
indicating all of its possible parts of speech.

=cut

##############################################################################

sub all_possible_tags
{
	my ( $self, $word ) = @_;
	return undef unless defined $word;
	eval {from_to($word,$self->{'input_encoding'},'ISO-8859-1') };
	croak gettext('conversion from %s is not supported', 
			$self->{'input_encoding'}) if $@;
	return decode('ISO-8859-1', $self->tag_one_word($word));
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
	return undef unless defined $text;
	eval {from_to($text,$self->{'input_encoding'},'ISO-8859-1') };
	croak gettext('conversion from %s is not supported', 
			$self->{'input_encoding'}) if $@;
	my $answer = $self->add_tags_real($text);
	foreach my $s (@$answer) {
		$s = decode('ISO-8859-1', $s);
	}
	return $answer;
}

sub add_tags_real
{
	my $self = $_[0];
	my $sentences = unchecked_xml(@_);
	foreach my $sentence (@$sentences) {
		comhshuite($sentence);
		aonchiall($sentence);
		aonchiall_deux($sentence);
		unigram($sentence) if $self->{'unigram_tagging'};
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
	return undef unless defined $text;
	eval {from_to($text,$self->{'input_encoding'},'ISO-8859-1') };
	croak gettext('conversion from %s is not supported', 
			$self->{'input_encoding'}) if $@;
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

	$msg =~ m/^([^{]+)/;
	my $macro = $1;
	my $msgstr = '-';
	if (exists($MESSAGES{$macro})) {
		my $msgid = $MESSAGES{$macro};
		if ($msg =~ m/{(.*)}$/) {
			my $argument = $1;
			$argument =~ tr/_/ /;  # from EILE database
			$msgstr = gettext($msgid, $argument);
		}
		else {
			$msgstr = gettext($msgid);
		}
	}
	else {
		carp gettext('%s: unrecognized error macro: %s\n',
				gettext('An Gramadoir'),$macro);
	}
	return $msgstr;
}

##############################################################################

=item grammatical_errors TEXT

Returns the grammatical errors in the input TEXT as a reference to an array,
one error per element of the array, with each error given in a simple
XML format usable by other applications.  Error messages are localized
according to locale settings as determined by Locale::Maketext.

=cut

##############################################################################

# used to be " " x length($text)  but we need to keep newlines for coords
sub whiteout
{
	my ( $text ) = @_;
	$text =~ s/[^\n]/ /g;
	return $text;
}

# like the bash "xml_api"
sub grammatical_errors
{
	my ( $self, $text ) = @_;
	return undef unless defined $text;
	eval {from_to($text,$self->{'input_encoding'},'ISO-8859-1') };
	croak gettext('conversion from %s is not supported', 
			$self->{'input_encoding'}) if $@;
	my $pristine = $text;  # so actually NOT pristine e.g. if input is utf8
	  # next three lines need to preserve all newlines, all lengths!
	  # they mimic the code in get_sentences_real
	$pristine =~ s/(<[^>]*>)/whiteout($1);/eg;
	$pristine =~ s/\\[tnvfr]/  /g;
	$pristine =~ s/$NOBD/ /g;
	$pristine =~ s/$BD/ /g;
	  # next three lines add "buffering" for easier searching per-line
	$pristine =~ s/^/ /;
	$pristine =~ s/\n/ \n /g;
	$pristine =~ s/$/ /;

	my $marked_up_sentences = $self->xml_sentences ($text);
	my $errors = [];  # array reference to return
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
				$errorregexp =~ s/ /\\s+/g;
				$errorregexp =~ s/^/(?<=[^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9])/;
				$errorregexp =~ s/$/(?=[^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9])/;
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

# called from rialacha "OK" rules
sub strip_errors
{
	my ( $str ) = @_;
	$str =~ s/<E[^>]*>//;
	$str =~ s/<\/E>//;
	return $str;
}

# called from aonchiall ":!" rules
# first argument is the stuff between <Z> and </Z>
# second argument is the word
# third argument is a regexp matching all tags to be tossed out
sub strip_badpos
{
	my ( $str, $word, $badpos ) = @_;
	my $pos;
	my $orig = $str;
	$str =~ s/$badpos//g;
	if ($str =~ m/></) {
		return "<B><Z>$str</Z>$word</B>";
	}
	elsif ($str =~ m/^<([A-Z])/) {
		$pos = $1;
		$str =~ s/.>$/>/;
		return "$str$word</$pos>";
	}
	else {
		$orig =~ s/^(<([A-Z])[^>]*).><.*/$1>/;
		$pos = $2;
		return "$orig$word</$pos>";
	}
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
	s/(<S>[Ii]<\/S> )<B><Z>(?:<[^>]+>)+<\/Z>(bhfuil)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(bhfuil)<\/B>()/$1<V p="y" t="l\x{e1}ith">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(raibh)<\/B>()/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Tt]har)<\/B>()/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Cc]han)<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<U>$2<\/U>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ff]aoin)<\/B>()/$1<S>$2<\/S>$3/g;
	s/(<S>[Ff]aoin<\/S> )<B><Z>(?:<[^>]+>)+<\/Z>(g?ch?\x{e9}ad)<\/B>()/$1<N pl="n" gnt="n">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Tt]h\x{ed}os)<\/B>()/$1<R>$2<\/R>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ff]i\x{fa})<\/B>()/$1<R>$2<\/R>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Gg]o<\/[A-DF-Z]> )<B><Z><N pl="n" gnt="n" gnd="m".><N pl="n" gnt="y" gnd="m".><V p="y" t="foshuit".><\/Z>((?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*)<\/B>()/$1<V p="y" t="foshuit">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Nn]\x{e1}r<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>([Cc]huma)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Nn]\x{e1}r<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)*<V p="y" t="foshuit".>(?:<[^>]+>)*<\/Z>((?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+)<\/B>()/$1<V p="y" t="foshuit">$2<\/V>$3/g;
	s/()<B><Z>((?:<[^>]+>)*<V p="y" t="foshuit".>(?:<[^>]+>)*)<\/Z>((?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+)<\/B>()/"$1".strip_badpos($2,$3,'<V p="y" t="foshuit".>')."$4"/eg;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(g?[Cc]h?\x{e9}ad)<\/B>( (?:<[\/A-DF-Z][^>]*>)+seo<\/[A-DF-Z]>)/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(g?[Cc]h?\x{e9}ad)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Cc]heana)<\/B>()/$1<R>$2<\/R>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Mm]\x{e1}s)<\/B>()/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]b)<\/B>()/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([\x{c1}\x{e1}]il)<\/B>()/$1<N pl="n" gnt="n">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Mm]h?\x{f3}ide)<\/B>()/$1<A pl="n" gnt="y" gnd="f">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)*<V cop="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>( <N pl="n" gnt="n">(?:\x{e1}il|ch?uimhin|eol|fh?\x{e9}idir|oth)<\/N>)/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)*<V cop="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>( <N pl="n" gnt="n" h="y">(?:h\x{e1}il|heol)<\/N>)/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)*<V cop="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>( <N pl="n" gnt="n" gnd="f">(?:aithnid|mian|suim)<\/N>)/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)*<V cop="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>( <N pl="n" gnt="n" gnd="m">fuath<\/N>)/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)*<V cop="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>( (?:<N[^>]*>g\x{e1}<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>g\x{e1}<\/B>))/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)*<V cop="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>( <A pl="n" gnt="n">(?:dh?\x{f3}cha|eagal|fh?ol\x{e1}ir|ionann|leor|mh?iste)<\/A>)/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)*<V cop="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>( <A pl="n" gnt="n" h="y">(?:heagal|hionann)<\/A>)/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)*<V cop="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>( <A pl="n" gnt="y" gnd="f">(?:fh?earr|mh?\x{f3}|mh?\x{f3}ide)<\/A>)/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)*<V cop="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>( (?:<A[^>]*>(?:h?ioma\x{ed}|l\x{e9}ir|n\x{e1}ir)<\/A>|<B><Z>(?:<A[^>]*>)+<\/Z>(?:h?ioma\x{ed}|l\x{e9}ir|n\x{e1}ir)<\/B>))/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)*<V cop="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>( (?:<[\/A-DF-Z][^>]*>)+(?:c\x{f3}ir|cuma|deacair|dh?\x{e9}ana\x{ed}|deimhin|dh?ual|h?ea|\x{e9}ard|fi\x{fa}|maith|mh?ithid)<\/[A-DF-Z]>)/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(Ach)<\/B>()/$1<C>$2<\/C>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(\x{e1}irithe)<\/B>()/$1<A>$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Hh]al\x{f3})<\/B>()/$1<I>$2<\/I>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]lt)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]ma)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]s)<\/B>( <T>na<\/T>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]s)<\/B>( (?:<[\/A-DF-Z][^>]*>)+an<\/[A-DF-Z]>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]s)<\/B>( (?:<N[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>[^<]+<\/B>))/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(ann)<\/B>()/$1<O>$2<\/O>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]n)<\/B>( <N pl="n" gnt="n" gnd="f">c\x{fa}is<\/N>)/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]n)<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<Q>$2<\/Q>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]n)<\/B>( (?:<[\/A-DF-Z][^>]*>)+amhlaidh<\/[A-DF-Z]>)/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]n)<\/B>( (?:<[\/A-DF-Z][^>]*>)+mar<\/[A-DF-Z]>)/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]n)<\/B>( (?:<P[^>]*>t\x{e9}<\/P>|<B><Z>(?:<P[^>]*>)+<\/Z>t\x{e9}<\/B>))/$1<T>$2<\/T>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]n)<\/B>( (?:<[PRSO][^>]*>[^<]+<\/[PRSO]>|<B><Z>(?:<[PRSO][^>]*>)+<\/Z>[^<]+<\/B>))/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]n)<\/B>( (?:<[\/A-DF-Z][^>]*>)+leis<\/[A-DF-Z]>)/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]n)<\/B>( (?:<[\/A-DF-Z][^>]*>)+de<\/[A-DF-Z]>)/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]n)<\/B>( (?:<[\/A-DF-Z][^>]*>)+faoi<\/[A-DF-Z]>)/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(an)<\/B>( (?:<[\/A-DF-Z][^>]*>)+(?:chuir|mh?aith|n\x{ed})<\/[A-DF-Z]>)/$1<T>$2<\/T>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]n)<\/B>( (?:<[^\/V][^>]*>[^<]+<\/[^V]>|<B><Z>(?:<[^V][^>]*>)+<\/Z>[^<]+<\/B>))/$1<T>$2<\/T>$3/g;
	s/(<S>[^<]+<\/S> )<B><Z>(?:<[^>]+>)+<\/Z>([Aa]n)<\/B>()/$1<T>$2<\/T>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]nuas)<\/B>()/$1<R>$2<\/R>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Mm]ar<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>(aon)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]on)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/(<T>[Aa]n<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>(\x{e1}r)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(\x{e1}r)<\/B>( <C>[^<]+<\/C>)/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(\x{e1}r)<\/B>( <T>[^<]+<\/T>)/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([\x{c1}\x{e1}]r)<\/B>()/$1<D>$2<\/D>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]t\x{e1})<\/B>()/$1<V p="y" t="l\x{e1}ith">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(h[Aa]thair)<\/B>()/$1<N pl="n" gnt="n" gnd="m" h="y">$2<\/N>$3/g;
	s/(<T>[Nn]a<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>(ba)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Bb]a)<\/B>()/$1<V cop="y">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+(?:[Gg]o|[Nn]ach)<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>(m[Bb]a)<\/B>()/$1<V cop="y">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Dd]h?\x{e1}<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>(m[Bb]a)<\/B>()/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Bb]haineann)<\/B>()/$1<V p="y" t="l\x{e1}ith">$2<\/V>$3/g;
	s/(<T>[Aa]n<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>([Bb]arra)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Bb]h?arr)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Bb]h?eag)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Bb]h\x{ed})<\/B>()/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Cc]\x{e1})<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<Q>$2<\/Q>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Cc]\x{e1})<\/B>( (?:<[\/A-DF-Z][^>]*>)+(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/[A-DF-Z]>)/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(g?[Cc]h?airde)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Cc]\x{e1}r)<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<Q>$2<\/Q>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Cc]\x{e1}r)<\/B>( (?:<[\/A-DF-Z][^>]*>)+(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[A-DF-Z]>)/$1<Q>$2<\/Q>$3/g;
	s/(<T>na<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>([Cc]\x{e9})<\/B>()/$1<N pl="n" gnt="y" gnd="f">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Cc][\x{c9}\x{e9}])<\/B>()/$1<Q>$2<\/Q>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Cc]h?\x{e9}anna)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+(?:a|\x{e1})<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>(dh\x{f3})<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z><N pl="n" gnt="n" gnd="m".><N pl="n" gnt="y" gnd="m".><A pl="n" gnt="n".><\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+d?[Tt]h?r\x{ed}<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>([Bb]liana)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<A pl="n" gnt="n">g?[Cc]h?eithre<\/A> )<B><Z>(?:<[^>]+>)+<\/Z>([Bb]liana)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<A pl="n" gnt="n">g?[Cc]h?\x{fa}ig<\/A> )<B><Z>(?:<[^>]+>)+<\/Z>([Bb]liana)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$2<\/N>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Ss]h?\x{e9}<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>([Bb]liana)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<A pl="n" gnt="n">[Ss]h?eacht<\/A> )<B><Z>(?:<[^>]+>)+<\/Z>(m[Bb]liana)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<A pl="n" gnt="n">h?[Oo]cht<\/A> )<B><Z>(?:<[^>]+>)+<\/Z>(m[Bb]liana)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<A pl="n" gnt="n">[Nn]aoi<\/A> )<B><Z>(?:<[^>]+>)+<\/Z>(m[Bb]liana)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<A pl="n" gnt="n">n?[Dd]h?eich<\/A> )<B><Z>(?:<[^>]+>)+<\/Z>(m[Bb]liana)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(m?[Bb]h?liana)<\/B>()/$1<N pl="n" gnt="y" gnd="f">$2<\/N>$3/g;
	s/(<T>[Aa]n<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>([Cc]heathr\x{fa})<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/(<S>(?:[Dd][eo]n|[Ss]an?|[Ff]aoin|[\x{d3}\x{f3}]n)<\/S> )<B><Z>(?:<[^>]+>)+<\/Z>([Cc]heathr\x{fa})<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(g?[Cc]h?eathr\x{fa})<\/B>( (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/B>))/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(g?[Cc]h?eathr\x{fa})<\/B>( (?:<N[^>]*h="y"[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*h="y"[^>]*>)+<\/Z>[^<]+<\/B>))/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Cc]hinn)<\/B>( <N pl="n" gnt="y" gnd="f">[Bb]liana<\/N>)/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/(<T>[Nn]a<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>(cinn)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$2<\/N>$3/g;
	s/((?:<[SV][^>]*>[^<]+<\/[SV]>|<B><Z>(?:<[SV][^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>(?:<[^>]+>)+<\/Z>(cinn)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(cinn)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Cc]omhalta)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(g?ch?\x{f3}na\x{ed})<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Cc]ora)<\/B>( <N pl="n" gnt="y" gnd="f">[Cc]ainte<\/N>)/$1<N pl="y" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<T>an<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>([Cc]huir)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Cc]huir)<\/B>()/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Cc]uir)<\/B>()/$1<V p="y" t="ord">$2<\/V>$3/g;
	s/(<T>na<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>(g[Cc]umann)<\/B>()/$1<N pl="y" gnt="y" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(g?[Cc]h?umann)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Aa]o?n<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>(d\x{e1})<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+g?ch?\x{e9}ad<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>(d\x{e1})<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/(<S>[Ss]a<\/S> )<B><Z>(?:<[^>]+>)+<\/Z>(d\x{e1})<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/(<T>[Aa]n<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>([Dd]\x{e1})<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Dd]\x{e1})<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<C>$2<\/C>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Dd]\x{e1})<\/B>( (?:<N[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>[^<]+<\/B>))/$1<D>$2<\/D>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Dd]\x{e1})<\/B>( (?:<[\/A-DF-Z][^>]*>)+h[^<]+<\/[A-DF-Z]>)/$1<D>$2<\/D>$3/g;
	s/(<T>an<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>(d\x{e1}la)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(D\x{e9})<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Dd]eas)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Dd]\x{e9}ag)<\/B>()/$1<N pl="n" gnt="n">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(n?[Dd]h?earna)<\/B>()/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Dd]eir)<\/B>()/$1<V p="y" t="l\x{e1}ith">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Dd]eireadh)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(d\x{ed}o?bh)<\/B>()/$1<O>$2<\/O>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Dd]o)<\/B>( <T>na<\/T>)/$1<S>$2<\/S>$3/g;
	s/(<S>[^<]+<\/S> )<B><Z>(?:<[^>]+>)+<\/Z>(do)<\/B>()/$1<D>$2<\/D>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(do)<\/B>( <D>[^<]+<\/D>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(do)<\/B>( <Y>[^<]+<\/Y>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(do)<\/B>( <A pl="n" gnt="n">gach<\/A>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(do)<\/B>( (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*gnt="y"[^>]*>)+<\/Z>[^<]+<\/B>))/$1<D>$2<\/D>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>(d\x{f3})<\/B>()/$1<N pl="n" gnt="n">$2<\/N>$3/g;
	s/(<T>an<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>(d\x{f3})<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(d\x{f3}igh)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(Dh?\x{fa}n)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([\x{c9}\x{e9}])<\/B>()/$1<P>$2<\/P>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ff]aoi)<\/B>( <T>na<\/T>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ff]aoi)<\/B>( (?:<[\/A-DF-Z][^>]*>)+an<\/[A-DF-Z]>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ff]aoi)<\/B>( (?:<N[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>[^<]+<\/B>))/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ff]eadh)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<T>na<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>(bh[Ff]ear)<\/B>()/$1<N pl="y" gnt="y" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>((?:bh)?[Ff]h?ear)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ff]\x{e9}in)<\/B>()/$1<R>$2<\/R>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>((?:bh)?[Ff]uair)<\/B>()/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>(Gabhann)<\/B>()/$1<Y>$2<\/Y>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(Gabhann)<\/B>()/$1<V p="y" t="l\x{e1}ith">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(g[Cc]inn)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Gg]o)<\/B>( (?:<A[^>]*>[^<]+<\/A>|<B><Z>(?:<A[^>]*>)+<\/Z>[^<]+<\/B>))/$1<U>$2<\/U>$3/g;
	s/(<T>na<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>(huaire)<\/B>()/$1<N pl="n" gnt="y" gnd="f" h="y">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(huaire)<\/B>()/$1<N pl="y" gnt="n" gnd="f" h="y">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(iompair)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ii]onam)<\/B>()/$1<O>$2<\/O>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(iontach)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/()<B><Z><R.><A pl="n" gnt="n".><\/Z>([^<]+)<\/B>()/$1<R>$2<\/R>$3/g;
	s/((?:<[^\/ST][^>]*>[^<]+<\/[^ST]>|<B><Z>(?:<[^ST][^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>(?:<[^>]+>)+<\/Z>(theas)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ll]\x{e1}n)<\/B>( (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*pl="y"[^>]*>)+<\/Z>[^<]+<\/B>))/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ll]\x{e1}n)<\/B>( <D>[^<]+<\/D>)/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ll]\x{e1}n)<\/B>( <S>de<\/S>)/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/(<S>[Ll]e<\/S> )<B><Z>(?:<[^>]+>)+<\/Z>((?:haon|hocht))<\/B>()/$1<A pl="n" gnt="n" h="y">$2<\/A>$3/g;
	s/(<S>[Ll]e<\/S> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="n" gnd="m" h="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m" h="y">$2<\/N>$3/g;
	s/(<S>[Ll]e<\/S> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="n" gnd="f" h="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f" h="y">$2<\/N>$3/g;
	s/(<S>[Ll]e<\/S> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="n" gnd="m" h="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m" h="y">$2<\/N>$3/g;
	s/(<S>[Ll]e<\/S> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="n" gnd="f" h="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="f" h="y">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ll]\x{e9}inn)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ll]eis)<\/B>( <T>[Nn]a<\/T>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ll]eis)<\/B>( (?:<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ll]eith)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ll]eo)<\/B>()/$1<O>$2<\/O>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>([Ll]inne)<\/B>()/$1<N pl="n" gnt="y" gnd="f">$2<\/N>$3/g;
	s/((?:<[DT][^>]*>[^<]+<\/[DT]>|<B><Z>(?:<[DT][^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>(?:<[^>]+>)+<\/Z>([Ll]inne)<\/B>()/$1<N pl="n" gnt="y" gnd="f">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ll]inne)<\/B>()/$1<O em="y">$2<\/O>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Mm]\x{e1})<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<C>$2<\/C>$3/g;
	s/(<S>[^<]+<\/S> )<B><Z>(?:<[^>]+>)+<\/Z>(mh?aith)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<T>an<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>(mh?aith)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<A pl="n" gnt="n">[Aa]on<\/A> )<B><Z>(?:<[^>]+>)+<\/Z>(mh?aith)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Mm]h?aith)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Mm]ar)<\/B>( (?:<[\/A-DF-Z][^>]*>)+gheall<\/[A-DF-Z]>)/$1<S>$2<\/S>$3/g;
	s/(<T>an<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>(mheasa)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(mh?easa)<\/B>()/$1<A pl="n" gnt="y" gnd="f">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Mm]h?\x{f3}r)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/(<T>[Nn]a<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>((?:haon|hocht))<\/B>()/$1<A pl="n" gnt="n" h="y">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Nn]\x{e1})<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<U>$2<\/U>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Nn]\x{e1}<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)*<V p="y" t="ord".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<V p="y" t="ord">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Nn]\x{e1})<\/B>()/$1<C>$2<\/C>$3/g;
	s/()<B><Z><N pl="n" gnt="n" gnd="m" h="y".><V p="y" t="ord".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m" h="y">$2<\/N>$3/g;
	s/()<B><Z><N pl="n" gnt="n" gnd="f" h="y".><V p="y" t="ord".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f" h="y">$2<\/N>$3/g;
	s/((?:<N[^>]*>Spiorad<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>Spiorad<\/B>) )<B><Z>(?:<[^>]+>)+<\/Z>(Naomh)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/(<T>na<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>([Nn]aomh)<\/B>()/$1<N pl="y" gnt="y" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Nn]aomh)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<T>[Aa]n<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>([Nn]\x{ed})<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Nn]\x{ed})<\/B>( (?:<[\/A-DF-Z][^>]*>)+nach<\/[A-DF-Z]>)/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Nn]\x{ed})<\/B>( (?:<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]>)/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<A pl="n" gnt="n">(?:[Aa]on|[Gg]ach)<\/A> )<B><Z>(?:<[^>]+>)+<\/Z>([Nn]\x{ed})<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Nn]\x{ed})<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<U>$2<\/U>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Nn]\x{ed})<\/B>( <A pl="n" gnt="n">m\x{f3}r<\/A>)/$1<V cop="y">$2<\/V>$3/g;
	s/(<C>[^<]+<\/C> )<B><Z>(?:<[^>]+>)+<\/Z>(n\x{ed})<\/B>( (?:<[^\/V][^>]*>[^<]+<\/[^V]>|<B><Z>(?:<[^V][^>]*>)+<\/Z>[^<]+<\/B>))/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Nn]\x{ed})<\/B>( (?:<N[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>[^<]+<\/B>))/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Nn]\x{ed})<\/B>( (?:<P[^>]*>[^<]+<\/P>|<B><Z>(?:<P[^>]*>)+<\/Z>[^<]+<\/B>))/$1<V cop="y">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>(N\x{ed}l)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<S>[^<]+<\/S> )<B><Z>(?:<[^>]+>)+<\/Z>(N\x{ed}l)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(N\x{ed}l)<\/B>()/$1<V p="y" t="l\x{e1}ith">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Nn]uair)<\/B>()/$1<C>$2<\/C>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(os)<\/B>()/$1<S>$2<\/S>$3/g;
	s/(<T>na<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>([Rr]inne)<\/B>()/$1<N pl="n" gnt="y" gnd="f">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Rr]inne)<\/B>()/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(San)<\/B>( (?:<[\/A-DF-Z][^>]*>)+[A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]>)/$1<N pl="n" gnt="n">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(San)<\/B>()/$1<S>$2<\/S>$3/g;
	s/(<T>na<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>(s\x{ed})<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(s\x{ed})<\/B>()/$1<P>$2<\/P>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+\x{d3}<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>(S\x{e9})<\/B>()/$1<Y>$2<\/Y>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ss]\x{e9})<\/B>( (?:<[\/A-DF-Z][^>]*>)+(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[A-DF-Z]>)/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>(s\x{e9})<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/((?:<P[^>]*>s\x{ed}<\/P>|<B><Z>(?:<P[^>]*>)+<\/Z>s\x{ed}<\/B>) <C>n\x{f3}<\/C> )<B><Z>(?:<[^>]+>)+<\/Z>(s\x{e9})<\/B>()/$1<P>$2<\/P>$3/g;
	s/((?:<[^\/V][^>]*>[^<]+<\/[^V]>|<B><Z>(?:<[^V][^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>(?:<[^>]+>)+<\/Z>([Ss]\x{e9})<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ss]\x{e9})<\/B>()/$1<P>$2<\/P>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ss]iad)<\/B>()/$1<P>$2<\/P>$3/g;
	s/(<S>[Ss]na<\/S> )<B><Z>(?:<[^>]+>)+<\/Z>((?:haon|hocht))<\/B>()/$1<A pl="n" gnt="n" h="y">$2<\/A>$3/g;
	s/(<S>[Ss]na<\/S> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="n" gnd="m" h="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m" h="y">$2<\/N>$3/g;
	s/(<S>[Ss]na<\/S> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="n" gnd="f" h="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="f" h="y">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ss]n\x{e1}mh)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Tt]har)<\/B>()/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Tt]hart)<\/B>()/$1<R>$2<\/R>$3/g;
	s/((?:<N[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>(?:<[^>]+>)+<\/Z>(thoir)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/((?:<N[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>(?:<[^>]+>)+<\/Z>(Thoir)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Tt]hoir)<\/B>()/$1<R>$2<\/R>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(T[Hh][Ee])<\/B>()/$1<F>$2<\/F>$3/g;
	s/((?:<[^\/N][^>]*>[^<]+<\/[^N]>|<B><Z>(?:<[^N][^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>(?:<[^>]+>)+<\/Z>(the)<\/B>()/$1<F>$2<\/F>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Tt][Hh][Ee])<\/B>( <X>[^<]+<\/X>)/$1<F>$2<\/F>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(theannta)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Tt]h?\x{ed})<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/(<T>[^<]+<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>([Tt]r\x{ed})<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Tt]r\x{ed})<\/B>( (?:<[\/A-DF-Z][^>]*>)+(?:bliana|cinn|fichid|seachtaine)<\/[A-DF-Z]>)/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Tt]r\x{ed})<\/B>()/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Tt]r\x{ed}d)<\/B>( <T>na<\/T>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Tt]r\x{ed}d)<\/B>( (?:<[\/A-DF-Z][^>]*>)+an<\/[A-DF-Z]>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Tt]r\x{ed}d)<\/B>()/$1<O>$2<\/O>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Aa]r<\/[A-DF-Z]> <T>[Aa]n<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>(Aire)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<S>[^<]+<\/S> <T>[Aa]n<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>(Aire)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<T>[Aa]n<\/T> )<B><Z>(?:<[^>]+>)+<\/Z>(Aire)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(Aire)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>((?:n-)?aire)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/((?:<[^\/ACNRSY][^>]*>[^<]+<\/[^ACNRSY]>|<B><Z>(?:<[^ACNRSY][^>]*>)+<\/Z>[^<]+<\/B>) (?:<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>([Gg]hl\x{f3}ir)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>((?:[Cc]h\x{e1}il|[CcMm]hoill|[Cc]hoir|[Gg]hr\x{e1}in))<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/((?:<[^\/S][^>]*>[^<]+<\/[^S]>|<B><Z>(?:<[^S][^>]*>)+<\/Z>[^<]+<\/B>) (?:<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="y" gnd="m".>(?:<[^>]+>)*<\/Z>((?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/(<S>[Cc]hun<\/S> (?:<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="y" gnd="m".>(?:<[^>]+>)*<\/Z>((?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(Inis)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)*<V p="y" t="ord".><V p="y" t="caite".>(?:<[^>]+>)*<\/Z>([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*)<\/B>()/$1<V p="y" t="ord">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+(?:[Gg]ur|[Mm]urar|[Ss]ular)<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)*<V p="y" t="caite".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/(<S>(?:d\x{e1}r|(?:faoi|i|le|\x{f3}|tr\x{ed})nar)<\/S> )<B><Z>(?:<[^>]+>)*<V p="y" t="caite".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+(?:[Cc]\x{e1}r|[Cc]har|[Nn]\x{e1}r|[Nn]\x{ed}or)<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)*<V p="y" t="caite".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)*<V p="y" t="ord".><V p="y" t="caite".>(?:<[^>]+>)*<\/Z>([AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*)<\/B>()/$1<V p="y" t="ord">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+(?:[Gg]ur|[Mm]urar|[Ss]ular)<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)*<V p="y" t="caite".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/(<S>(?:d\x{e1}r|(?:faoi|i|le|\x{f3}|tr\x{ed})nar)<\/S> )<B><Z>(?:<[^>]+>)*<V p="y" t="caite".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+(?:[Cc]\x{e1}r|[Cc]har|[Nn]\x{e1}r|[Nn]\x{ed}or)<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)*<V p="y" t="caite".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Aa]r<\/[A-DF-Z]> )<B><Z>((?:<[^>]+>)*<V p="y" t="ord".><V p="y" t="caite".>(?:<[^>]+>)*)<\/Z>([^<]+)<\/B>()/"$1".strip_badpos($2,$3,'<V p="y" t="ord".>')."$4"/eg;
	s/((?:<[\/A-DF-Z][^>]*>)+[Aa]r<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)*<V p="n" t="caite".>(?:<[^>]+>)*<\/Z>((?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*)<\/B>()/$1<V p="n" t="caite">$2<\/V>$3/g;
	s/(<T>na<\/T> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="y" gnd="m".>(?:<[^>]+>)*<\/Z>((?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*)<\/B>()/$1<N pl="y" gnt="y" gnd="m">$2<\/N>$3/g;
	s/(<T>na<\/T> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="y" gnd="f".>(?:<[^>]+>)*<\/Z>((?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*)<\/B>()/$1<N pl="y" gnt="y" gnd="f">$2<\/N>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+(?:[Cc]ois|[Dd]\x{e1}la|[Ff]earacht|[Tt]impeall|[Tt]rasna)<\/[A-DF-Z]> <T>an<\/T> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="y" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+(?:[Cc]ois|[Dd]\x{e1}la|[Ff]earacht|[Tt]impeall|[Tt]rasna)<\/[A-DF-Z]> <T>na<\/T> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="y" gnd="f".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="f">$2<\/N>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+(?:[Cc]ois|[Dd]\x{e1}la|[Ff]earacht|[Tt]impeall|[Tt]rasna)<\/[A-DF-Z]> <T>na<\/T> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="y" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="y" gnd="m">$2<\/N>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+(?:[Cc]ois|[Dd]\x{e1}la|[Ff]earacht|[Tt]impeall|[Tt]rasna)<\/[A-DF-Z]> <T>na<\/T> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="y" gnd="f".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="y" gnd="f">$2<\/N>$3/g;
	s/(<S>[Gg]o dt\x{ed}<\/S> <T>an<\/T> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="n" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<S>[Gg]o dt\x{ed}<\/S> <T>na<\/T> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="n" gnd="f".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<S>[Gg]o dt\x{ed}<\/S> <T>na<\/T> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="n" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<S>[^< ]+ [^<]+<\/S> <T>an<\/T> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="y" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/(<S>[^< ]+ [^<]+<\/S> <T>na<\/T> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="y" gnd="f".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="f">$2<\/N>$3/g;
	s/(<S>[^< ]+ [^<]+<\/S> <T>na<\/T> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="y" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="y" gnd="m">$2<\/N>$3/g;
	s/(<S>[^< ]+ [^<]+<\/S> <T>na<\/T> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="y" gnd="f".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="y" gnd="f">$2<\/N>$3/g;
	s/(<S>[^<]+<\/S> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="n" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<S>[^<]+<\/S> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="n" gnd="f".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<S>[^<]+<\/S> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="n" gnd="f".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<S>[^<]+<\/S> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="n" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$2<\/N>$3/g;
	s/((?:<N[^>]*>[Dd]\x{ed}s|[Dd]h?osaen|[Pp]h?\x{e9}ire<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>[Dd]\x{ed}s|[Dd]h?osaen|[Pp]h?\x{e9}ire<\/B>) )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="y" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="y" gnd="m">$2<\/N>$3/g;
	s/((?:<N[^>]*>[Dd]\x{ed}s|[Dd]h?osaen|[Pp]h?\x{e9}ire<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>[Dd]\x{ed}s|[Dd]h?osaen|[Pp]h?\x{e9}ire<\/B>) )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="y" gnd="f".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="y" gnd="f">$2<\/N>$3/g;
	s/(<N pl="n" gnt="n" gnd="m">[Cc]h?\x{fa}pla<\/N> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="n" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<N pl="n" gnt="n" gnd="m">[Cc]h?\x{fa}pla<\/N> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="n" gnd="f".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/((?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>(?:<[^>]+>)+<\/Z>(d\x{f3})<\/B>()/$1<O>$2<\/O>$3/g;
	s/((?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*pl="n" gnt="n"[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="y" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/((?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*pl="n" gnt="n"[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="y" gnd="f".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="f">$2<\/N>$3/g;
	s/()<B><Z><S.><R.>(?:<A pl="n" gnt="n".>)?<\/Z>([^<]+)<\/B>()/$1<R>$2<\/R>$3/g;
	s/((?:<N[^>]*pl="y" gnt="y"[^>]*>[^<]*[a\x{e1}o\x{f3}u\x{fa}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}<]+<\/N>|<B><Z>(?:<N[^>]*pl="y" gnt="y"[^>]*>)+<\/Z>[^<]*[a\x{e1}o\x{f3}u\x{fa}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}<]+<\/B>) )<B><Z>(?:<[^>]+>)*<A pl="n" gnt="n".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/((?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*pl="y"[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>(?:<N pl="y"[^>]+>)*(?:<A[^>]*>)*<A pl="y" gnt="n".><\/Z>([^<]+)<\/B>()/$1<A pl="y" gnt="n">$2<\/A>$3/g;
	s/((?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*pl="n" gnt="n"[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>(?:<N pl="y"[^>]+>)*<A pl="n" gnt="n".>(?:<A[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/(<A pl="y" gnt="n">[^<]+<\/A> )<B><Z>(?:<N pl="y"[^>]+>)*(?:<A[^>]*>)*<A pl="y" gnt="n".><\/Z>([^<]+)<\/B>()/$1<A pl="y" gnt="n">$2<\/A>$3/g;
	s/(<A pl="n" gnt="y" gnd="f">[^<]+<\/A> )<B><Z>(?:<N pl="y"[^>]+>)*(?:<A[^>]*>)*<A pl="n" gnt="y" gnd="f".>(?:<A[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="y" gnd="f">$2<\/A>$3/g;
	s/(<A pl="n" gnt="y" gnd="m">[^<]+<\/A> )<B><Z>(?:<N pl="y"[^>]+>)*(?:<A[^>]*>)*<A pl="n" gnt="y" gnd="m".>(?:<A[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="y" gnd="m">$2<\/A>$3/g;
	s/((?:<A[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/A>|<B><Z>(?:<A[^>]*pl="n" gnt="n"[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>(?:<N pl="y"[^>]+>)*<A pl="n" gnt="n".>(?:<A[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/(<T>[Nn]a<\/T> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="n" gnd="f".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<T>[Nn]a<\/T> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="n" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<S>[Ss]na<\/S> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="n" gnd="f".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<S>[Ss]na<\/S> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="n" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$2<\/N>$3/g;
	s/((?:<[ANR][^>]*>[^<]+<\/[ANR]>|<B><Z>(?:<[ANR][^>]*>)+<\/Z>[^<]+<\/B>) (?:<[\/A-DF-Z][^>]*>)+an<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="y" gnd="m".>(?:<[^>]+>)*<\/Z>([aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Gg]o<\/[A-DF-Z]> )<B><Z>(?:<N pl="y"[^>]+>)*<A pl="n" gnt="n".>(?:<A[^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/(<R>[Cc]homh<\/R> )<B><Z>(?:<[^>]+>)*<A pl="n" gnt="n".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/(<R>[Cc]homh<\/R> )<B><Z>(?:<[^>]+>)*<A pl="n" gnt="n" h="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n" h="y">$2<\/A>$3/g;
	s/(<R>[Nn]\x{ed}os<\/R> )<B><Z>(?:<N pl="y"[^>]+>)*(?:<[^>]+>)*<A pl="n" gnt="y" gnd="f".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="y" gnd="f">$2<\/A>$3/g;
	s/(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> )<B><Z>(?:<N pl="y"[^>]+>)*(?:<[^>]+>)*<A pl="n" gnt="y" gnd="f".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="y" gnd="f">$2<\/A>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+is<\/[A-DF-Z]> )<B><Z>(?:<N pl="y"[^>]+>)*(?:<[^>]+>)*<A pl="n" gnt="y" gnd="f".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="y" gnd="f">$2<\/A>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Gg]o<\/[A-DF-Z]> )<B><Z>(?:<N[^>]+>)+<A pl="n" gnt="n".>(?:<[AV][^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Gg]o<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)*<A pl="n" gnt="n" h="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n" h="y">$2<\/A>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Gg]o<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="n" gnd="m" h="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m" h="y">$2<\/N>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Gg]o<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="n" gnd="f" h="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f" h="y">$2<\/N>$3/g;
	s/(<S>[^<]+<\/S> )<B><Z><N pl="n" gnt="n" gnd="m".>(?:<N pl="y" gnt="y" gnd="m".>)?<A pl="n" gnt="n".>(?:<[A-Z][^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<T>[Aa]n<\/T> )<B><Z><N pl="n" gnt="n" gnd="m".>(?:<N pl="y" gnt="y" gnd="m".>)?<A pl="n" gnt="n".>(?:<[A-Z][^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/((?:<N[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z><N pl="n" gnt="n" gnd="m".>(?:<N pl="y" gnt="y" gnd="m".>)?<A pl="n" gnt="n".>(?:<[A-Z][^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/(<S>[^<]+<\/S> )<B><Z><N pl="n" gnt="n" gnd="f".><A pl="n" gnt="n".>(?:<[A-Z][^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<T>[Aa]n<\/T> )<B><Z><N pl="n" gnt="n" gnd="f".><A pl="n" gnt="n".>(?:<[A-Z][^>]*>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/((?:<N[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z><N pl="n" gnt="n" gnd="f".><A pl="n" gnt="n".>(?:<[A-Z][^>]*>)*<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/(<S>[^<]+<\/S> )<B><Z><N pl="n" gnt="n" gnd="m".>(?:<V p="y"[^>]+>)+<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<T>[Aa]n<\/T> )<B><Z><N pl="n" gnt="n" gnd="m".>(?:<V p="y"[^>]+>)+<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z><N pl="n" gnt="n" gnd="m".>(?:<V p="y"[^>]+>)+<\/Z>([^<]+)<\/B>( (?:<P[^>]*>[^<]+<\/P>|<B><Z>(?:<P[^>]*>)+<\/Z>[^<]+<\/B>))/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z><N pl="n" gnt="n" gnd="m".>(?:<V p="y"[^>]+>)+<\/Z>([^<]+)<\/B>( (?:<[\/A-DF-Z][^>]*>)+s\x{e9}<\/[A-DF-Z]>)/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z><N pl="n" gnt="n" gnd="m".>(?:<V p="y"[^>]+>)+<\/Z>([^<]+)<\/B>( (?:<N[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>[^<]+<\/B>))/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z><N pl="n" gnt="n" gnd="m".>(?:<V p="y"[^>]+>)+<\/Z>([^<]+)<\/B>( <Y>[^<]+<\/Y>)/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/((?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z><N pl="n" gnt="n" gnd="m".>(?:<V p="y"[^>]+>)+<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<S>[^<]+<\/S> )<B><Z><N pl="n" gnt="n" gnd="f".>(?:<V p="y"[^>]+>)+<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<T>[Aa]n<\/T> )<B><Z><N pl="n" gnt="n" gnd="f".>(?:<V p="y"[^>]+>)+<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z><N pl="n" gnt="n" gnd="f".>(?:<V p="y"[^>]+>)+<\/Z>([^<]+)<\/B>( (?:<P[^>]*>[^<]+<\/P>|<B><Z>(?:<P[^>]*>)+<\/Z>[^<]+<\/B>))/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z><N pl="n" gnt="n" gnd="f".>(?:<V p="y"[^>]+>)+<\/Z>([^<]+)<\/B>( (?:<[\/A-DF-Z][^>]*>)+s\x{e9}<\/[A-DF-Z]>)/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z><N pl="n" gnt="n" gnd="f".>(?:<V p="y"[^>]+>)+<\/Z>([^<]+)<\/B>( (?:<N[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>[^<]+<\/B>))/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z><N pl="n" gnt="n" gnd="f".>(?:<V p="y"[^>]+>)+<\/Z>([^<]+)<\/B>( <Y>[^<]+<\/Y>)/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/((?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z><N pl="n" gnt="n" gnd="f".>(?:<V p="y"[^>]+>)+<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[\x{d3}\x{f3}]<\/[A-DF-Z]> )<B><Z><N pl="n" gnt="n" gnd="m".><V p="n" t="caite".><V p="y" t="ord".>(?:<V p="y" t="gn\x{e1}th".>)?<\/Z>((?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*)<\/B>()/$1<V p="n" t="caite">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z><N pl="n" gnt="n" gnd="m".><V p="n" t="caite".><V p="y" t="ord".>(?:<V p="y" t="gn\x{e1}th".>)?<\/Z>((?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]> )<B><Z><N pl="n" gnt="n" gnd="m".><V p="n" t="caite".><V p="y" t="ord".>(?:<V p="y" t="gn\x{e1}th".>)?<\/Z>((?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*)<\/B>()/$1<V p="n" t="caite">$2<\/V>$3/g;
	s/()<B><Z><R.><N pl="n" gnt="n".><\/Z>([^<]+)<\/B>()/$1<R>$2<\/R>$3/g;
	s/()<B><Z><S.><D.><\/Z>([^<][^<][^<]+)<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<S>$2<\/S>$3/g;
	s/()<B><Z><S.><D.><\/Z>([^<][^<][^<]+)<\/B>()/$1<D>$2<\/D>$3/g;
	s/()<B><Z><N pl="y" gnt="n".><N pl="y" gnt="n" gnd="m".><\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z><Y.>(?:<[^>]+>)+<\/Z>([^<]+)<\/B>()/$1<Y>$2<\/Y>$3/g;
	s/()<B><Z><N pl="n" gnt="n" gnd="m".><V p="." t="foshuit".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z><N pl="y" gnt="n" gnd="m".><V p="." t="foshuit".><\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z><N pl="y" gnt="n" gnd="f".><V p="." t="foshuit".><\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$2<\/N>$3/g;
	s/()<B><Z><N pl="y" gnt="n".><N pl="y" gnt="n" gnd="f".><\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$2<\/N>$3/g;
	s/()<B><Z><V p="y" t="l\x{e1}ith".><V p="y" t="foshuit".><\/Z>([^<]+)<\/B>()/$1<V p="y" t="l\x{e1}ith">$2<\/V>$3/g;
	s/()<B><Z><N pl="n" gnt="y" gnd="f".><V p="." t="foshuit".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="f">$2<\/N>$3/g;
	s/()<B><Z><A pl="y" gnt="n".><V p="." t="foshuit".><\/Z>([^<]+)<\/B>()/$1<A pl="y" gnt="n">$2<\/A>$3/g;
	s/(<T>[^<]+<\/T> )<B><Z><N pl="n" gnt="y" gnd="f".><A pl="n" gnt="n".><A pl="n" gnt="y" gnd="f".><A pl="n" gnt="y" gnd="m".><A pl="y" gnt="n".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="f">$2<\/N>$3/g;
	s/(<T>[^<]+<\/T> )<B><Z><N pl="n" gnt="y" gnd="m".><A pl="n" gnt="n".><A pl="n" gnt="y" gnd="f".><A pl="n" gnt="y" gnd="m".><A pl="y" gnt="n".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/()<B><Z><N pl="n" gnt="y" gnd="f".><A pl="n" gnt="n".><A pl="n" gnt="y" gnd="f".><A pl="n" gnt="y" gnd="m".><A pl="y" gnt="n".><\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/()<B><Z><N pl="n" gnt="y" gnd="m".><A pl="n" gnt="n".><A pl="n" gnt="y" gnd="f".><A pl="n" gnt="y" gnd="m".><A pl="y" gnt="n".><\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]> )<B><Z>(?:<[^N][^>]*>)*<N pl="n" gnt="y" gnd="m".><N pl="y" gnt="n" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/(<A pl="n" gnt="n">(?:[Aa]on|[Gg]ach)<\/A> )<B><Z>(?:<[^N][^>]*>)*<N pl="n" gnt="y" gnd="m".><N pl="y" gnt="n" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="n" gnd="m".><N pl="y" gnt="y" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<A pl="n" gnt="n">(?:[Aa]on|[Gg]ach)<\/A> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="n" gnd="m".><N pl="y" gnt="y" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<T>na<\/T> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="n" gnd="m".><N pl="y" gnt="y" gnd="m".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="y" gnd="m">$2<\/N>$3/g;
	s/()<B><Z><N pl="n" gnt="n" gnd="m".><N pl="y" gnt="y" gnd="m".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<T>na<\/T> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="n" gnd="f".><N pl="y" gnt="y" gnd="f".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="y" gnd="f">$2<\/N>$3/g;
	s/()<B><Z><N pl="n" gnt="n" gnd="f".><N pl="y" gnt="y" gnd="f".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/((?:<N[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>[^<]+<\/B>) <T>[Aa]n<\/T> )<B><Z><N pl="n" gnt="n" gnd="f".><N pl="n" gnt="y" gnd="m".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/(<T>[Aa]n<\/T> )<B><Z><N pl="n" gnt="n" gnd="f".><N pl="n" gnt="y" gnd="m".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/((?:<[^\/N][^>]*>[^<]+<\/[^N]>|<B><Z>(?:<[^N][^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z><N pl="n" gnt="n" gnd="f".><N pl="n" gnt="y" gnd="m".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<S>[^<]+<\/S> <T>[Aa]n<\/T> )<B><Z><N pl="n" gnt="n" gnd="m".><N pl="n" gnt="y" gnd="m".>(?:<V p="." t="foshuit".>)?<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<T>[Aa]n<\/T> )<B><Z><N pl="n" gnt="n" gnd="m".><N pl="n" gnt="y" gnd="m".>(?:<V p="." t="foshuit".>)?<\/Z>((?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<S>[^<]+<\/S> <T>[Aa]n<\/T> )<B><Z><N pl="n" gnt="n" gnd="m".><N pl="n" gnt="y" gnd="m".>(?:<V p="." t="foshuit".>)?<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Aa]r<\/[A-DF-Z]> <T>[Aa]n<\/T> )<B><Z><N pl="n" gnt="n" gnd="m".><N pl="n" gnt="y" gnd="m".>(?:<V p="." t="foshuit".>)?<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/(<T>[Aa]n<\/T> )<B><Z><N pl="n" gnt="n" gnd="m".><N pl="n" gnt="y" gnd="m".>(?:<V p="." t="foshuit".>)?<\/Z>((?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/((?:<[^\/T][^>]*>[^<]+<\/[^T]>|<B><Z>(?:<[^T][^>]*>)+<\/Z>[^<]+<\/B>) (?:<N[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>[^<]+<\/B>) <T>[Aa]n<\/T> )<B><Z><N pl="n" gnt="n" gnd="m".><N pl="n" gnt="y" gnd="m".>(?:<V p="." t="foshuit".>)?<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/()<B><Z><N pl="n" gnt="n" gnd="m".><N pl="n" gnt="y" gnd="m".>(?:<V p="." t="foshuit".>)?<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z><N pl="y" gnt="n" gnd="m".><N pl="y" gnt="y" gnd="m".><\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z><N pl="y" gnt="n" gnd="f".><N pl="y" gnt="y" gnd="f".>(?:<A pl="n" gnt="y" gnd="f".>)?<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="f">$2<\/N>$3/g;
	s/(<T>na<\/T> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="y" gnd="f".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="f">$2<\/N>$3/g;
	s/(<D>[^<]*[A\x{c1}a\x{e1}]<\/D> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="n" gnd="f" h="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f" h="y">$2<\/N>$3/g;
	s/((?:<N[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>[^<]+<\/B>) <T>na<\/T> )<B><Z>(?:<[^>]+>)*<N pl="n" gnt="y" gnd="f" h="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="f" h="y">$2<\/N>$3/g;
	s/(<T>na<\/T> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="n" gnd="m" h="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m" h="y">$2<\/N>$3/g;
	s/(<T>na<\/T> )<B><Z>(?:<[^>]+>)*<N pl="y" gnt="n" gnd="f" h="y".>(?:<[^>]+>)*<\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="f" h="y">$2<\/N>$3/g;
	s/(<T>na<\/T> )<B><Z><N pl="n" gnt="n" gnd="m".><N pl="y" gnt="y" gnd="m".><A pl="n" gnt="n".><\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="y" gnd="m">$2<\/N>$3/g;
	s/((?:<[^\/N][^>]*>[^<]+<\/[^N]>|<B><Z>(?:<[^N][^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z><N pl="n" gnt="n" gnd="f".><N pl="n" gnt="y" gnd="f".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="n" gnd="f">$2<\/N>$3/g;
	s/()<B><Z><S.><C.><\/Z>([^<]+)<\/B>( (?:<[NP][^>]*>[^<]+<\/[NP]>|<B><Z>(?:<[NP][^>]*>)+<\/Z>[^<]+<\/B>))/$1<S>$2<\/S>$3/g;
	s/()<B><Z><S.><C.><\/Z>([^<]+)<\/B>( <T>na<\/T>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z><S.><C.><\/Z>([^<]+)<\/B>( (?:<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z><S.><C.><\/Z>([^<]+)<\/B>( (?:<[\/A-DF-Z][^>]*>)+seo<\/[A-DF-Z]>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z><S.><C.><\/Z>([^<]+)<\/B>( (?:<[\/A-DF-Z][^>]*>)+sin<\/[A-DF-Z]>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z><S.><C.><\/Z>([^<]+)<\/B>()/$1<C>$2<\/C>$3/g;
	s/()<B><Z><U.><C.><Q.><V cop="y".><\/Z>([^<]+)<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<U>$2<\/U>$3/g;
	s/()<B><Z><U.><C.><Q.><V cop="y".><\/Z>([^<]+)<\/B>()/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z><V p="n" t="caite".><V p="y" t="ord".><V p="y" t="gn\x{e1}th".><\/Z>((?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+)<\/B>()/$1<V p="y" t="gn\x{e1}th">$2<\/V>$3/g;
	s/()<B><Z><V p="y" t="ord".><V p="y" t="gn\x{e1}th".><\/Z>([^<]+)<\/B>()/$1<V p="y" t="gn\x{e1}th">$2<\/V>$3/g;
	s/()<B><Z><V p="y" t="ord".><V p="y" t="caite".><\/Z>((?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+)<\/B>()/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)*<V p="y" t="caite".>(?:<[^>]+>)*<\/Z>(D'[^<]+)<\/B>()/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/()<B><Z>((?:<[^>]+>)*<V p="y" t="ord".><V p="y" t="caite".>(?:<[^>]+>)*)<\/Z>((?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+)<\/B>()/"$1".strip_badpos($2,$3,'<V p="y" t="caite".>')."$4"/eg;
	s/()<B><Z><V p="y" t="ord".><V p="y" t="caite".><\/Z>([^<]+)<\/B>()/$1<V p="y" t="caite">$2<\/V>$3/g;
	s/()<B><Z><V p="n" t="caite".><V p="y" t="ord".><\/Z>([^<]+)<\/B>()/$1<V p="n" t="caite">$2<\/V>$3/g;
	s/()<B><Z><V p="y" t="ord".><V p="y" t="l\x{e1}ith".><\/Z>([^<]+)<\/B>()/$1<V p="y" t="l\x{e1}ith">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]r)<\/B>( (?:<P[^>]*>[Ss](?:[\x{e9}\x{ed}]|iad(?:san)?|ise|eisean)<\/P>|<B><Z>(?:<P[^>]*>)+<\/Z>[Ss](?:[\x{e9}\x{ed}]|iad(?:san)?|ise|eisean)<\/B>))/$1<V p="y" t="l\x{e1}ith">$2<\/V>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[^<]+<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>([Aa]r)<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<U>$2<\/U>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]r)<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<Q>$2<\/Q>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa]r)<\/B>()/$1<S>$2<\/S>$3/g;
	s/()<B><Z>((?:<[^>]+>)+)<\/Z>([^<]+)<\/B>( (?:<P[^>]*>[Ss](?:[\x{e9}\x{ed}]|iad(?:san)?|ise|eisean)<\/P>|<B><Z>(?:<P[^>]*>)+<\/Z>[Ss](?:[\x{e9}\x{ed}]|iad(?:san)?|ise|eisean)<\/B>))/"$1".strip_badpos($2,$3,'<[^V][^<]*.>')."$4"/eg;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Dd]e)<\/B>( (?:<[\/A-DF-Z][^>]*>)+a<\/[A-DF-Z]>)/$1<O>$2<\/O>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Dd]e)<\/B>( (?:<[CPSR][^>]*>[^<]+<\/[CPSR]>|<B><Z>(?:<[CPSR][^>]*>)+<\/Z>[^<]+<\/B>))/$1<O>$2<\/O>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Dd]e)<\/B>()/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(n?[Dd]h?earcadh)<\/B>()/$1<N pl="n" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(gur)<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<C>$2<\/C>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(gur)<\/B>()/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(\x{d3})<\/B>( (?:<[\/A-DF-Z][^>]*>)+[A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]>)/$1<Y>$2<\/Y>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(\x{d3})<\/B>( (?:<[\/A-DF-Z][^>]*>)+[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*WITHH<\/[A-DF-Z]>)/$1<Y>$2<\/Y>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(\x{d3})<\/B>( <Y>[^<]+<\/Y>)/$1<Y>$2<\/Y>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([\x{d3}\x{f3}])<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<C>$2<\/C>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([\x{d3}\x{f3}])<\/B>()/$1<S>$2<\/S>$3/g;
	s/((?:<[^\/N][^>]*>[^<]+<\/[^N]>|<B><Z>(?:<[^N][^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z><N pl="n" gnt="y" gnd="m".><N pl="y" gnt="n" gnd="m".><\/Z>([^<]+)<\/B>()/$1<N pl="y" gnt="n" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(N\x{ed})<\/B>( (?:<[\/A-DF-Z][^>]*>)+[A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]>)/$1<Y>$2<\/Y>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(N\x{ed})<\/B>( <Y>[^<]+<\/Y>)/$1<Y>$2<\/Y>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(N\x{ed})<\/B>()/$1<V cop="y">$2<\/V>$3/g;
	s/(<S>[^<]+<\/S> )<B><Z><P.><A pl="n" gnt="n".>(?:<A pl="n" gnt="y" gnd="m".>)?<\/Z>([^<]+)<\/B>()/$1<P>$2<\/P>$3/g;
	s/(<Q>[^<]+<\/Q> )<B><Z><P.><A pl="n" gnt="n".>(?:<A pl="n" gnt="y" gnd="m".>)?<\/Z>([^<]+)<\/B>()/$1<P>$2<\/P>$3/g;
	s/((?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z><P.><A pl="n" gnt="n".>(?:<A pl="n" gnt="y" gnd="m".>)?<\/Z>([^<]+)<\/B>()/$1<P>$2<\/P>$3/g;
	s/(<C>[^<]+<\/C> )<B><Z><P.><A pl="n" gnt="n".>(?:<A pl="n" gnt="y" gnd="m".>)?<\/Z>([^<]+)<\/B>()/$1<P>$2<\/P>$3/g;
	s/()<B><Z><P.><A pl="n" gnt="n".>(?:<A pl="n" gnt="y" gnd="m".>)?<\/Z>([^<]+)<\/B>()/$1<A pl="n" gnt="n">$2<\/A>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>( (?:<[\/A-DF-Z][^>]*>)+h[^<]+<\/[A-DF-Z]>)/$1<D>$2<\/D>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>( (?:<N[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/B>))/$1<D>$2<\/D>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>( (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*pl="y"[^>]*>)+<\/Z>[^<]+<\/B>))/$1<D>$2<\/D>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>( (?:<[\/A-DF-Z][^>]*>)+ch\x{f3}ir<\/[A-DF-Z]>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>( (?:<[\/A-DF-Z][^>]*>)+dh\x{ed}th<\/[A-DF-Z]>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>( (?:<[^\/V][^>]*>[^<]*(?:a[dm]h|i[nr]t|\x{e1}il|\x{fa})<\/[^V]>|<B><Z>(?:<[^V][^>]*>)+<\/Z>[^<]*(?:a[dm]h|i[nr]t|\x{e1}il|\x{fa})<\/B>))/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>( (?:<[\/A-DF-Z][^>]*>)+(?:bheith|cheannach|chur|dh\x{ed}ol|dhul|fhoghlaim|\x{ed}oc|iompar|oscailt|r\x{e1}|roinnt|scr\x{ed}obh|shol\x{e1}thar|theacht)<\/[A-DF-Z]>)/$1<S>$2<\/S>$3/g;
	s/(<C>[Nn]uair<\/C> )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>()/$1<G>$2<\/G>$3/g;
	s/(<C>[Ff]ad is<\/C> )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>()/$1<G>$2<\/G>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Aa]mhlaidh<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>()/$1<G>$2<\/G>$3/g;
	s/(<R>ar \x{e9}igean<\/R> )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>()/$1<G>$2<\/G>$3/g;
	s/(<Q>[Cc]ad [Cc]huige<\/Q> )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>()/$1<H>$2<\/H>$3/g;
	s/(<Q>[Cc][^<]+<\/Q> )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>()/$1<G>$2<\/G>$3/g;
	s/(<N pl="n" gnt="n" gnd="f">[Uu]air<\/N> )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>()/$1<G>$2<\/G>$3/g;
	s/(<N pl="n" gnt="n" gnd="f" h="y">h[Uu]air<\/N> )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>()/$1<G>$2<\/G>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Cc]\x{e1}<\/[A-DF-Z]> (?:<N[^>]*>[Ff]had<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>[Ff]had<\/B>) )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>()/$1<G>$2<\/G>$3/g;
	s/(<N pl="n" gnt="n" gnd="f">[Dd]h?\x{f3}igh<\/N> )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>()/$1<H>$2<\/H>$3/g;
	s/(<N pl="n" gnt="n" gnd="m">(?:[Ff]h?\x{e1}th|g[Cc]\x{e1}s)<\/N> )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>()/$1<H>$2<\/H>$3/g;
	s/(<N pl="n" gnt="n" gnd="f">(?:[\x{c1}\x{e1}]it|t[Ss]l\x{ed})<\/N> )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>()/$1<H>$2<\/H>$3/g;
	s/(<N pl="n" gnt="n" gnd="f" h="y">h[\x{c1}\x{e1}]it<\/N> )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>()/$1<H>$2<\/H>$3/g;
	s/((?:<N[^>]*pl="n"[^>]*>g?[Cc]h?aoi<\/N>|<B><Z>(?:<N[^>]*pl="n"[^>]*>)+<\/Z>g?[Cc]h?aoi<\/B>) )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>()/$1<H>$2<\/H>$3/g;
	s/(<A pl="n" gnt="n">[Gg]ach<\/A> )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>()/$1<H>$2<\/H>$3/g;
	s/(<S>[^<]+<\/S> )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<H>$2<\/H>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Aa]s<\/[A-DF-Z]> )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<H>$2<\/H>$3/g;
	s/((?:<[\/A-DF-Z][^>]*>)+[Cc]\x{e9}<\/[A-DF-Z]> (?:<O[^>]*>acu<\/O>|<B><Z>(?:<O[^>]*>)+<\/Z>acu<\/B>) )<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>()/$1<G>$2<\/G>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>( (?:<V[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/B>))/$1<H>$2<\/H>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>( (?:<V[^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/B>))/$1<G>$2<\/G>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>( (?:<V[^>]*>d'[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>d'[^<]+<\/B>))/$1<G>$2<\/G>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<U>$2<\/U>$3/g;
	s/((?:<[GHU][^>]*>[Aa]<\/[GHU]>|<B><Z>(?:<[GHU][^>]*>)+<\/Z>[Aa]<\/B>) )<B><Z>((?:<[^>]+>)+)<\/Z>([^<]+)<\/B>()/"$1".strip_badpos($2,$3,'<[^V][^>]*.>')."$4"/eg;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>( (?:<[\/A-DF-Z][^>]*>)+[^<]*(?:a[dm]h|i[nr]t|\x{e1}il|\x{fa})<\/[A-DF-Z]>)/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Aa])<\/B>()/$1<D>$2<\/D>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>(d\x{f3})<\/B>()/$1<O>$2<\/O>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Ll]eis)<\/B>()/$1<O>$2<\/O>$3/g;
	s/()<B><Z><S.><O.><\/Z>([^<]+)<\/B>( (?:<[RS][^>]*>[^<]+<\/[RS]>|<B><Z>(?:<[RS][^>]*>)+<\/Z>[^<]+<\/B>))/$1<O>$2<\/O>$3/g;
	s/()<B><Z><S.><O.><\/Z>([^<]+)<\/B>()/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Dd]ar)<\/B>( (?:<[DOST][^>]*>[^<]+<\/[DOST]>|<B><Z>(?:<[DOST][^>]*>)+<\/Z>[^<]+<\/B>))/$1<S>$2<\/S>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Dd]ar)<\/B>()/$1<V cop="y">$2<\/V>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Nn]\x{ed}or)<\/B>( (?:<V[^>]*>[^<]+<\/V>|<B><Z>(?:<V[^>]*>)+<\/Z>[^<]+<\/B>))/$1<U>$2<\/U>$3/g;
	s/()<B><Z>(?:<[^>]+>)+<\/Z>([Nn]\x{ed}or)<\/B>()/$1<V cop="y">$2<\/V>$3/g;
	s/(<V cop="y">[^<]+<\/V> )<B><Z><N pl="n" gnt="n" gnd="m".><V p="n" t="caite".><V p="y" t="ord".>(?:<V p="y" t="gn\x{e1}th".>)?<\/Z>((?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*)<\/B>()/$1<V p="n" t="caite">$2<\/V>$3/g;
	s/((?:<[^\/ACDNRSTY][^>]*>[^<]+<\/[^ACDNRSTY]>|<B><Z>(?:<[^ACDNRSTY][^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z>((?:<[^>]+>)*<N pl="." gnt="y"[^>]+>(?:<[^>]+>)*)<\/Z>([^<]+)<\/B>()/"$1".strip_badpos($2,$3,'<N pl="." gnt="y" gnd=".".>')."$4"/eg;
	s/((?:<[^\/ACNRSY][^>]*>[^<]+<\/[^ACNRSY]>|<B><Z>(?:<[^ACNRSY][^>]*>)+<\/Z>[^<]+<\/B>) <T>[^<]+<\/T> )<B><Z>((?:<[^>]+>)*<N pl="." gnt="y"[^>]+>(?:<[^>]+>)*)<\/Z>([^<]+)<\/B>()/"$1".strip_badpos($2,$3,'<N pl="." gnt="y" gnd=".".>')."$4"/eg;
	s/(<S>(?:[Dd][eo]n|[Ss]an?|[Ff]aoin|[\x{d3}\x{f3}]n)<\/S> )<B><Z>((?:<[^>]+>)*<N pl="." gnt="y"[^>]+>(?:<[^>]+>)*)<\/Z>([^<]+)<\/B>()/"$1".strip_badpos($2,$3,'<N pl="." gnt="y" gnd=".".>')."$4"/eg;
	s/(<S>(?:[Aa][grs]|[Cc]huig|[Dd][eo]|[Ff]aoi|[Gg]an|[Gg]o|[Ll]e|[\x{d3}\x{f3}]|[Ii]n?|[Rr]oimh|[Tt]har|[Tt]r\x{ed}d?|[Uu]m)<\/S> )<B><Z>((?:<[^>]+>)*<N pl="." gnt="y"[^>]+>(?:<[^>]+>)*)<\/Z>([^<]+)<\/B>()/"$1".strip_badpos($2,$3,'<N pl="." gnt="y" gnd=".".>')."$4"/eg;
	s/((?:<N[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*>)+<\/Z>[^<]+<\/B>) )<B><Z><N pl="n" gnt="y" gnd="m".><N pl="y" gnt="n" gnd="m".><\/Z>([^<]+)<\/B>()/$1<N pl="n" gnt="y" gnd="m">$2<\/N>$3/g;
	s/()<B><Z>((?:<[^>]+>)*<V p="y" t="caite".>(?:<[^>]+>)*)<\/Z>((?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*)<\/B>()/"$1".strip_badpos($2,$3,'<V p="y" t="caite".>')."$4"/eg;
	s/()<B><Z>((?:<[^>]+>)*<V p="n" t="caite".>(?:<[^>]+>)*)<\/Z>((?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*)<\/B>()/"$1".strip_badpos($2,$3,'<V p="n" t="caite".>')."$4"/eg;
	s/((?:<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]> )<B><Z>((?:<[^>]+>)*<V p="y" t="caite".>(?:<[^>]+>)*)<\/Z>([^<]+)<\/B>()/"$1".strip_badpos($2,$3,'<V p="y" t="caite".>')."$4"/eg;
	s/((?:<[\/A-DF-Z][^>]*>)+[Aa]n<\/[A-DF-Z]> )<B><Z>((?:<[^>]+>)*<V p="n" t="caite".>(?:<[^>]+>)*)<\/Z>([^<]+)<\/B>()/"$1".strip_badpos($2,$3,'<V p="n" t="caite".>')."$4"/eg;
	s/((?:<[^\/C][^>]*>(?:...|[^Nn]|.[^\x{e1}\x{c1}])[^<]*<\/[^C]>|<B><Z>(?:<[^C][^>]*>)+<\/Z>(?:...|[^Nn]|.[^\x{e1}\x{c1}])[^<]*<\/B>) )<B><Z>((?:<[^>]+>)*<V p="y" t="ord".>(?:<[^>]+>)*)<\/Z>([^<]+)<\/B>()/"$1".strip_badpos($2,$3,'<V p="y" t="ord".>')."$4"/eg;
	s/()<B><Z>((?:<[^>]+>)*<V[^>]+>(?:<[^>]+>)*)<\/Z>([^<]+)<\/B>( (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*gnt="y"[^>]*>)+<\/Z>[^<]+<\/B>))/"$1".strip_badpos($2,$3,'<V[^>]+.>')."$4"/eg;
	}
}

sub comhshuite
{
	for ($_[0]) {
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]s)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ch\x{e9}ile)<\/[A-DF-Z]>/<R>$1 $2 $3<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ch\x{e9}ile)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Cc]hloi?g)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(l\x{e1}n)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(thiarcais)<\/[A-DF-Z]>/<I>$1 $2<\/I>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]gus)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(araile)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(aghaidh)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ais)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(athl\x{e1}imh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(atr\x{e1}th)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ba[lo]l)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ballchrith)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(barr)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bior)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(b\x{ed}s)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bith)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bh\x{ed}thin)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bogadh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(b\x{f3}il\x{e9}agar)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bord)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(buile)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bun)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(cairde)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ceal)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(c\x{e9}alacan)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ceant)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ceathr\x{fa}in)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ch\x{fa}l)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(c\x{ed}os)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(cip\x{ed}n\x{ed})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(cl\x{e9})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(cois)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(comhaois)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(comhbhr\x{ed})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(comhch\x{e9}im)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(comhfhad)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(comhsc\x{f3}r)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(cosaint)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(cothrom)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(crith)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(crochadh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(cuairt)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(d\x{e1}ir)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dearglasadh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(deargmheisce)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dei[cl])<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(deighilt)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(deireadh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(deiseal)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(deora\x{ed}ocht)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(d\x{ed}birt)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(d\x{ed}ol)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(d\x{ed}ot\x{e1}il)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(di\x{fa}it\x{e9})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(d\x{f3}igh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(doimhneacht)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(domhan)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dt\x{fa}s)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dualgas)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(\x{e9}igean)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(fad)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Ff]\x{e1}il)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(f\x{e1}n)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(faonoscailt)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(farraige)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(feadh)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(f\x{e9}arach)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(feitheamh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(fiannas)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(fiar)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(fionra\x{ed})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(fiuchadh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa][gr])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(foluain)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(f\x{f3}namh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(forbh\x{e1}s)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(foscadh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(fost\x{fa})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(fruili\x{fa})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa][gr])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(fuaidreamh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(fud)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(garda)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gc\x{fa}l)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gor)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(leith)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(leithligh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(liobarna)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(lorg)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(maidin)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(maos)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(marthain)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(me\x{e1}n)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(meara\x{ed})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(mearbhall)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(mear\x{fa})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(meisce)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(mire)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(m\x{ed}threoir)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(muin)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(muir)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(nd\x{f3}igh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(neamhchead)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ndiaidh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(n\x{f3}s)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Pp]\x{e1}r)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(pinsean)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(promhadh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(saoire)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(seachr\x{e1}n)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(seirbh\x{ed}s)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(sileadh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(si\x{fa}l)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(sn\x{e1}mh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(sochar)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(sodar)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(son)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(strae)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(taispe\x{e1}int)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(talamh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(teachtadh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(teaghr\x{e1}n)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(teitheadh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(th\x{f3}ir)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(t\x{ed})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(tinneall)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(t\x{ed}r)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ti\x{fa}s)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(togradh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(tosach)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(triail)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(tuathal)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(uairibh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]rna)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(mh\x{e1}rach)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r\x{fa})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(am\x{e1}rach)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r\x{fa})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(anuraidh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r\x{fa})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ar\x{e9}ir)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r\x{fa})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(inn\x{e9})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Bb]ainte)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Aa]mach)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(m?[Bb]h?eo)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(beathach)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(m?[Bb]h?\x{f3}\x{ed}n)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(D\x{e9})<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="f">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(m?[Bb]h?r\x{ed}n)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(\x{f3}g)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(m?[Bb]h?uaileam)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(sciath)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(mh\x{e9}ad)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(a)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(mh\x{e9}ad)<\/[A-DF-Z]>/<R>$1 $2 $3<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(m?[Bb]h?aile)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(\x{c1}tha)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(Cliath)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="m">$1 $2 $3<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Cc][\x{e1}\x{e9}])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Mm]h\x{e9}ad)<\/[A-DF-Z]>/<Q>$1 $2<\/Q>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Cc]ad)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Cc]huige)<\/[A-DF-Z]>/<Q>$1 $2<\/Q>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e1})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(mh\x{e9}ad)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Cc]\x{e1}r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bith)<\/[A-DF-Z]>/<Q>$1 $2<\/Q>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Cc]\x{e9})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(is)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(moite)<\/[A-DF-Z]>/<R>$1 $2 $3<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Cc]eannann)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(c\x{e9}anna)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Cc]heannann)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ch\x{e9}anna)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Cc]iolar)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(chiot)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="f">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]h\x{e1})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ch\x{e9}ad)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]r\x{ed})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ch\x{e9}ad)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Cc]eithre)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ch\x{e9}ad)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Cc]\x{fa}ig)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ch\x{e9}ad)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ss]\x{e9})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ch\x{e9}ad)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(g?[Cc]h?odladh)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(grif\x{ed}n)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="m">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(g?[Cc]h?os)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ar)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bolg)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2 $3<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(g?[Cc]h?othrom)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(na)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Ff]\x{e9}inne)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="m">$1 $2 $3<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Cc]hun)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(cinn)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Cc]hun)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(tosaigh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]ar)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(nd\x{f3}igh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd][e\x{e1}])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bh\x{ed}thin)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e1})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(\x{e9}is)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]allach)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dubh)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]arb)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ainm)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bharr)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(chois)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ch\x{f3}ir)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(chuid)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dheasca)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dh\x{ed}obh\x{e1}il)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ghlanmheabhair)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(r\x{e9}ir)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(sciot\x{e1}n)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(thairbhe)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(thaisme)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(D\x{e9})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(Luain)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(D\x{e9})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(M\x{e1}irt)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(D\x{e9})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(C\x{e9}adaoin)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(D\x{e9})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(hAoine)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(D\x{e9})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(Sathairn)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(D\x{e9})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(Domhnaigh)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(h[Aa]on)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2 $3<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{f3})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]h\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2 $3<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Tt]r\x{ed})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2 $3<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Cc]eathair)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2 $3<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Cc]\x{fa}ig)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2 $3<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Ss]\x{e9})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2 $3<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Ss]eacht)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2 $3<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(h[Oo]cht)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2 $3<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Nn]aoi)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2 $3<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa]on)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Dd]\x{f3})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]h\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]r\x{ed})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Cc]eathair)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Cc]\x{fa}ig)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ss]\x{e9})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ss]eacht)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Oo]cht)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Nn]aoi)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{e9}ag)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(h[Aa]on)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]\x{f3})<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Tt]r\x{ed})<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Cc]eathair)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Cc]\x{fa}ig)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Ss]\x{e9})<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Ss]eacht)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(h[Oo]cht)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Aa])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Nn]aoi)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ff]ad)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(is)<\/[A-DF-Z]>/<C>$1 $2<\/C>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bhr\x{e1}id)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bhun)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(cheann)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(choinne)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(deara)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dh\x{e9}in)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dheoidh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dh\x{f3})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(l\x{e1}nseol)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(l\x{e1}thair)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(leith)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ff]aoi)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(seach)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(Fear)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(Manach)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ff]\x{ed}orchaoin)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(f\x{e1}ilte)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ff]ite)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Ff]uaite)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ff]ud)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Ff]ad)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ff]uta)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Ff]ata)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]ach)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(re)<\/[A-DF-Z]>/<A>$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]an)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Ff]hios)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]an)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(fi\x{fa})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(n?Gh?aoth)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(Dobhair)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]liog)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gleag)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(br\x{e1}ch)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ceann)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ch\x{e9}ile)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Dd]eimhin)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(deo)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(d\x{ed}reach)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dt\x{ed})<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(feillbhinn)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(fi\x{fa})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(f\x{f3}ill)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(fras)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(h\x{e1}irithe)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(h\x{e9}ag)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(h\x{e9}asca)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(hioml\x{e1}n)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(l\x{e9}ir)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(leith)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(leor)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(luath)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(minic)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(nuige)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(t\x{f3}in)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(poill)<\/[A-DF-Z]>/<R>$1 $2 $3<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Gg]o)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(treis)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(Hong)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(Cong)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bhf\x{e1}ch)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bhfad)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bhfeac)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bhfeidhm)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bhfeighil)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bhfianaise)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bhfochair)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bhfogas)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bhfoirm)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bhfolach)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dtaisce)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dteagmh\x{e1}il)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dteannta)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dt\x{f3}lamh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dtr\x{e1}tha)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dtreis)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dtreo)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dtuilleama\x{ed})<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gcaitheamh)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gceann)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gceartl\x{e1}r)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gc\x{e9}in)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gceist)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gcionn)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gcoinne)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gc\x{f3}ir)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gcoitinne)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gcomhair)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gcomhchlos)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gcomhthr\x{e1}th)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gc\x{f3}na\x{ed})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gcosamar)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gcr\x{ed}ch)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gcuideachta)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(l\x{e1}r)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(l\x{e1}thair)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(l\x{e9}ig)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(leith)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(mbliana)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(mbun)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(measc)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(nd\x{e1}ir\x{ed}re)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ndiaidh)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ngach)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ngan)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(fhios)<\/[A-DF-Z]>/<R>$1 $2 $3<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ngearr)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(rith)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(s\x{e1}inn)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]dir)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(cham\x{e1}in)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(aghaidh)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(aice)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(aicearracht)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ainneoin)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(airde)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(airicis)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(\x{e1}it)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ann)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(\x{e9}adan)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(\x{e9}ind\x{ed})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(\x{e9}ineacht)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(imeacht)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ionad)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]na)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(aice)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]na)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ch?olgsheasamh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]na)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(leith)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ii]na)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(steillbheatha)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(hInis)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(Me\x{e1}in)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="f" h="y">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(Inis)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(Me\x{e1}in)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="f">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(hInis)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(M\x{f3}r)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="f" h="y">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(Inis)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(M\x{f3}r)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="f">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ll]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Cc]h\x{e9}ile)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ll]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(cois)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ll]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(d\x{e9}ana\x{ed})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ll]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(deireanas)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ll]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(feice\x{e1}il)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ll]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(haghaidh)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ll]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(hais)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ll]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(linn)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ll]i\x{fa}tar)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(\x{e9}atar)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(Loch)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(Garman)<\/[A-DF-Z]>/<Y>$1 $2<\/Y>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ll]\x{fa}b)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Aa]r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Ll]\x{e1}r)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="f">$1 $2 $3<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ll]u\x{ed})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(gaidhte)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="m">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ll]uthairt)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(lathairt)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Mm]h?ac)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(siobh\x{e1}in)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="m">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(Mh?aigh)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(Eo)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Mm]ar)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dhea)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Mm]ar)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(sin)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(f\x{e9}in)<\/[A-DF-Z]>/<R>$1 $2 $3<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Mm]eacan)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ragaim)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="m">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Mm]h?\x{ed})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(Feabhra)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="f">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Mm]h?\x{f3}r)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Ll]e)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Rr]\x{e1})<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2 $3<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Mm]ugadh)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(magadh)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(na)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bhfud)<\/[A-DF-Z]>/<N pl="y" gnt="y" gnd="m">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(neachtar)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(acu)<\/[A-DF-Z]>/<P>$1 $2<\/P>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Nn]\x{ed})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ba)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Nn]\x{ed})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(hamh\x{e1}in)<\/[A-DF-Z]>/<U>$1 $2<\/U>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Nn]\x{ed})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(hamhlaidh)<\/[A-DF-Z]>/<U>$1 $2<\/U>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Nn]\x{ed})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(hansa)<\/[A-DF-Z]>/<U>$1 $2<\/U>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Nn]\x{ed}os)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(d\x{e9}ana\x{ed})<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Nn]\x{ed}os)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(fearr)<\/[A-DF-Z]>/<A>$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Nn]\x{ed}os)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(m\x{f3})<\/[A-DF-Z]>/<A>$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Nn]i\x{fa}dar)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ne\x{e1}dar)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([\x{d3}\x{f3}])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(chianaibh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([\x{d3}\x{f3}])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dheas)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([\x{d3}\x{f3}])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(thuaidh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([\x{d3}\x{f3}])<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(shin)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Oo]s)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(cionn)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Oo]s)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(coinne)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Oo]s)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(comhair)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Pp]linc)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(pleainc)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Rr]aiple)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(h\x{fa}ta)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Rr]ibe)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(r\x{f3}ib\x{e9}is)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="m">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Rr]ib\x{ed})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(r\x{f3}ib\x{e9}is)<\/[A-DF-Z]>/<N pl="y" gnt="n" gnd="m">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(Ros)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(Com\x{e1}in)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+(Ros)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(Muc)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Rr]uaille)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(buaille)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ss]a)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(treis)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ss]a)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(tsl\x{e1}nchruinne)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ss]an)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(\x{e1}ireamh)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ss]an)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(fhaopach)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ss]aochan)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(c\x{e9}ille)<\/[A-DF-Z]>/<N pl="n" gnt="n" gnd="m">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ss]aor)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Ii]n)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Aa]isce)<\/[A-DF-Z]>/<R>$1 $2 $3<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ss]cun)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(scan)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ss]eo)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(caite)<\/[A-DF-Z]>/<A pl="n" gnt="n">$1 $2<\/A>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ss]h?inn)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(F\x{e9}in)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ss]i\x{fa}n)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(sinc\x{ed}n)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ss]pior)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(spear)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ss]teig)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(meig)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Ss]\x{fa}m)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(s\x{e1}m)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]h?amhach)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(t\x{e1}isc)<\/[A-DF-Z]>/<N pl="n" gnt="n">$1 $2<\/N>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]ar)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(\x{e9}is)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(barr)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bord)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(br\x{e1}id)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(cailc)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ceal)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(ceann)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(cionn)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(cuimse)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(farraige)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(f\x{f3}ir)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(lear)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(maoil)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(me\x{e1}n)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(muir)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+([Ss]\x{e1}ile)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(tairseach)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(t\x{e9}arma)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(teorainn)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(t\x{ed}r)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]har)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(toinn)<\/[A-DF-Z]>/<R>$1 $2<\/R>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Tt]r\x{ed})<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(bh\x{ed}thin)<\/[A-DF-Z]>/<S>$1 $2<\/S>/g;
	s/(?:<[\/A-DF-Z][^>]*>)+([Uu]m)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(an)<\/[A-DF-Z]> (?:<[\/A-DF-Z][^>]*>)+(dtaca)<\/[A-DF-Z]>/<R>$1 $2 $3<\/R>/g;
	}
}

# analogue of "escape_punc" in bash version
sub giorr
{
	for ($_[0]) {
	s/^/ /;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-90-9-][0-9])([.?!])/$1$NOBD$2/g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-90-9-][0-9][0-9])([.?!])/$1$NOBD$2/g;
	s/(\...)([.?!])/$1$NOBD$2/g;
	s/\.(ie|uk)$NOBD([.?!])/.$1$2/g;
	s/(\..)([.?!])/$1$NOBD$2/g;
	s/(\.)([.?!])/$1$NOBD$2/g;
	s/([IVX][IVX])([.?!])/$1$NOBD$2/g;
	s/([^\\A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-][A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-])([.?!])/$1$NOBD$2/g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-][\x{e9}\x{ed}])$NOBD([.?!])/$1$2/g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Beo)!/$1$NOBD!/g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-][Yy]ahoo)!/$1$NOBD!/g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Aib)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Ath)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Beal)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]bl)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]B[nr])\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-][Cc]aib)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]c[cf])\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]C[dho])\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Cho)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]cit)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Dr)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Ea[gn])\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]etc)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Feabh)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Fig)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]F\x{f3}mh)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Fr)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]gCo)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]hor)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-][Ii]bid)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-][Ii]ml)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Inc)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]\x{cd}ocht)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Jr)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-][Ll][cg]h)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Ltd)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]L\x{fa}n)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]M\x{e1}r)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Meith)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]M[rs])\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Mrs)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-][Nn]o)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Noll)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]op)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]pp)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]rl)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Samh)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]sbh)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]S[crt])\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-][Ss][hpq])\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]srl)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]taesp)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]tAth)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]teil)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Teo)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]tr)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]tSr)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]tUas)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-]Uas)\./$1$NOBD./g;
	s/([^A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}0-9'-][Uu]imh)\./$1$NOBD./g;
	s/([?!][]"')}]*[ \t\n-]+[a-z\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])/$NOBD$1/g;
	s/^ //;
	}
}

sub rialacha
{
	for ($_[0]) {
	s/(<E[^>]*><[A-DF-Z][^>]*>ar<\/[A-DF-Z]> <[A-DF-Z][^>]*>ar<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><[A-DF-Z][^>]*>ciar\x{f3}g<\/[A-DF-Z]> <[A-DF-Z][^>]*>ciar\x{f3}g<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> <E[^>]*><[A-DF-Z][^>]*>deo<\/[A-DF-Z]> <[A-DF-Z][^>]*>deo<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><[A-DF-Z][^>]*>do<\/[A-DF-Z]> <[A-DF-Z][^>]*>do<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><[A-DF-Z][^>]*>\x{e9}<\/[A-DF-Z]> <[A-DF-Z][^>]*>\x{e9}<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><[A-DF-Z][^>]*>fada<\/[A-DF-Z]> <[A-DF-Z][^>]*>fada<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> <E[^>]*><[A-DF-Z][^>]*>leor<\/[A-DF-Z]> <[A-DF-Z][^>]*>leor<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><[A-DF-Z][^>]*>m\x{e9}<\/[A-DF-Z]> <[A-DF-Z][^>]*>m\x{e9}<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><[A-DF-Z][^>]*>milli\x{fa}n<\/[A-DF-Z]> <[A-DF-Z][^>]*>milli\x{fa}n<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> <E[^>]*><[A-DF-Z][^>]*>m\x{f3}r<\/[A-DF-Z]> <[A-DF-Z][^>]*>m\x{f3}r<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><[A-DF-Z][^>]*>sin<\/[A-DF-Z]> <[A-DF-Z][^>]*>sin<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	s/(?<![<>])(<X>[^<]+<\/X>)(?![<>])/<E msg="ANAITHNID">$1<\/E>/g;
	s/(?<![<>])(<F>h?[Aa]irithe<\/F>)(?![<>])/<E msg="IONADAI{\x{e1}irithe}">$1<\/E>/g;
	s/(?<![<>])(<F>[Aa]ithnigh<\/F>)(?![<>])/<E msg="IONADAI{aithin}">$1<\/E>/g;
	s/(?<![<>])(<F>[Aa]ta<\/F>)(?![<>])/<E msg="IONADAI{at\x{e1}}">$1<\/E>/g;
	s/(?<![<>])(<F>m?[Bb]h?aise<\/F>)(?![<>])/<E msg="IONADAI{boise}">$1<\/E>/g;
	s/(?<![<>])(<F>m?[Bb]h?as<\/F>)(?![<>])/<E msg="IONADAI{b\x{e1}s, bos}">$1<\/E>/g;
	s/(?<![<>])(<F>m?[Bb]h?asa<\/F>)(?![<>])/<E msg="IONADAI{bosa}">$1<\/E>/g;
	s/(?<![<>])(<C>[Gg]o<\/C> <F>[Bb]rach<\/F>)(?![<>])/<E msg="IONADAI{go br\x{e1}ch}">$1<\/E>/g;
	s/(?<![<>])(<F>[Bb]h\x{fa}r<\/F>)(?![<>])/<E msg="IONADAI{bhur}">$1<\/E>/g;
	s/(?<![<>])(<F>g?[Cc]h?arta<\/F>)(?![<>])/<E msg="IONADAI{c\x{e1}rta}">$1<\/E>/g;
	s/(?<![<>])(<F>[Cc]heanna<\/F>)(?![<>])/<E msg="IONADAI{cheana}">$1<\/E>/g;
	s/(?<![<>])(<F>g[Cc]eanna<\/F>)(?![<>])/<E msg="IONADAI{gc\x{e9}anna}">$1<\/E>/g;
	s/(?<![<>])(<F>g?[Cc]h?onach<\/F>)(?![<>])/<E msg="IONADAI{confadh}">$1<\/E>/g;
	s/(?<![<>])(<F>[Cc]huile<\/F>)(?![<>])/<E msg="IONADAI{gach uile}">$1<\/E>/g;
	s/(?<![<>])(<F>[Cc]h?l\x{e1}racha<\/F>)(?![<>])/<E msg="IONADAI{cl\x{e1}ir}">$1<\/E>/g;
	s/(?<![<>])(<F>[Cc]l\x{e1}ra\x{ed}<\/F>)(?![<>])/<E msg="IONADAI{cl\x{e1}ir}">$1<\/E>/g;
	if (s/(?<![<>])(<F>[Dd]h?\x{e1}lta<\/F>)(?![<>])/<E msg="IONADAI{d\x{e1}la}">$1<\/E>/g) {
	s/(<E[^>]*><F>[Dd]\x{e1}lta<\/F><\/E> <R>le ch\x{e9}ile<\/R>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<F>n?[Dd]h?eire<\/F>)(?![<>])/<E msg="IONADAI{deireadh}">$1<\/E>/g;
	s/(?<![<>])(<F>[Dd]\x{ed}ofa<\/F>)(?![<>])/<E msg="IONADAI{d\x{ed}obh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> <F>n[Dd]oimhne<\/F>)(?![<>])/<E msg="IONADAI{i ndoimhneacht}">$1<\/E>/g;
	s/(?<![<>])(<F>n?[Dd]h?rud<\/F>)(?![<>])/<E msg="IONADAI{druidim}">$1<\/E>/g;
	s/(?<![<>])(<F>[Ff]h?in\x{ed}<\/F>)(?![<>])/<E msg="IONADAI{finte}">$1<\/E>/g;
	s/(?<![<>])(<F>[Ff]h?irinne<\/F>)(?![<>])/<E msg="IONADAI{f\x{ed}rinne}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <F>[Ff]his<\/F>)(?![<>])/<E msg="IONADAI{ris}">$1<\/E>/g;
	s/(?<![<>])(<F>[Ff]os<\/F>)(?![<>])/<E msg="IONADAI{f\x{f3}s}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> <F>bh[Ff]os<\/F>)(?![<>])/<E msg="CAIGHDEAN{abhus}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <F>[Ff]uaid<\/F>)(?![<>])/<E msg="IONADAI{ar fud}">$1<\/E>/g;
	s/(?<![<>])(<F>n?[Gg]h?oire<\/F>)(?![<>])/<E msg="IONADAI{gaire}">$1<\/E>/g;
	s/(?<![<>])(<F>n?[Gg]h?reas<\/F>)(?![<>])/<E msg="IONADAI{dreas}">$1<\/E>/g;
	if (s/(?<![<>])(<F>[Ii]nne<\/F>)(?![<>])/<E msg="IONADAI{inn\x{e9}}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ii]n<\/S> <F>[Ii]nne<\/F><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<F>[Ll]\x{e9}ithe<\/F>)(?![<>])/<E msg="IONADAI{l\x{e9}i}">$1<\/E>/g;
	s/(?<![<>])(<F>leitir<\/F>)(?![<>])/<E msg="IONADAI{litir}">$1<\/E>/g;
	s/(?<![<>])(<F>[Ll]eitreacha?<\/F>)(?![<>])/<E msg="IONADAI{litreach, litreacha}">$1<\/E>/g;
	s/(?<![<>])(<F>[Ll]iost<\/F>)(?![<>])/<E msg="IONADAI{liosta}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <F>[Mm]aothas<\/F>)(?![<>])/<E msg="IONADAI{ar maos}">$1<\/E>/g;
	s/(?<![<>])(<F>[Mm]h?uscail<\/F>)(?![<>])/<E msg="IONADAI{m\x{fa}scail}">$1<\/E>/g;
	s/(?<![<>])(<F>[\x{d3}\x{f3}]m<\/F>)(?![<>])/<E msg="IONADAI{\x{f3} mo}">$1<\/E>/g;
	if (s/(?<![<>])(<F>[Rr]ata\x{ed}?<\/F>)(?![<>])/<E msg="IONADAI{r\x{e1}ta, rachta}">$1<\/E>/g) {
	s/(<Y>pro<\/Y> <E[^>]*><F>rata<\/F><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<F>[Rr]uadh<\/F>)(?![<>])/<E msg="IONADAI{rua}">$1<\/E>/g;
	s/(?<![<>])(<F>[Ss]h?ol\x{e1}thraigh<\/F>)(?![<>])/<E msg="IONADAI{sol\x{e1}thair}">$1<\/E>/g;
	s/(?<![<>])(<F>[Tt]hairgeadh<\/F>)(?![<>])/<E msg="IONADAI{th\x{e1}irgeadh}">$1<\/E>/g;
	s/(?<![<>])(<F>[Tt]h?arrach<\/F>)(?![<>])/<E msg="IONADAI{tarraingt}">$1<\/E>/g;
	s/(?<![<>])(<F>d?[Tt]h?oiseach<\/F>)(?![<>])/<E msg="IONADAI{tosach}">$1<\/E>/g;
	s/(?<![<>])(<F>[Tt]h?oisigh<\/F>)(?![<>])/<E msg="IONADAI{tosaigh}">$1<\/E>/g;
	s/(?<![<>])(<F>[^<]+<\/F>)(?![<>])/<E msg="NEAMHCHOIT">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>n?[Dd]h?eara<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{faoi deara}">$1<\/E>/g;
	if (s/(?<![<>])((?:<V[^>]*t="foshuit"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="NOSUBJ">$1<\/E>/g) {
	s/(<C>(?:[Dd]\x{e1}|[Gg]o|[Ss]ula|[Mm]ura)<\/C> <E[^>]*>(?:<V[^>]*t="foshuit"[^>]*>[^<]+<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<U>[Nn]\x{e1}r<\/U> <E[^>]*>(?:<V[^>]*t="foshuit"[^>]*>[^<]+<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[^< ]+ [^<]+<\/S> <T>[^<]+<\/T> (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="GENITIVE">$1<\/E>/g) {
	s/(<S>[Aa]g?<\/S> (?:<N[^>]*>[^<]+<\/N>) <E[^>]*><S>[^< ]+ [^<]+<\/S> <T>[^<]+<\/T> (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Gg]o dt\x{ed}<\/S> <T>[^<]+<\/T> (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>(?:[Cc]ois|[Dd]\x{e1}la|[Ff]earacht|[Tt]impeall|[Tt]rasna)<\/S> <T>[^<]+<\/T> (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="GENITIVE">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">(?:[^<][^<]*[^m]|[0-9]+)\x{fa}<\/A> (?:<N[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Dd]ara<\/A> (?:<N[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	if (s/(?<![<>])((?:<V[^>]*t="ord"[^>]*>h[^<]+<\/V>))(?![<>])/<E msg="NIAITCH">$1<\/E>/g) {
	s/(<[A-DF-Z][^>]*>[Nn]\x{e1}<\/[A-DF-Z]> <E[^>]*>(?:<V[^>]*t="ord"[^>]*>h[^<]+<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<N pl="n" gnt="n" gnd="m">t(?:[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/N>)(?![<>])/<E msg="NITEE">$1<\/E>/g) {
	s/(<T>[Aa]n<\/T> <E[^>]*><N pl="n" gnt="n" gnd="m">t(?:[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/N><\/E>)/strip_errors($1);/eg;
	s/(<Q>[Cc]\x{e9}n<\/Q> <E[^>]*><N pl="n" gnt="n" gnd="m">t(?:[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/N><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<N pl="n" gnt="n" gnd="f">t[sS][^<]+<\/N>)(?![<>])/<E msg="NITEE">$1<\/E>/g) {
	s/(<T>[Aa][Nn]<\/T> <E[^>]*><N pl="n" gnt="n" gnd="f">t[sS][^<]+<\/N><\/E>)/strip_errors($1);/eg;
	s/(<S>(?:[Dd][eo]n|[Ss]an?|[Ff]aoin|[\x{d3}\x{f3}]n)<\/S> <E[^>]*><N pl="n" gnt="n" gnd="f">t[sS][^<]+<\/N><\/E>)/strip_errors($1);/eg;
	s/(<Q>[Cc]\x{e9}n<\/Q> <E[^>]*><N pl="n" gnt="n" gnd="f">t[sS][^<]+<\/N><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<N pl="n" gnt="y" gnd="m">t[sS][^<]+<\/N>)(?![<>])/<E msg="NITEE">$1<\/E>/g) {
	s/(<T>[Aa]n<\/T> <E[^>]*><N pl="n" gnt="y" gnd="m">t[sS][^<]+<\/N><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n" gnd="f">fr\x{ed}d<\/N>)(?![<>])/<E msg="CAIGHDEAN{tr\x{ed}, tr\x{ed}d}">$1<\/E>/g;
	if (s/(?<![<>])((?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+<\/N>) <A pl="n" gnt="n">(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/A>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+<\/N>) <A pl="n" gnt="n">[^< ]+ [^<]+<\/A><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+<\/N>) <A pl="n" gnt="n">(?:bainte|c\x{e9}ad|cib\x{e9}|curtha|deich|dulta|gach|seacht|seo|sin|tugtha)<\/A><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><N pl="n" gnt="n" gnd="f">[Bb]heith<\/N> <A pl="n" gnt="n">(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Aa]g<\/S> <N pl="n" gnt="n" gnd="f">[Ff]\x{e1}il<\/N> <N pl="n" gnt="y" gnd="m">b\x{e1}is<\/N>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]g<\/S> <N pl="n" gnt="n" gnd="f">[Gg]abh\x{e1}il<\/N> <N pl="n" gnt="y" gnd="m">(?:foinn|ceoil)<\/N>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])((?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+<\/N>) (?:<N[^>]*gnt="y"[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+<\/N>) <N pl="n" gnt="y" gnd="m">D\x{e9}<\/N><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+<\/N>) <N pl="n" gnt="y" gnd="m">[^<]+<\/N><\/E> <A pl="n" gnt="y" gnd="m">[^<]+<\/A>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+<\/N>) <N pl="n" gnt="y" gnd="f">[^<]+<\/N><\/E> <A pl="n" gnt="y" gnd="f">[^<]+<\/A>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+<\/N>) <N pl="n" gnt="y" gnd="m">(?:[^<]+(?:[\x{f3}\x{fa}]ra|eora|\x{e9}ara|a\x{ed})|cail\x{ed}n|duine|fir|p\x{e1}iste)<\/N><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+<\/N>) <N pl="n" gnt="y" gnd="f">(?:baintr\x{ed}|clainne|mn\x{e1})<\/N><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+<\/N>) <N pl="y" gnt="y" gnd="f">ban<\/N><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+[DdLlNnSsTt]<\/N>) (?:<N[^>]*gnt="y"[^>]*>[DdSsTt][^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>(?:[Aa]ilp|m?[Bb]h?ailc|(?:an-|g)?[Cc]h?uid|m?[Bb]h?arra\x{ed}ocht|m?[Bb]h?reis|n?[Dd]h?\x{ed}th|n?[Dd]h?\x{f3}thain|h?[\x{c9}\x{e9}]agmais|h?[Ee]aspa|h?[Ii]omarca|[Ll]eath|[Rr]oinnt)<\/N>) (?:<N[^>]*gnt="y"[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>bheith<\/N>) (?:<N[^>]*gnt="y"[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><N pl="n" gnt="n" gnd="f">n?[Dd]h?\x{e9}<\/N> <N pl="n" gnt="y" gnd="m">deiridh<\/N><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><N pl="n" gnt="n" gnd="f">n?[Gg]h?loine<\/N> (?:<N[^>]*gnt="y"[^>]*>[Ff][^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><N pl="n" gnt="n" gnd="f">(?:[Ff]h?oireann|[Ff]h?oinse)<\/N> (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><N pl="n" gnt="n" gnd="f">[Mm]h?eitheal<\/N> <N pl="n" gnt="y" gnd="f">[Ff]orbartha<\/N><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>(?:[^<]+(?:[ao]cht|\x{ed}l)|h?[Aa]cmhainn|h?[Aa]irde|(?:bh)?[Ff]h?(?:airsinge|earg|inne)|n?[Gg]h?\x{e9}arch\x{e9}im|h?[\x{cd}\x{ed}]de|[Ll]aige|[Mm]h?aise|h?[Oo]iread|h?[\x{d3}\x{f3}]ige|t?[Ss]c\x{e9}im|t?[Ss]h?aoirse)<\/N>) (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>(?:[^<]+i[lnr]t|[^<]+\x{e1}il|breith|foghlaim|iarraidh|obair|seilg)<\/N>) (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+<\/N>) <N pl="n" gnt="y" gnd="m">fichead<\/N><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+<\/N>) <N pl="n" gnt="y" gnd="m">[Tt]\x{ed}<\/N><\/E>)/strip_errors($1);/eg;
	s/(<S>[Aa]g<\/S> <E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>(?:[^<]+i[lnr]t|[^<]+\x{e1}il|breith|foghlaim|iarraidh|obair|seilg)<\/N>) (?:<N[^>]*gnt="y"[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+[DdLlNnSsTt]<\/N>) (?:<N[^>]*gnt="y"[^>]*>[DdSsTt][Hh][^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>[^<]+<\/N>) (?:<N[^>]*gnt="y"[^>]*>[A-Z\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])((?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>(?:[Aa]ilp|m?[Bb]h?ailc|(?:an-|g)?[Cc]h?uid|m?[Bb]h?arra\x{ed}ocht|m?[Bb]h?reis|n?[Dd]h?\x{ed}th|n?[Dd]h?\x{f3}thain|h?[\x{c9}\x{e9}]agmais|h?[Ee]aspa|h?[Ii]omarca|[Ll]eath|[Rr]oinnt)<\/N>) (?:<N[^>]*gnt="y"[^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>n?[Gg]h?loine<\/N>) (?:<N[^>]*gnt="y"[^>]*>[Ff][Hh][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Aa]g<\/S> (?:<N[^>]*pl="n" gnt="n" gnd="f"[^>]*>(?:[^<]+i[lnr]t|[^<]+\x{e1}il|breith|foghlaim|iarraidh|obair|seilg)<\/N>) (?:<N[^>]*gnt="y"[^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><S>[Aa]g<\/S> <N pl="n" gnt="n" gnd="f">[Ff]\x{e1}il<\/N> <N pl="n" gnt="y" gnd="m">bh\x{e1}is<\/N><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Aa]g<\/S> <N pl="n" gnt="n" gnd="f">[Gg]abh\x{e1}il<\/N> <N pl="n" gnt="y" gnd="m">(?:fhoinn|cheoil)<\/N><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<N pl="n" gnt="n" gnd="m">(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N> <A pl="n" gnt="n">(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/A>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>[^<]+<\/N>) <A pl="n" gnt="n">(?:[Dd]h\x{e1}|[Tt]hoir|[Tt]huasluaite)<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>(?:[^BbCcDdFfGgMmPpTt]|[Ss][^lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]*<\/N>) <A pl="n" gnt="n">(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/A>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*>(?:<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>[^<]+<\/N>) <A pl="n" gnt="n">(?:[Dd]h\x{e1}|[Tt]hoir|[Tt]huasluaite)<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<N[^>]*pl="y"[^>]*>[^<]*[e\x{e9}i\x{ed}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}<]+<\/N>) <A pl="y" gnt="n">(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/A>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*>(?:<N[^>]*pl="y"[^>]*>[^<]*[e\x{e9}i\x{ed}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}<]+<\/N>) <A pl="y" gnt="n">(?:bainte|cib\x{e9}|curtha|dulta|tugtha)<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<N[^>]*pl="y"[^>]*>[^<]*[e\x{e9}i\x{ed}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}<]+<\/N>) (?:<N[^>]*gnt="y"[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*>(?:<N[^>]*pl="y"[^>]*>[^<]*[e\x{e9}i\x{ed}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}<]+<\/N>) <N pl="n" gnt="y" gnd="m">D\x{e9}<\/N><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<N[^>]*pl="y"[^>]*>[^<]+[DdLlNnSsTt]<\/N>) (?:<N[^>]*gnt="y"[^>]*>[DdSsTt][^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])((?:<N[^>]*pl="y"[^>]*>[^<]+[DdLlNnSsTt]<\/N>) (?:<N[^>]*gnt="y"[^>]*>[DdSsTt][Hh][^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Mm]h\x{e1}rach<\/N>)(?![<>])/<E msg="INPHRASE{arna mh\x{e1}rach}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Aa]<\/[A-DF-Z]> (?:<V[^>]*>[Tt]\x{e1}(?:i[dm]|imid|thar)?<\/V>))(?![<>])/<E msg="BACHOIR{at\x{e1}}">$1<\/E>/g;
	if (s/(?<![<>])(<[A-DF-Z][^>]*>[Aa]<\/[A-DF-Z]> <A pl="n" gnt="n">(?:[Aa]on|[Oo]cht)<\/A>)(?![<>])/<E msg="PREFIXH">$1<\/E>/g) {
	s/(<E[^>]*><[A-DF-Z][^>]*>[Aa]<\/[A-DF-Z]> <A pl="n" gnt="n">(?:[Aa]on|[Oo]cht)<\/A><\/E> (?:<N[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>a<\/S> (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<U>[Aa]<\/U> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>[BbCcDdFfGgPpTt][^hcCpPtT'][^<]*<\/V>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g) {
	s/(<E[^>]*><U>[Aa]<\/U> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>[Dd](?:eir|\x{e9}ar)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><U>[Aa]<\/U> (?:<V[^>]*t="caite"[^>]*>(?:(?:d\x{fa}i?r|rai?bh|fuair|fhac|dheach|dhearna)[^<]*|fuarthas)<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<H>[Aa]<\/H> (?:<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{ar}">$1<\/E>/g) {
	s/(<E[^>]*><H>[Aa]<\/H> (?:<V[^>]*t="caite"[^>]*>(?:nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<H>[Aa]<\/H> (?:<V[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	if (s/(?<![<>])(<G>[Aa]<\/G> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><G>[Aa]<\/G> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>[Dd](?:eir|\x{e9}ar)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><G>[Aa]<\/G> (?:<V[^>]*t="caite"[^>]*>(?:(?:d\x{fa}i?r|rai?bh|fuair|fhac|dheach|dhearna)[^<]*|fuarthas)<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<V cop="y">[Aa]b<\/V> <[A-DF-Z][^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Aa]ch<\/S> (?:<[AN][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[AN]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><S>[Aa]ch<\/S> <N pl="n" gnt="n" gnd="f">bheith<\/N><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Aa]ch<\/S> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Aa]ch<\/S> <T>[Aa]n<\/T> <N pl="n" gnt="n" gnd="m">[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]ch<\/S> <T>[Aa]n<\/T> <A pl="n" gnt="n">(?:[Aa]on\x{fa}?|[Oo]cht(?:[\x{f3}\x{fa}]|\x{f3}d\x{fa})?)<\/A>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]ch<\/S> <T>an<\/T> <N pl="n" gnt="n" gnd="f">(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa][grs]<\/S> <T>an<\/T> (?:<N[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa][grs]<\/S> <T>an<\/T> <N pl="n" gnt="n" gnd="m">t(?:[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/N>)(?![<>])/<E msg="NITEE">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Aa][gs]<\/S> (?:<[^\/Y][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[^Y]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><S>[Aa]s<\/S> <[A-DF-Z][^>]*>(?:bheith|th\x{fa})<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Aa][gs]<\/S> <[A-DF-Z][^>]*>(?:bhur|dh\x{e1}|thart)<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Aa]g<\/S> (?:<P[^>]*>[Mm]\x{e9}<\/P>))(?![<>])/<E msg="BACHOIR{agam}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]g<\/S> (?:<P[^>]*>[Tt]h?\x{fa}<\/P>))(?![<>])/<E msg="BACHOIR{agat}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]g<\/S> (?:<P[^>]*>[\x{c9}\x{e9}]<\/P>))(?![<>])/<E msg="BACHOIR{aige}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]g<\/S> (?:<P[^>]*>[\x{cd}\x{ed}]<\/P>))(?![<>])/<E msg="BACHOIR{aici}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]g<\/S> (?:<P[^>]*>(?:[Mm]uid|[Ss]inn)<\/P>))(?![<>])/<E msg="BACHOIR{againn}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]g<\/S> (?:<P[^>]*>[Ss]ibh<\/P>))(?![<>])/<E msg="BACHOIR{agaibh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]g<\/S> (?:<P[^>]*>[Ii]ad<\/P>))(?![<>])/<E msg="BACHOIR{acu}">$1<\/E>/g;
	s/(?<![<>])(<S>(?:[Dd][eo]n|[Ss]an?|[Ff]aoin|[\x{d3}\x{f3}]n)<\/S> <A pl="n" gnt="n">[Aa]it<\/A>)(?![<>])/<E msg="IONADAI{\x{e1}it}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]n<\/S> <A pl="n" gnt="n">[Aa]it<\/A>)(?![<>])/<E msg="IONADAI{in \x{e1}it}">$1<\/E>/g;
	s/(?<![<>])(<T>[Aa]n<\/T> <A pl="n" gnt="n">[Aa]it<\/A>)(?![<>])/<E msg="IONADAI{an \x{e1}it}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]e<\/S> <A pl="n" gnt="n" h="y">h[Aa]it<\/A>)(?![<>])/<E msg="IONADAI{le h\x{e1}it}">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Aa]mhail<\/S> (?:<[^\/Y][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[^Y]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><S>[Aa]mhail<\/S> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Aa]mhail<\/S> <T>[Aa]n<\/T> <N pl="n" gnt="n" gnd="m">[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]mhail<\/S> <T>[Aa]n<\/T> <A pl="n" gnt="n">(?:[Aa]on\x{fa}?|[Oo]cht(?:[\x{f3}\x{fa}]|\x{f3}d\x{fa})?)<\/A>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]mhail<\/S> <T>an<\/T> <N pl="n" gnt="n" gnd="f">(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<Q>[Aa]n<\/Q> (?:<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{ar}">$1<\/E>/g) {
	s/(<E[^>]*><Q>[Aa]n<\/Q> (?:<V[^>]*t="caite"[^>]*>(?:nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<Q>[Aa]n<\/Q> (?:<V[^>]*>(?:[cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]+<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	if (s/(?<![<>])(<T>[Aa]n<\/T> <N pl="n" gnt="n" gnd="f">(?:[BbCcFfGgMmPp][^Hh']|bh[fF])[^<]*<\/N>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g) {
	s/(<S>[^<]+<\/S> <E[^>]*><T>[Aa]n<\/T> <N pl="n" gnt="n" gnd="f">(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N><\/E>)/strip_errors($1);/eg;
	s/(<S>[^<]+<\/S> <E[^>]*><T>[Aa]n<\/T> <N pl="n" gnt="n" gnd="f">[Mm][^<]+<\/N><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<T>[Aa]n<\/T> <N pl="n" gnt="n" gnd="m">[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g) {
	s/(<S>[^<]+<\/S> <E[^>]*><T>[Aa]n<\/T> <N pl="n" gnt="n" gnd="m">[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<T>[Aa]n<\/T> <A pl="n" gnt="n">(?:[Aa]on\x{fa}?|[Oo]cht(?:[\x{f3}\x{fa}]|\x{f3}d\x{fa})?)<\/A> (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="PREFIXT">$1<\/E>/g) {
	s/(<S>[^<]+<\/S> <E[^>]*><T>[Aa]n<\/T> <A pl="n" gnt="n">(?:[Aa]on\x{fa}?|[Oo]cht(?:[\x{f3}\x{fa}]|\x{f3}d\x{fa})?)<\/A> (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><T>[Aa]n<\/T> <A pl="n" gnt="n">(?:[Aa]on\x{fa}?|[Oo]cht(?:[\x{f3}\x{fa}]|\x{f3}d\x{fa})?)<\/A> (?:<N[^>]*pl="n" gnt="n"[^>]*>haois<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<T>[Aa]n<\/T> <N pl="n" gnt="y" gnd="m">(?:[BbCcFfGgMmPp][^Hh']|bh[fF])[^<]*<\/N>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><T>[Aa]n<\/T> <N pl="n" gnt="y" gnd="m">[Mm]\x{e9}id<\/N><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<T>[Aa]n<\/T> <N pl="n" gnt="n" gnd="f">[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}h][^<]+<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<T>[Aa]n<\/T> <N pl="n" gnt="y" gnd="m">[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}h][^<]+<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<T>[Aa]n<\/T> (?:<N[^>]*pl="n" gnt="y" gnd="f"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="BACHOIR{na}">$1<\/E>/g;
	s/(?<![<>])(<T>[Aa]n<\/T> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="BACHOIR{na}">$1<\/E>/g;
	if (s/(?<![<>])(<T>[Aa]n<\/T> <A pl="n" gnt="n">(?:tr\x{ed}|ceithre|c\x{fa}ig|s\x{e9}|seacht|ocht|naoi|deich)<\/A>)(?![<>])/<E msg="BACHOIR{na}">$1<\/E>/g) {
	s/(<E[^>]*><T>[Aa]n<\/T> <A pl="n" gnt="n">[^<]+<\/A><\/E> <[A-DF-Z][^>]*>(?:g?ch?\x{e9}ad|mh?\x{ed}le|mh?illi\x{fa}n)<\/[A-DF-Z]>)/strip_errors($1);/eg;
	s/(<E[^>]*><T>[Aa]n<\/T> <A pl="n" gnt="n">[^<]+<\/A><\/E> <[A-DF-Z][^>]*>a<\/[A-DF-Z]> <[A-DF-Z][^>]*>chlog<\/[A-DF-Z]>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<T>[Aa]n<\/T> (?:<N[^>]*>[Dd]h\x{e1}r\x{e9}ag<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>(?:[Dd][eo]n|[Ss]an?|[Ff]aoin|[\x{d3}\x{f3}]n)<\/S> (?:<N[^>]*>[Dd]h\x{e1}r\x{e9}ag<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<T>[Aa]n<\/T> (?:<N[^>]*>(?:n[Dd]|d[Tt]|[DdSsTt][Hh])[^<]+<\/N>))(?![<>])/<E msg="NICLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<T>[^<]+<\/T> (?:<N[^>]*gnt="n"[^>]*>[^<]+<\/N>) <T>[^<]+<\/T> (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="ONEART">$1<\/E>/g;
	s/(?<![<>])(<T>[^<]+<\/T> (?:<N[^>]*gnt="n"[^>]*>[^<]+<\/N>) <A pl="n" gnt="n">gach<\/A> (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="ONEART">$1<\/E>/g;
	if (s/(?<![<>])(<V cop="y">[Aa]n<\/V> (?:<[AN][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[AN]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><V cop="y">[Aa]n<\/V> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<A pl="n" gnt="n">[Aa]on<\/A> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Aa]on<\/A> (?:<N[^>]*>[Dd]h\x{e1}r\x{e9}ag<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>h?[Aa]on<\/[A-DF-Z]> (?:<N[^>]*>(?:[BbCcFfGgMmPp][^Hh']|bh[fF])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>h?[Aa]on<\/[A-DF-Z]> (?:<N[^>]*>[DdSsTt][Hh][^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<[A-DF-Z][^>]*>[Aa]on<\/[A-DF-Z]> (?:<[^\/N][^>]*>[^<]+<\/[^N]>))(?![<>])/<E msg="CUPLA">$1<\/E>/g) {
	s/(<E[^>]*><[A-DF-Z][^>]*>[Aa]on<\/[A-DF-Z]> (?:<A[^>]*>[Mm]h\x{ed}le<\/A>)<\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>[Mm]ar<\/[A-DF-Z]> <E[^>]*><[A-DF-Z][^>]*>[Aa]on<\/[A-DF-Z]> (?:<[DOS][^>]*>[Ll][^<]+<\/[DOS]>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><[A-DF-Z][^>]*>[Aa]on<\/[A-DF-Z]> <[A-DF-Z][^>]*>d\x{e1}<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])((?:<[QU][^>]*>[Aa]r<\/[QU]>) (?:<V[^>]*t="caite"[^>]*>(?:(?:d\x{fa}i?r|rai?bh|fuair|fhac|dheach|dhearna)[^<]*|fuarthas)<\/V>))(?![<>])/<E msg="BACHOIR{a, an}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> (?:<N[^>]*>d?t\x{fa}i?s<\/N>))(?![<>])/<E msg="IONADAI{ar dt\x{fa}s}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">c\x{fa}l<\/N>)(?![<>])/<E msg="IONADAI{ar gc\x{fa}l}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">s\x{fa}il<\/N>)(?![<>])/<E msg="IONADAI{ar si\x{fa}l}">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Aa]r<\/S> (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="WEAKSEIMHIU{ar}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>)<\/E> (?:<P[^>]*>[^<]+<\/P>))/strip_errors($1);/eg;
	}
	s/(?<![<>])(<Q>[Aa]r<\/Q> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Aa]r<\/V> <[A-DF-Z][^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{arb, arbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Aa]r<\/V> <[A-DF-Z][^>]*>[Ff][Hh][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{arbh}">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Aa]r<\/S> (?:<P[^>]*>[Mm]\x{e9}<\/P>))(?![<>])/<E msg="BACHOIR{orm}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Aa]r<\/S> (?:<P[^>]*>[Tt]h?\x{fa}<\/P>))(?![<>])/<E msg="BACHOIR{ort}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Aa]r<\/S> (?:<P[^>]*>[\x{c9}\x{e9}]<\/P>))(?![<>])/<E msg="BACHOIR{air}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Aa]r<\/S> (?:<P[^>]*>[\x{cd}\x{ed}]<\/P>))(?![<>])/<E msg="BACHOIR{uirthi}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Aa]r<\/S> (?:<P[^>]*>(?:[Mm]uid|[Ss]inn)<\/P>))(?![<>])/<E msg="BACHOIR{orainn}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Aa]r<\/S> (?:<P[^>]*>[Ss]ibh<\/P>))(?![<>])/<E msg="BACHOIR{oraibh}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Aa]r<\/S> (?:<P[^>]*>[Ii]ad<\/P>))(?![<>])/<E msg="BACHOIR{orthu}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Aa]r<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	s/(?<![<>])(<D>[\x{c1}\x{e1}]r<\/D> <A pl="n" gnt="n">dh\x{e1}<\/A> (?:<N[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<D>[\x{c1}\x{e1}]r<\/D> (?:<N[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Aa]rb<\/V> <[A-DF-Z][^>]*>[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{ar}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Aa]rbh<\/V> <[A-DF-Z][^>]*>(?:[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}fF]|[Ff]h?[lr])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{ar}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Aa]rbh<\/V> <[A-DF-Z][^>]*>[Ff][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<[A-DF-Z][^>]*>mb'[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="NIURU">$1<\/E>/g) {
	s/(<[A-DF-Z][^>]*>(?:[Dd]h?\x{e1}|[Gg]o|[Nn]ach)<\/[A-DF-Z]> <E[^>]*><[A-DF-Z][^>]*>mb'[^<]+<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<V cop="y">m?[Bb]a<\/V> (?:<[AN][^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/[AN]>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">m?[Bb]a<\/V> (?:<[AN][^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/[AN]>))(?![<>])/<E msg="BACHOIR{b', ab}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="f">[Bb]eirt<\/N> (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<N pl="n" gnt="n" gnd="f">m?[Bb]h?eirt<\/N> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*><N pl="n" gnt="n" gnd="f">m?[Bb]h?eirt<\/N> <N pl="y" gnt="y" gnd="f">bhan<\/N><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n" gnd="f">m?[Bb]h?eirt<\/N> <N pl="n" gnt="n" gnd="f">m?bh?ean<\/N>)(?![<>])/<E msg="BACHOIR{bhan}">$1<\/E>/g;
	if (s/(?<![<>])((?:<N[^>]*>[Bb]h?eirte?<\/N>) (?:<N[^>]*>[^<]+<\/N>) (?:<A[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/A>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*>(?:<N[^>]*>[Bb]h?eirte?<\/N>) (?:<N[^>]*>[^<]+<\/N>) <[A-DF-Z][^>]*>(?:seo|sin)<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<D>[Bb]hur<\/D> <A pl="n" gnt="n">dh\x{e1}<\/A> (?:<N[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<D>[Bb]hur<\/D> <[A-DF-Z][^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Cc][\x{e1}\x{e9}]<\/[A-DF-Z]> (?:<N[^>]*>[Mm]h?\x{e9}id<\/N>))(?![<>])/<E msg="CAIGHDEAN{mh\x{e9}ad}">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc][\x{e1}\x{e9}] [Mm]h\x{e9}ad<\/Q> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Cc]\x{e1}<\/V> (?:<N[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	if (s/(?<![<>])(<V cop="y">[Cc]\x{e1}<\/V> (?:<N[^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><V cop="y">[Cc]\x{e1}<\/V> (?:<N[^>]*>(?:mhinice|fhad)<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<V cop="y">[Cc]\x{e1}<\/V> <N pl="n" gnt="n" gnd="f">minice<\/N>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Cc]\x{e1}<\/V> <N pl="n" gnt="n" gnd="m">fad<\/N>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<Q>[Cc]\x{e1}<\/Q> (?:<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{c\x{e1}r}">$1<\/E>/g) {
	s/(<E[^>]*><Q>[Cc]\x{e1}<\/Q> (?:<V[^>]*t="caite"[^>]*>(?:nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<Q>[Cc]\x{e1}<\/Q> (?:<V[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e1}r<\/Q> (?:<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{c\x{e1}}">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e1}r<\/Q> (?:<V[^>]*t="caite"[^>]*>(?:(?:d\x{fa}i?r|rai?bh|fuair|fhac|dheach|dhearna)[^<]*|fuarthas)<\/V>))(?![<>])/<E msg="BACHOIR{c\x{e1}}">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e1}r<\/Q> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Cc]\x{e1}r<\/V> <[A-DF-Z][^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{c\x{e1}rb, c\x{e1}rbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Cc]\x{e1}r<\/V> <[A-DF-Z][^>]*>[Ff][Hh][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{c\x{e1}rbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Cc]\x{e1}rb<\/V> <[A-DF-Z][^>]*>[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{c\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Cc]\x{e1}rbh<\/V> <[A-DF-Z][^>]*>(?:[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}fF]|[Ff]h?[lr])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{c\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<S>(?:[Dd][eo]n|[Ss]an?|[Ff]aoin|[\x{d3}\x{f3}]n)<\/S> <[A-DF-Z][^>]*>[Cc]has<\/[A-DF-Z]>)(?![<>])/<E msg="IONADAI{ch\x{e1}s}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> <[A-DF-Z][^>]*>g[Cc]as<\/[A-DF-Z]>)(?![<>])/<E msg="IONADAI{i gc\x{e1}s}">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e9}<\/Q> <R>[Aa]r bith<\/R>)(?![<>])/<E msg="BACHOIR{cib\x{e9}}">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e9}<\/Q> <N pl="n" gnt="n" gnd="m">bith<\/N>)(?![<>])/<E msg="BACHOIR{cib\x{e9}}">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e9}<\/Q> <N pl="n" gnt="n" gnd="m">rud<\/N>)(?![<>])/<E msg="BACHOIR{c\x{e9}ard}">$1<\/E>/g;
	if (s/(?<![<>])(<Q>[Cc]\x{e9}<\/Q> (?:<P[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/P>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g) {
	s/(<E[^>]*><Q>[Cc]\x{e9}<\/Q> (?:<P[^>]*>ea<\/P>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<Q>[Cc]\x{e9}<\/Q> <T>an<\/T>)(?![<>])/<E msg="BACHOIR{c\x{e9}n}">$1<\/E>/g;
	s/(?<![<>])(<T>[Aa]n<\/T> <N pl="n" gnt="n" gnd="m">[Cc]head<\/N> (?:<N[^>]*>[^<]+<\/N>))(?![<>])/<E msg="IONADAI{ch\x{e9}ad}">$1<\/E>/g;
	s/(?<![<>])(<T>[^<]+<\/T> <A pl="n" gnt="n">c\x{e9}ad<\/A>)(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]na<\/S> <A pl="n" gnt="n">c\x{e9}ad<\/A>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<D>[Aa]<\/D> <A pl="n" gnt="n">c\x{e9}ad<\/A> (?:<N[^>]*>(?:[BbCcFfGgMmPp][^Hh']|bh[fF])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<D>[Aa]<\/D> <A pl="n" gnt="n">c\x{e9}ad<\/A> (?:<N[^>]*>[DdSsTt][Hh][^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<N pl="y" gnt="n" gnd="m">[Cc]eanna<\/N>)(?![<>])/<E msg="IONADAI{c\x{e9}anna}">$1<\/E>/g) {
	s/((?:<[STV][^>]*>[^<]+<\/[STV]>) <E[^>]*><N pl="y" gnt="n" gnd="m">[Cc]eanna<\/N><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<A pl="n" gnt="n">[Gg]ach<\/A> <N pl="n" gnt="n" gnd="m">[Cc]eard<\/N>)(?![<>])/<E msg="CAIGHDEAN{cearn}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Cc]eard<\/N> <S>faoi<\/S>)(?![<>])/<E msg="IONADAI{c\x{e9}ard}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Cc]eard<\/N> <V cop="y">[^<]+<\/V>)(?![<>])/<E msg="IONADAI{c\x{e9}ard}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Cc]eard<\/N> <[A-DF-Z][^>]*>[Aa]<\/[A-DF-Z]> (?:<V[^>]*>[^<]+<\/V>))(?![<>])/<E msg="IONADAI{c\x{e9}ard}">$1<\/E>/g;
	if (s/(?<![<>])(<N pl="n" gnt="n" gnd="m">g?[Cc]h?eathrar<\/N> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*><N pl="n" gnt="n" gnd="m">g?[Cc]h?eathrar<\/N> <N pl="y" gnt="y" gnd="f">ban<\/N><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">g?[Cc]h?eathrar<\/N> <N pl="n" gnt="n" gnd="f">m?bh?ean<\/N>)(?![<>])/<E msg="BACHOIR{ban}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">g?[Cc]h?eithre<\/A> <[A-DF-Z][^>]*>uaire?<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{huaire}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>g?[Cc]h?eithre<\/[A-DF-Z]> (?:<N[^>]*>airde<\/N>))(?![<>])/<E msg="BACHOIR{hairde}">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">g?[Cc]h?eithre<\/A> (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g) {
	s/(<T>[Nn]a<\/T> <E[^>]*><A pl="n" gnt="n">g?[Cc]h?eithre<\/A> (?:<N[^>]*>[Dd]\x{fa}ile<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><A pl="n" gnt="n">g?[Cc]h?eithre<\/A> (?:<N[^>]*>(?:[Bb]liana|[Cc]inn|[Cc]loigne|[Cc]uarta|[Ff]ichid|[Ss]eachtaine)<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<A pl="n" gnt="n">g?[Cc]h?eithre<\/A> <N pl="n" gnt="n" gnd="f">[Bb]hliain<\/N>)(?![<>])/<E msg="BACHOIR{bliana}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">g?[Cc]h?eithre<\/A> <N pl="n" gnt="n" gnd="m">[Cc]heann<\/N>)(?![<>])/<E msg="BACHOIR{cinn}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">g?[Cc]h?eithre<\/A> <N pl="n" gnt="n" gnd="m">[Cc]hloigeann<\/N>)(?![<>])/<E msg="BACHOIR{cloigne}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">g?[Cc]h?eithre<\/A> <N pl="n" gnt="n" gnd="f">[Cc]huairt<\/N>)(?![<>])/<E msg="BACHOIR{cuarta}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">g?[Cc]h?eithre<\/A> <N pl="n" gnt="n" gnd="m">[Ff]hiche<\/N>)(?![<>])/<E msg="BACHOIR{fichid}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">g?[Cc]h?eithre<\/A> <N pl="n" gnt="n" gnd="f">[Ss]heachtain<\/N>)(?![<>])/<E msg="BACHOIR{seachtaine}">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">g?[Cc]h?eithre<\/A> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*><A pl="n" gnt="n">g?[Cc]h?eithre<\/A> (?:<N[^>]*pl="y"[^>]*>(?:bliana|cinn|cloigne|fichid|huaire)<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<Q>[Cc]\x{e9}n<\/Q> <N pl="n" gnt="n" gnd="m">[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<Q>[Cc]\x{e9}n<\/Q> <N pl="n" gnt="n" gnd="f">[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}h][^<]+<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Cc]\x{e9}r<\/V> <[A-DF-Z][^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{c\x{e9}rb, c\x{e9}rbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Cc]\x{e9}r<\/V> <[A-DF-Z][^>]*>[Ff][Hh][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{c\x{e9}rbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Cc]\x{e9}rb<\/V> <[A-DF-Z][^>]*>[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{c\x{e9}r}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Cc]\x{e9}rbh<\/V> <[A-DF-Z][^>]*>(?:[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}fF]|[Ff]h?[lr])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{c\x{e9}r}">$1<\/E>/g;
	if (s/(?<![<>])(<U>[Cc]ha<\/U> (?:<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{char}">$1<\/E>/g) {
	s/(<E[^>]*><U>[Cc]ha<\/U> (?:<V[^>]*t="caite"[^>]*>(?:raibh|dt\x{e1}inig|dtug|ndearnadh|gcuala|bhfuair)<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<U>[Cc]ha<\/U> <[A-DF-Z][^>]*>(?:[BbCcFfGgMmPp][^Hh']|bh[fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]ha<\/U> <[A-DF-Z][^>]*>[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]ha<\/U> <[A-DF-Z][^>]*>(?:[tT]|[Dd][^Tt'])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]ha<\/U> <[A-DF-Z][^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{chan}">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]har<\/U> (?:<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{cha}">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]har<\/U> (?:<V[^>]*t="caite"[^>]*>(?:(?:d\x{fa}i?r|rai?bh|fuair|fhac|dheach|dhearna)[^<]*|fuarthas)<\/V>))(?![<>])/<E msg="BACHOIR{cha}">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]har<\/U> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]ha<\/U> <[A-DF-Z][^>]*>ar<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{char}">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]ha<\/U> <[A-DF-Z][^>]*>arbh<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{charbh}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Cc]h\x{e9}ad<\/A> (?:<N[^>]*>(?:[BbCcFfGgMmPp][^Hh']|bh[fF])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Cc]h\x{e9}ad<\/A> (?:<N[^>]*>[DdSsTt][Hh][^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<R>[Cc]homh<\/R> <A pl="n" gnt="n">[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/A>)(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<S>[Cc]huig<\/S> <T>an<\/T> (?:<N[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Cc]huig<\/S> (?:<[^\/Y][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[^Y]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><S>[Cc]huig<\/S> <[A-DF-Z][^>]*>(?:bhur|dh\x{e1}|thart)<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Cc]huig<\/S> <T>an<\/T> <N pl="n" gnt="n" gnd="m">t(?:[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/N>)(?![<>])/<E msg="NITEE">$1<\/E>/g;
	if (s/(?<![<>])(<[A-DF-Z][^>]*>[Cc]hun<\/[A-DF-Z]> (?:<[^\/Y][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[^Y]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><[A-DF-Z][^>]*>[Cc]hun<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="f">bheith<\/N><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><[A-DF-Z][^>]*>[Cc]hun<\/[A-DF-Z]> <[A-DF-Z][^>]*>(?:bhur|dh\x{e1}|th\x{fa})<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Cc]hun<\/S> <T>[Aa]n<\/T> <N pl="n" gnt="n" gnd="m">[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Aa]<\/[A-DF-Z]> <[A-DF-Z][^>]*>g?[Cc]loi?g<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[^<]+<\/V> <N pl="n" gnt="n" gnd="f">[Cc]hoir<\/N>)(?![<>])/<E msg="IONADAI(ch\x{f3}ir}">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">cuibheasach<\/A> (?:<A[^>]*>[^<]+<\/A>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*><A pl="n" gnt="n">cuibheasach<\/A> <A pl="n" gnt="n">[^<]+<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Cc]huig<\/S> (?:<P[^>]*>[Mm]\x{e9}<\/P>))(?![<>])/<E msg="BACHOIR{chugam}">$1<\/E>/g;
	s/(?<![<>])(<S>[Cc]huig<\/S> (?:<P[^>]*>[Tt]h?\x{fa}<\/P>))(?![<>])/<E msg="BACHOIR{chugat}">$1<\/E>/g;
	s/(?<![<>])(<S>[Cc]huig<\/S> (?:<P[^>]*>[\x{c9}\x{e9}]<\/P>))(?![<>])/<E msg="BACHOIR{chuige}">$1<\/E>/g;
	s/(?<![<>])(<S>[Cc]huig<\/S> (?:<P[^>]*>[\x{cd}\x{ed}]<\/P>))(?![<>])/<E msg="BACHOIR{chuici}">$1<\/E>/g;
	s/(?<![<>])(<S>[Cc]huig<\/S> (?:<P[^>]*>(?:[Mm]uid|[Ss]inn)<\/P>))(?![<>])/<E msg="BACHOIR{chugainn}">$1<\/E>/g;
	s/(?<![<>])(<S>[Cc]huig<\/S> (?:<P[^>]*>[Ss]ibh<\/P>))(?![<>])/<E msg="BACHOIR{chugaibh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Cc]huig<\/S> (?:<P[^>]*>[Ii]ad<\/P>))(?![<>])/<E msg="BACHOIR{chucu}">$1<\/E>/g;
	if (s/(?<![<>])(<[A-DF-Z][^>]*>g?[Cc]h?\x{fa}ig<\/[A-DF-Z]> (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><[A-DF-Z][^>]*>g?[Cc]h?\x{fa}ig<\/[A-DF-Z]> (?:<N[^>]*>(?:[Bb]liana|[Cc]inn|[Cc]loigne|[Cc]uarta|[Ff]ichid|[Ss]eachtaine)<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<[A-DF-Z][^>]*>g?[Cc]h?\x{fa}ig<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="f">[Bb]hliain<\/N>)(?![<>])/<E msg="BACHOIR{bliana}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>g?[Cc]h?\x{fa}ig<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="m">[Cc]heann<\/N>)(?![<>])/<E msg="BACHOIR{cinn}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>g?[Cc]h?\x{fa}ig<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="m">[Cc]hloigeann<\/N>)(?![<>])/<E msg="BACHOIR{cloigne}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>g?[Cc]h?\x{fa}ig<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="f">[Cc]huairt<\/N>)(?![<>])/<E msg="BACHOIR{cuarta}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>g?[Cc]h?\x{fa}ig<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="m">[Ff]hiche<\/N>)(?![<>])/<E msg="BACHOIR{fichid}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>g?[Cc]h?\x{fa}ig<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="f">[Ss]heachtain<\/N>)(?![<>])/<E msg="BACHOIR{seachtaine}">$1<\/E>/g;
	if (s/(?<![<>])(<[A-DF-Z][^>]*>g?[Cc]h?\x{fa}ig<\/[A-DF-Z]> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*><[A-DF-Z][^>]*>g?[Cc]h?\x{fa}ig<\/[A-DF-Z]> (?:<N[^>]*pl="y"[^>]*>(?:bliana|cinn|cloigne|fichid|huaire)<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<N pl="n" gnt="n" gnd="m">g?[Cc]h?\x{fa}igear<\/N> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*><N pl="n" gnt="n" gnd="m">g?[Cc]h?\x{fa}igear<\/N> <N pl="y" gnt="y" gnd="f">ban<\/N><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">g?[Cc]h?\x{fa}igear<\/N> <N pl="n" gnt="n" gnd="f">m?bh?ean<\/N>)(?![<>])/<E msg="BACHOIR{ban}">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Cc]hun<\/S> (?:<P[^>]*>[Mm]\x{e9}<\/P>))(?![<>])/<E msg="BACHOIR{chugam}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Cc]hun<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Cc]hun<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Cc]hun<\/S> (?:<P[^>]*>[Tt]h?\x{fa}<\/P>))(?![<>])/<E msg="BACHOIR{chugat}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Cc]hun<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Cc]hun<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Cc]hun<\/S> (?:<P[^>]*>[\x{c9}\x{e9}]<\/P>))(?![<>])/<E msg="BACHOIR{chuige}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Cc]hun<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Cc]hun<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Cc]hun<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Cc]hun<\/S> (?:<P[^>]*>[\x{cd}\x{ed}]<\/P>))(?![<>])/<E msg="BACHOIR{chuici}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Cc]hun<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Cc]hun<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Cc]hun<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Cc]hun<\/S> (?:<P[^>]*>(?:[Mm]uid|[Ss]inn)<\/P>))(?![<>])/<E msg="BACHOIR{chugainn}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Cc]hun<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Cc]hun<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Cc]hun<\/S> (?:<P[^>]*>[Ss]ibh<\/P>))(?![<>])/<E msg="BACHOIR{chugaibh}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Cc]hun<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Cc]hun<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Cc]hun<\/S> (?:<P[^>]*>[Ii]ad<\/P>))(?![<>])/<E msg="BACHOIR{chucu}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Cc]hun<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Cc]hun<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Cc]hun<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<N[^>]*>g?[Cc]h?unta<\/N>))(?![<>])/<E msg="IONADAI{c\x{fa}nta}">$1<\/E>/g) {
	s/(<T>[Aa]n<\/T> <E[^>]*>(?:<N[^>]*>[Cc]h?unta<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<N[^>]*>[Cc]h?unta<\/N>)<\/E> <Y>[^<]+<\/Y>)/strip_errors($1);/eg;
	}
	s/(?<![<>])((?:<N[^>]*>[Cc]h?\x{fa}pla<\/N>) (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*>[Cc]h?\x{fa}pla<\/N>) (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="NOGENITIVE">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]\x{e1}<\/[A-DF-Z]> (?:<N[^>]*>[Mm]h?\x{e9}id<\/N>))(?![<>])/<E msg="CAIGHDEAN{mh\x{e9}ad}">$1<\/E>/g;
	if (s/(?<![<>])(<C>[Dd]\x{e1}<\/C> (?:<V[^>]*t="...[^n][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{m\x{e1}}">$1<\/E>/g) {
	s/((?:<[^\/C][^>]*>[^<]+<\/[^C]>) <E[^>]*><C>[Dd]\x{e1}<\/C> (?:<V[^>]*t="...[^n][^>]*>[^<]+<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<C>[Dd]\x{e1}<\/C> (?:<V[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<S>[Dd]ar<\/S> <T>an<\/T> (?:<N[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Dd]ar<\/V> <[A-DF-Z][^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{darb, darbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Dd]ar<\/V> <[A-DF-Z][^>]*>[Ff][Hh][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{darbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Dd]arb<\/V> <[A-DF-Z][^>]*>[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{dar}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Dd]arbh<\/V> <[A-DF-Z][^>]*>(?:[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}fF]|[Ff]h?[lr])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{dar}">$1<\/E>/g;
	s/(?<![<>])(<D>[Dd]\x{e1}r<\/D> <A pl="n" gnt="n">dh\x{e1}<\/A> (?:<N[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<D>[Dd]\x{e1}r<\/D> <[A-DF-Z][^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]\x{e1}r<\/[A-DF-Z]> (?:<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{d\x{e1}}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]\x{e1}r<\/[A-DF-Z]> (?:<V[^>]*t="caite"[^>]*>(?:(?:d\x{fa}i?r|rai?bh|fuair|fhac|dheach|dhearna)[^<]*|fuarthas)<\/V>))(?![<>])/<E msg="BACHOIR{d\x{e1}}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]\x{e1}r<\/[A-DF-Z]> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])((?:<N[^>]*>n?[Dd]h?\x{e1}r\x{e9}ag<\/N>) (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*>(?:<N[^>]*>n?[Dd]h?\x{e1}r\x{e9}ag<\/N>) <N pl="y" gnt="y" gnd="f">ban<\/N><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])((?:<N[^>]*>n?[Dd]h?\x{e1}r\x{e9}ag<\/N>) <N pl="n" gnt="n" gnd="f">m?bh?ean<\/N>)(?![<>])/<E msg="BACHOIR{ban}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>D\x{e9}<\/[A-DF-Z]> <[A-DF-Z][^>]*>Aoine<\/[A-DF-Z]>)(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>nd\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="CAIGHDEAN{d\x{e9}ag}">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]*[^bcdfghjlmnprstvxz<]+<\/N>) <[A-DF-Z][^>]*>d\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*pl="y"[^>]*>[^<]*[e\x{e9}i\x{ed}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}<]+<\/N>) <[A-DF-Z][^>]*>d\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>n?[Dd]h?\x{f3}<\/[A-DF-Z]> <[A-DF-Z][^>]*>[Dd]h?\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{a d\x{f3} dh\x{e9}ag, dh\x{e1} X d\x{e9}ag}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Aa] [Dd]\x{f3}<\/A> <[A-DF-Z][^>]*>[Dd]\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{a d\x{f3} dh\x{e9}ag, dh\x{e1} X d\x{e9}ag}">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">[Dd]\x{f3} [Dd]h\x{e9}ag<\/A>)(?![<>])/<E msg="INPHRASE{a d\x{f3} dh\x{e9}ag, dh\x{e1} X d\x{e9}ag}">$1<\/E>/g) {
	s/(<C>[Nn]\x{f3}<\/C> <E[^>]*><A pl="n" gnt="n">[Dd]\x{f3} [Dd]h\x{e9}ag<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<[A-DF-Z][^>]*>d?[Tt]h?r\x{ed}<\/[A-DF-Z]> <[A-DF-Z][^>]*>[Dd]h?\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{a tr\x{ed} d\x{e9}ag, tr\x{ed} X d\x{e9}ag}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Aa] [Tt]r\x{ed}<\/A> <[A-DF-Z][^>]*>[Dd]h\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{a tr\x{ed} d\x{e9}ag, tr\x{ed} X d\x{e9}ag}">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">[Tt]r\x{ed} [Dd]\x{e9}ag<\/A>)(?![<>])/<E msg="INPHRASE{a tr\x{ed} d\x{e9}ag, tr\x{ed} X d\x{e9}ag}">$1<\/E>/g) {
	s/(<C>[Nn]\x{f3}<\/C> <E[^>]*><A pl="n" gnt="n">[Tt]r\x{ed} [Dd]\x{e9}ag<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<[A-DF-Z][^>]*>g?[Cc]h?eathair<\/[A-DF-Z]> <[A-DF-Z][^>]*>[Dd]h?\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{a ceathair d\x{e9}ag, ceithre X d\x{e9}ag}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Aa] [Cc]eathair<\/A> <[A-DF-Z][^>]*>[Dd]h\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{a ceathair d\x{e9}ag, ceathair X d\x{e9}ag}">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">[Cc]eathair [Dd]\x{e9}ag<\/A>)(?![<>])/<E msg="INPHRASE{a ceathair d\x{e9}ag, ceithre X d\x{e9}ag}">$1<\/E>/g) {
	s/(<C>[Nn]\x{f3}<\/C> <E[^>]*><A pl="n" gnt="n">[Cc]eathair [Dd]\x{e9}ag<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<[A-DF-Z][^>]*>g?[Cc]h?\x{fa}ig<\/[A-DF-Z]> <[A-DF-Z][^>]*>[Dd]h?\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{a c\x{fa}ig d\x{e9}ag, c\x{fa}ig X d\x{e9}ag}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Aa] [Cc]\x{fa}ig<\/A> <[A-DF-Z][^>]*>[Dd]h\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{a c\x{fa}ig d\x{e9}ag, c\x{fa}ig X d\x{e9}ag}">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">[Cc]\x{fa}ig [Dd]\x{e9}ag<\/A>)(?![<>])/<E msg="INPHRASE{a c\x{fa}ig d\x{e9}ag, c\x{fa}ig X d\x{e9}ag}">$1<\/E>/g) {
	s/(<C>[Nn]\x{f3}<\/C> <E[^>]*><A pl="n" gnt="n">[Cc]\x{fa}ig [Dd]\x{e9}ag<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<[A-DF-Z][^>]*>[Ss]h?\x{e9}<\/[A-DF-Z]> <[A-DF-Z][^>]*>[Dd]h?\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{a s\x{e9} d\x{e9}ag, s\x{e9} X d\x{e9}ag}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Aa] [Ss]\x{e9}<\/A> <[A-DF-Z][^>]*>[Dd]h\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{a s\x{e9} d\x{e9}ag, s\x{e9} X d\x{e9}ag}">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">[Ss]\x{e9} [Dd]\x{e9}ag<\/A>)(?![<>])/<E msg="INPHRASE{a s\x{e9} d\x{e9}ag, s\x{e9} X d\x{e9}ag}">$1<\/E>/g) {
	s/(<C>[Nn]\x{f3}<\/C> <E[^>]*><A pl="n" gnt="n">[Ss]\x{e9} [Dd]\x{e9}ag<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<[A-DF-Z][^>]*>[Ss]h?eacht<\/[A-DF-Z]> <[A-DF-Z][^>]*>[Dd]h?\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{a seacht d\x{e9}ag, seacht X d\x{e9}ag}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Aa] [Ss]eacht<\/A> <[A-DF-Z][^>]*>[Dd]h\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{a seacht d\x{e9}ag, seacht X d\x{e9}ag}">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">[Ss]eacht [Dd]\x{e9}ag<\/A>)(?![<>])/<E msg="INPHRASE{a seacht d\x{e9}ag, seacht X d\x{e9}ag}">$1<\/E>/g) {
	s/(<C>[Nn]\x{f3}<\/C> <E[^>]*><A pl="n" gnt="n">[Ss]eacht [Dd]\x{e9}ag<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<[A-DF-Z][^>]*>h?[Oo]cht<\/[A-DF-Z]> <[A-DF-Z][^>]*>[Dd]h?\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{a hocht d\x{e9}ag, ocht X d\x{e9}ag}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Aa] h[Oo]cht<\/A> <[A-DF-Z][^>]*>[Dd]h\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{a hocht d\x{e9}ag, ocht X d\x{e9}ag}">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">[Oo]cht [Dd]\x{e9}ag<\/A>)(?![<>])/<E msg="INPHRASE{a hocht d\x{e9}ag, ocht X d\x{e9}ag}">$1<\/E>/g) {
	s/(<C>[Nn]\x{f3}<\/C> <E[^>]*><A pl="n" gnt="n">[Oo]cht [Dd]\x{e9}ag<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]aoi<\/[A-DF-Z]> <[A-DF-Z][^>]*>[Dd]h?\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{a naoi d\x{e9}ag, naoi X d\x{e9}ag}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Aa] [Nn]aoi<\/A> <[A-DF-Z][^>]*>[Dd]h\x{e9}ag<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{a naoi d\x{e9}ag, naoi X d\x{e9}ag}">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">[Nn]aoi [Dd]\x{e9}ag<\/A>)(?![<>])/<E msg="INPHRASE{a naoi d\x{e9}ag, naoi X d\x{e9}ag}">$1<\/E>/g) {
	s/(<C>[Nn]\x{f3}<\/C> <E[^>]*><A pl="n" gnt="n">[Nn]aoi [Dd]\x{e9}ag<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<[A-DF-Z][^>]*>n?[Dd]h?eich<\/[A-DF-Z]> (?:<N[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>n?[Dd]h?eich<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="f">m[Bb]liain<\/N>)(?![<>])/<E msg="BACHOIR{mbliana}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>n?[Dd]h?eich<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="m">g[Cc]eann<\/N>)(?![<>])/<E msg="BACHOIR{gcinn}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>n?[Dd]h?eich<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="m">g[Cc]loigeann<\/N>)(?![<>])/<E msg="BACHOIR{gcloigne}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>n?[Dd]h?eich<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="f">g[Cc]uairt<\/N>)(?![<>])/<E msg="BACHOIR{gcuarta}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>n?[Dd]h?eich<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="m">bh[Ff]iche<\/N>)(?![<>])/<E msg="BACHOIR{bhfichid}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>n?[Dd]h?eich<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="f">[Ss]eachtain<\/N>)(?![<>])/<E msg="BACHOIR{seachtaine}">$1<\/E>/g;
	if (s/(?<![<>])(<[A-DF-Z][^>]*>n?[Dd]h?eich<\/[A-DF-Z]> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*><[A-DF-Z][^>]*>n?[Dd]h?eich<\/[A-DF-Z]> (?:<N[^>]*pl="y"[^>]*>(?:mbliana|gcinn|gcloigne|bhfichid|n-uaire)<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<N pl="n" gnt="n" gnd="m">n?[Dd]h?eichni\x{fa}r<\/N> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*><N pl="n" gnt="n" gnd="m">n?[Dd]h?eichni\x{fa}r<\/N> <N pl="y" gnt="y" gnd="f">ban<\/N><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">n?[Dd]h?eichni\x{fa}r<\/N> <N pl="n" gnt="n" gnd="f">m?bh?ean<\/N>)(?![<>])/<E msg="BACHOIR{ban}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd][eo]<\/[A-DF-Z]> (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd][eo]n?<\/[A-DF-Z]> <V cop="y">(?:is|ar|arb)<\/V>)(?![<>])/<E msg="BACHOIR{dar, darb}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd][eo]n?<\/[A-DF-Z]> <V cop="y">(?:ba|ab|arbh)<\/V>)(?![<>])/<E msg="BACHOIR{dar, darbh}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd][eo]n?<\/[A-DF-Z]> <[A-DF-Z][^>]*>b'[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{darbh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Dd][eo]n<\/S> (?:<N[^>]*>(?:[BbCcFfGgMmPp][^Hh']|bh[fF])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Dd][eo]n<\/S> (?:<N[^>]*>(?:n[Dd]|d[Tt]|[DdSsTt][Hh])[^<]+<\/N>))(?![<>])/<E msg="NICLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Dd][eo]n<\/S> <N pl="n" gnt="n" gnd="f">[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}h][^<]+<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]e<\/[A-DF-Z]> <T>an<\/T>)(?![<>])/<E msg="BACHOIR{den}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Dd]h\x{e1}<\/A> (?:<V[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/V>))(?![<>])/<E msg="CAIGHDEAN{d\x{e1}}">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">[Dd]h\x{e1}<\/A> <[A-DF-Z][^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g) {
	s/(<D>(?:[Aa]|[\x{c1}\x{e1}]r|[Bb]hur)<\/D> <E[^>]*><A pl="n" gnt="n">[Dd]h\x{e1}<\/A> <[A-DF-Z][^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<A pl="n" gnt="n">[Dd]h\x{e1}<\/A> <[A-DF-Z][^>]*>[Bb]hliana<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{bhliain}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Dd]h\x{e1}<\/A> <[A-DF-Z][^>]*>[Cc]hinn<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{cheann}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Dd]h\x{e1}<\/A> <[A-DF-Z][^>]*>[Cc]hloigne<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{chloigeann}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Dd]h\x{e1}<\/A> <[A-DF-Z][^>]*>[Ff]hichid<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{chloigeann}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Dd]h\x{e1}<\/A> <[A-DF-Z][^>]*>h?uaire<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{uair}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Dd]h\x{e1}<\/A> <[A-DF-Z][^>]*>m?[Bb]h?os<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{bhois}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Dd]h\x{e1}<\/A> <[A-DF-Z][^>]*>m?[Bb]h?r\x{f3}g<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{bhr\x{f3}ig}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Dd]h\x{e1}<\/A> <[A-DF-Z][^>]*>g?[Cc]h?luas<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{chluais}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Dd]h\x{e1}<\/A> <[A-DF-Z][^>]*>g?[Cc]h?os<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{chois}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Dd]h\x{e1}<\/A> <[A-DF-Z][^>]*>[Ll]\x{e1}mh<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{l\x{e1}imh}">$1<\/E>/g;
	s/(?<![<>])(<T>[Aa]n<\/T> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>(?:[Dd][eo]n|[Ss]an?|[Ff]aoin|[\x{d3}\x{f3}]n)<\/S> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Cc]h?\x{e9}ad<\/A> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Cc]h?\x{e9}ad<\/A> (?:<N[^>]*>[Dd]h\x{e1}r\x{e9}ag<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])((?:<N[^>]*>[Dd]\x{e1}r\x{e9}ag<\/N>))(?![<>])/<E msg="BACHOIR{dh\x{e1}r\x{e9}ag}">$1<\/E>/g) {
	s/(<T>[Aa]n<\/T> <E[^>]*>(?:<N[^>]*>[Dd]\x{e1}r\x{e9}ag<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<S>(?:[Dd][eo]n|[Ss]an?|[Ff]aoin|[\x{d3}\x{f3}]n)<\/S> <E[^>]*>(?:<N[^>]*>[Dd]\x{e1}r\x{e9}ag<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<A pl="n" gnt="n">[Aa]on<\/A> <E[^>]*>(?:<N[^>]*>[Dd]\x{e1}r\x{e9}ag<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<A pl="n" gnt="n">[Cc]h?\x{e9}ad<\/A> <E[^>]*>(?:<N[^>]*>[Dd]\x{e1}r\x{e9}ag<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<A pl="n" gnt="n">[Dd]h\x{e1}<\/A> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g;
	s/(?<![<>])(<T>[Aa]n<\/T> <[A-DF-Z][^>]*>[Dd]\x{e1}<\/[A-DF-Z]> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]h?\x{ed}s<\/[A-DF-Z]> (?:<N[^>]*gnt="n"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="GENITIVE">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]h?\x{ed}s<\/[A-DF-Z]> (?:<N[^>]*pl="n"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="IOLRA">$1<\/E>/g;
	if (s/(?<![<>])(<C>n\x{f3}<\/C> <[A-DF-Z][^>]*>d\x{f3}<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g) {
	s/((?:<O[^>]*>di<\/O>) <E[^>]*><C>n\x{f3}<\/C> <[A-DF-Z][^>]*>d\x{f3}<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<[A-DF-Z][^>]*>dh\x{f3}<\/[A-DF-Z]>)(?![<>])/<E msg="CAIGHDEAN{d\x{f3}}">$1<\/E>/g) {
	s/(<[A-DF-Z][^>]*>(?:a|\x{e1})<\/[A-DF-Z]> <E[^>]*><N pl="n" gnt="n" gnd="m">dh\x{f3}<\/N><\/E>)/strip_errors($1);/eg;
	s/(<C>n\x{f3}<\/C> <E[^>]*><[A-DF-Z][^>]*>dh\x{f3}<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]o<\/[A-DF-Z]> <T>an<\/T>)(?![<>])/<E msg="BACHOIR{don}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd][eo]<\/[A-DF-Z]> (?:<N[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/N>))(?![<>])/<E msg="BACHOIR{d+uascham\x{f3}g}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]o<\/[A-DF-Z]> <[A-DF-Z][^>]*>a<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{d\x{e1}}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd][eo]<\/[A-DF-Z]> <[A-DF-Z][^>]*>[\x{e1}a]r<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{d\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]o<\/[A-DF-Z]> <[A-DF-Z][^>]*>r\x{e9}ir<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{de r\x{e9}ir}">$1<\/E>/g;
	s/(?<![<>])(<S>[Dd]o<\/S> (?:<P[^>]*>[Mm]\x{e9}<\/P>))(?![<>])/<E msg="BACHOIR{dom}">$1<\/E>/g;
	s/(?<![<>])(<S>[Dd]o<\/S> (?:<P[^>]*>[Tt]h?\x{fa}<\/P>))(?![<>])/<E msg="BACHOIR{duit}">$1<\/E>/g;
	s/(?<![<>])(<S>[Dd]o<\/S> (?:<P[^>]*>[\x{c9}\x{e9}]<\/P>))(?![<>])/<E msg="BACHOIR{d\x{f3}}">$1<\/E>/g;
	s/(?<![<>])(<S>[Dd]o<\/S> (?:<P[^>]*>[\x{cd}\x{ed}]<\/P>))(?![<>])/<E msg="BACHOIR{di}">$1<\/E>/g;
	s/(?<![<>])(<S>[Dd]o<\/S> (?:<P[^>]*>(?:[Mm]uid|[Ss]inn)<\/P>))(?![<>])/<E msg="BACHOIR{d\x{fa}inn}">$1<\/E>/g;
	s/(?<![<>])(<S>[Dd]o<\/S> (?:<P[^>]*>[Ss]ibh<\/P>))(?![<>])/<E msg="BACHOIR{daoibh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Dd]o<\/S> (?:<P[^>]*>[Ii]ad<\/P>))(?![<>])/<E msg="BACHOIR{d\x{f3}ibh}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]h?osaen<\/[A-DF-Z]> (?:<N[^>]*gnt="n"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="GENITIVE">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]h?osaen<\/[A-DF-Z]> (?:<N[^>]*pl="n"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="IOLRA">$1<\/E>/g;
	s/(?<![<>])(<S>(?:[Aa][grs]|[Cc]huig|[Dd][eo]|[Ff]aoi|[Gg]an|[Gg]o|[Ll]e|[\x{d3}\x{f3}]|[Ii]n?|[Rr]oimh|[Tt]har|[Tt]r\x{ed}d?|[Uu]m)<\/S> (?:<N[^>]*>(?:[nh])?\x{c9}ire(?:ann)?<\/N>))(?![<>])/<E msg="BACHOIR{\x{c9}irinn}">$1<\/E>/g;
	s/(?<![<>])(<S>(?:[Aa][rg]|[Ll]e)<\/S> <N pl="n" gnt="n" gnd="f">[Ff]ail<\/N>)(?![<>])/<E msg="IONADAI{f\x{e1}il}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]<\/S> <N pl="n" gnt="n" gnd="f">fhail<\/N>)(?![<>])/<E msg="IONADAI{fh\x{e1}il}">$1<\/E>/g;
	s/(?<![<>])(<D>[\x{c1}\x{e1}]<\/D> <N pl="n" gnt="n" gnd="f">fhail<\/N>)(?![<>])/<E msg="IONADAI{fh\x{e1}il}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ff]aoi<\/S> (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ff]aoi<\/S> <T>an<\/T>)(?![<>])/<E msg="BACHOIR{faoin}">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Ff]aoi<\/S> (?:<P[^>]*>[Mm]\x{e9}<\/P>))(?![<>])/<E msg="BACHOIR{f\x{fa}m}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ff]aoi<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ff]aoi<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Ff]aoi<\/S> (?:<P[^>]*>[Tt]h?\x{fa}<\/P>))(?![<>])/<E msg="BACHOIR{f\x{fa}t}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ff]aoi<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ff]aoi<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Ff]aoi<\/S> (?:<P[^>]*>[\x{c9}\x{e9}]<\/P>))(?![<>])/<E msg="BACHOIR{faoi}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ff]aoi<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ff]aoi<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ff]aoi<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Ff]aoi<\/S> (?:<P[^>]*>[\x{cd}\x{ed}]<\/P>))(?![<>])/<E msg="BACHOIR{f\x{fa}ithi}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ff]aoi<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ff]aoi<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ff]aoi<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Ff]aoi<\/S> (?:<P[^>]*>(?:[Mm]uid|[Ss]inn)<\/P>))(?![<>])/<E msg="BACHOIR{f\x{fa}inn}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ff]aoi<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ff]aoi<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Ff]aoi<\/S> (?:<P[^>]*>[Ss]ibh<\/P>))(?![<>])/<E msg="BACHOIR{f\x{fa}ibh}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ff]aoi<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ff]aoi<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Ff]aoi<\/S> (?:<P[^>]*>[Ii]ad<\/P>))(?![<>])/<E msg="BACHOIR{f\x{fa}thu}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ff]aoi<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ff]aoi<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ff]aoi<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	s/(?<![<>])(<[A-DF-Z][^>]*>[Ff]aoin?<\/[A-DF-Z]> <[A-DF-Z][^>]*>a<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{faoina}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Ff]aoin?<\/[A-DF-Z]> <[A-DF-Z][^>]*>\x{e1}r<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{faoin\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ff]aoin?<\/S> <V cop="y">(?:is|ar|arb)<\/V>)(?![<>])/<E msg="BACHOIR{faoinar, faoinarb}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ff]aoin?<\/S> <V cop="y">(?:ba|ab|arbh)<\/V>)(?![<>])/<E msg="BACHOIR{faoinar, faoinarbh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ff]aoin?<\/S> <[A-DF-Z][^>]*>b'[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{faoinarbh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ff]aoin<\/S> (?:<N[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ff]aoin<\/S> (?:<N[^>]*>(?:n[Dd]|d[Tt]|[DdSsTt][Hh])[^<]+<\/N>))(?![<>])/<E msg="NICLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ff]aoin<\/S> <N pl="n" gnt="n" gnd="f">[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}h][^<]+<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Ff]aoina<\/S> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Ff]aoina<\/S> (?:<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{faoinar}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ff]aoina<\/S> (?:<V[^>]*t="caite"[^>]*>(?:nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Ff]aoinar<\/S> (?:<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{faoina}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ff]aoinar<\/S> (?:<V[^>]*t="caite"[^>]*>(?:(?:d\x{fa}i?r|rai?bh|fuair|fhac|dheach|dhearna)[^<]*|fuarthas)<\/V>))(?![<>])/<E msg="BACHOIR{faoina}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ff]aoinar<\/S> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ff]aoinar<\/V> <[A-DF-Z][^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{faoinarb, faoinarbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ff]aoinar<\/V> <[A-DF-Z][^>]*>[Ff][Hh][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{faoinarbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ff]aoinarb<\/V> <[A-DF-Z][^>]*>[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{faoinar}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ff]aoinarbh<\/V> <[A-DF-Z][^>]*>(?:[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}fF]|[Ff]h?[lr])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{faoinar}">$1<\/E>/g;
	s/(?<![<>])(<D>[Ff]aoin\x{e1}r<\/D> <A pl="n" gnt="n">dh\x{e1}<\/A> (?:<N[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<D>[Ff]aoin\x{e1}r<\/D> <[A-DF-Z][^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>Fh?\x{e9}ile<\/[A-DF-Z]> <Y>[BCDFGMPST][Hh][^<]+<\/Y>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]g<\/S> <N pl="y" gnt="n" gnd="m">gabhail<\/N>)(?![<>])/<E msg="IONADAI{gabh\x{e1}il}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]<\/S> <N pl="y" gnt="n" gnd="m">ghabhail<\/N>)(?![<>])/<E msg="IONADAI{ghabh\x{e1}il}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Gg]ach<\/A> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> (?:<N[^>]*>[^<]+<\/N>) <C>n\x{f3}<\/C> (?:<N[^>]*>[^<]+<\/N>))(?![<>])/<E msg="BACHOIR{n\x{e1}}">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> (?:<N[^>]*>[DdFfSsTt][Hh][^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> <Y>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/Y>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> (?:<N[^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/N>) <C>n\x{e1}<\/C>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> (?:<N[^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/N>) (?:<[AO][^>]*>[^<]+<\/[AO]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> (?:<N[^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/N>) <[A-DF-Z][^>]*>d\x{e1}<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="m">laghad<\/N>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> (?:<N[^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/N>) <R>ar bith<\/R>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> (?:<N[^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/N>) <R>go br\x{e1}ch<\/R>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> (?:<N[^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/N>) <R>(?:amach|amh\x{e1}in)<\/R>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> (?:<N[^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/N>) (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> (?:<N[^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/N>) <T>[^<]+<\/T> (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> (?:<N[^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/N>) <[A-DF-Z][^>]*>a<\/[A-DF-Z]> (?:<N[^>]*>[^<]*(?:a[dm]h|i[nr]t|\x{e1}il|\x{fa})<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> (?:<N[^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/N>) <[A-DF-Z][^>]*>a<\/[A-DF-Z]> (?:<N[^>]*>(?:bheith|cheannach|chur|dh\x{ed}ol|dhul|fhoghlaim|\x{ed}oc|iompar|oscailt|r\x{e1}|roinnt|scr\x{ed}obh|shol\x{e1}thar|theacht)<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> <T>[Aa]n<\/T> <N pl="n" gnt="n" gnd="m">[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> <T>[Aa]n<\/T> <A pl="n" gnt="n">(?:[Aa]on\x{fa}?|[Oo]cht(?:[\x{f3}\x{fa}]|\x{f3}d\x{fa})?)<\/A>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]an<\/S> <T>an<\/T> <N pl="n" gnt="n" gnd="f">(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Gg]an<\/S> (?:<N[^>]*>[BbCcGgMmPp][^Hh'][^<]*<\/N>))(?![<>])/<E msg="WEAKSEIMHIU{gan}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Gg]an<\/S> (?:<N[^>]*>(?:[Bb]eann|[Bb]reith|[Cc]ead|[Cc][ou]r|[Mm]\x{f3}r\x{e1}n|[Pp]uinn)<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Gg]an<\/S> (?:<N[^>]*>[^<]*(?:a[dm]h|i[nr]t|\x{e1}il|\x{fa})<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Gg]an<\/S> (?:<N[^>]*>[BbCcGgMmPp][^Hh'][^<]*<\/N>)<\/E> <C>n\x{e1}<\/C>)/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Gg]an<\/S> (?:<N[^>]*>[BbCcGgMmPp][^Hh'][^<]*<\/N>)<\/E> (?:<[AO][^>]*>[^<]+<\/[AO]>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Gg]an<\/S> (?:<N[^>]*>[BbCcGgMmPp][^Hh'][^<]*<\/N>)<\/E> <[A-DF-Z][^>]*>d\x{e1}<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="m">laghad<\/N>)/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Gg]an<\/S> (?:<N[^>]*>[BbCcGgMmPp][^Hh'][^<]*<\/N>)<\/E> <R>ar bith<\/R>)/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Gg]an<\/S> (?:<N[^>]*>[BbCcGgMmPp][^Hh'][^<]*<\/N>)<\/E> <R>go br\x{e1}ch<\/R>)/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Gg]an<\/S> (?:<N[^>]*>[BbCcGgMmPp][^Hh'][^<]*<\/N>)<\/E> <R>(?:amach|amh\x{e1}in)<\/R>)/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Gg]an<\/S> (?:<N[^>]*>[BbCcGgMmPp][^Hh'][^<]*<\/N>)<\/E> (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Gg]an<\/S> (?:<N[^>]*>[BbCcGgMmPp][^Hh'][^<]*<\/N>)<\/E> <T>[^<]+<\/T> (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Gg]an<\/S> (?:<N[^>]*>[BbCcGgMmPp][^Hh'][^<]*<\/N>)<\/E> <[A-DF-Z][^>]*>a<\/[A-DF-Z]> (?:<N[^>]*>[^<]*(?:a[dm]h|i[nr]t|\x{e1}il|\x{fa})<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Gg]an<\/S> (?:<N[^>]*>[BbCcGgMmPp][^Hh'][^<]*<\/N>)<\/E> <[A-DF-Z][^>]*>a<\/[A-DF-Z]> (?:<N[^>]*>(?:bheith|cheannach|chur|dh\x{ed}ol|dhul|fhoghlaim|\x{ed}oc|iompar|oscailt|r\x{e1}|roinnt|scr\x{ed}obh|shol\x{e1}thar|theacht)<\/N>))/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Gg]an<\/S> <N pl="n" gnt="n" gnd="m">[Ff]ios<\/N>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> (?:<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{gur}">$1<\/E>/g) {
	s/(<E[^>]*><[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> (?:<V[^>]*t="caite"[^>]*>(?:nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> (?:<[AN][^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[AN]>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> (?:<V[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]o<\/S> <N pl="n" gnt="n" gnd="f">fuil<\/N>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]o<\/S> <N pl="n" gnt="y" gnd="m">t\x{ed}<\/N>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> <[A-DF-Z][^>]*>b'[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	if (s/(?<![<>])(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> (?:<[^\/Y][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[^Y]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="f">bheith<\/N><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> <T>[^<]+<\/T>)(?![<>])/<E msg="BACHOIR{go dt\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> <D>(?:[MmDd]o|[Aa]|[\x{c1}\x{e1}]r|[Bb]hur)<\/D>)(?![<>])/<E msg="BACHOIR{go dt\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> (?:<N[^>]*>[md]'[^<]+<\/N>))(?![<>])/<E msg="BACHOIR{go dt\x{ed}}">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Gg]o dt\x{ed}<\/S> (?:<[^\/Y][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[^Y]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><S>[Gg]o dt\x{ed}<\/S> <[A-DF-Z][^>]*>(?:bhur|dh\x{e1}|thart|th\x{fa})<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Gg]o dt\x{ed}<\/S> <T>[Aa]n<\/T> <N pl="n" gnt="n" gnd="m">[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]o dt\x{ed}<\/S> <T>[Aa]n<\/T> <A pl="n" gnt="n">(?:[Aa]on\x{fa}?|[Oo]cht(?:[\x{f3}\x{fa}]|\x{f3}d\x{fa})?)<\/A>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Gg]o dt\x{ed}<\/S> <T>an<\/T> <N pl="n" gnt="n" gnd="f">(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<C>[Gg]ur<\/C> (?:<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{go}">$1<\/E>/g;
	s/(?<![<>])(<C>[Gg]ur<\/C> (?:<V[^>]*t="caite"[^>]*>(?:(?:d\x{fa}i?r|rai?bh|fuair|fhac|dheach|dhearna)[^<]*|fuarthas)<\/V>))(?![<>])/<E msg="BACHOIR{go}">$1<\/E>/g;
	s/(?<![<>])(<C>[Gg]ur<\/C> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Gg]ur<\/V> <[A-DF-Z][^>]*>[Ff][Hh][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{gurbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Gg]urb<\/V> <[A-DF-Z][^>]*>[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{gur}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Gg]urbh<\/V> <[A-DF-Z][^>]*>(?:[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}fF]|[Ff]h?[lr])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{gur}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Gg]urbh<\/V> <[A-DF-Z][^>]*>[Ff][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> (?:<N[^>]*>n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])[^<]*<\/N>))(?![<>])/<E msg="BACHOIR{in}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> (?:<N[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="BACHOIR{in}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> (?:<N[^>]*>(?:[cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> <[A-DF-Z][^>]*>[Gg]ach<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> <D>[Bb]hur<\/D>)(?![<>])/<E msg="BACHOIR{in bhur}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A>)(?![<>])/<E msg="BACHOIR{in dh\x{e1}}">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Ii]<\/S> (?:<[^\/Y][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[^Y]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ii]<\/S> <R>thart<\/R><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Ii]<\/S> (?:<P[^>]*>[Mm]\x{e9}<\/P>))(?![<>])/<E msg="BACHOIR{ionam}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> (?:<P[^>]*>[Tt]h?\x{fa}<\/P>))(?![<>])/<E msg="BACHOIR{ionat}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> (?:<P[^>]*>[\x{c9}\x{e9}]<\/P>))(?![<>])/<E msg="BACHOIR{ann}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> (?:<P[^>]*>[\x{cd}\x{ed}]<\/P>))(?![<>])/<E msg="BACHOIR{inti}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> (?:<P[^>]*>(?:[Mm]uid|[Ss]inn)<\/P>))(?![<>])/<E msg="BACHOIR{ionainn}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> (?:<P[^>]*>[Ss]ibh<\/P>))(?![<>])/<E msg="BACHOIR{ionaibh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]<\/S> (?:<P[^>]*>[Ii]ad<\/P>))(?![<>])/<E msg="BACHOIR{iontu}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]n?<\/S> <[A-DF-Z][^>]*>[Aa]n<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{sa}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]n?<\/S> <[A-DF-Z][^>]*>[Nn]a<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{sna}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]n?<\/S> <[A-DF-Z][^>]*>a<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{ina}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]n?<\/S> <[A-DF-Z][^>]*>ar<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{inar}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]n?<\/S> <D>\x{e1}r<\/D>)(?![<>])/<E msg="BACHOIR{in\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]n?<\/S> <V cop="y">(?:is|ar|arb)<\/V>)(?![<>])/<E msg="BACHOIR{inar, inarb}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]n?<\/S> <V cop="y">(?:ba|ab|arbh)<\/V>)(?![<>])/<E msg="BACHOIR{inar, inarbh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]n?<\/S> <[A-DF-Z][^>]*>b'[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{inarbh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]dir<\/S> <T>[Aa]n<\/T> <N pl="n" gnt="n" gnd="m">[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]dir<\/S> <T>[Aa]n<\/T> <A pl="n" gnt="n">(?:[Aa]on\x{fa}?|[Oo]cht(?:[\x{f3}\x{fa}]|\x{f3}d\x{fa})?)<\/A>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]dir<\/S> <T>an<\/T> <N pl="n" gnt="n" gnd="f">(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]dir<\/S> (?:<N[^>]*>g?[Cc]am\x{e1}in<\/N>))(?![<>])/<E msg="INPHRASE{idir cham\x{e1}in}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]dir<\/S> <N pl="n" gnt="n" gnd="f">g?[Cc]l\x{e9}ir<\/N>)(?![<>])/<E msg="INPHRASE{idir chl\x{e9}ir agus thuath}">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Ii]n<\/S> <[A-DF-Z][^>]*>[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{i}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ii]n<\/S> <[A-DF-Z][^>]*>n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])[^<]*<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ii]n<\/S> (?:<A[^>]*>(?:[0-9]?[18]|1?8[0-9][0-9][0-9]*)<\/A>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ii]n<\/S> <D>[Bb]hur<\/D><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ii]n<\/S> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Ii]na<\/S> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Ii]na<\/S> (?:<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{inar}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ii]na<\/S> (?:<V[^>]*t="caite"[^>]*>(?:nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Ii]nar<\/S> (?:<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{ina}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]nar<\/S> (?:<V[^>]*t="caite"[^>]*>(?:(?:d\x{fa}i?r|rai?bh|fuair|fhac|dheach|dhearna)[^<]*|fuarthas)<\/V>))(?![<>])/<E msg="BACHOIR{ina}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]nar<\/S> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ii]nar<\/V> <[A-DF-Z][^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{inarb, inarbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ii]nar<\/V> <[A-DF-Z][^>]*>[Ff][Hh][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{inarbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ii]narb<\/V> <[A-DF-Z][^>]*>[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{inar}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ii]narbh<\/V> <[A-DF-Z][^>]*>(?:[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}fF]|[Ff]h?[lr])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{inar}">$1<\/E>/g;
	s/(?<![<>])(<D>[Ii]n\x{e1}r<\/D> <A pl="n" gnt="n">dh\x{e1}<\/A> (?:<N[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<D>[Ii]n\x{e1}r<\/D> <[A-DF-Z][^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Ii]oma\x{ed}<\/A> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Ii]oma\x{ed}<\/A> (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="NOGENITIVE">$1<\/E>/g;
	if (s/(?<![<>])((?:<N[^>]*>[Ii]omarca<\/N>))(?![<>])/<E msg="NEEDART">$1<\/E>/g) {
	s/(<T>[Aa]n<\/T> <E[^>]*>(?:<N[^>]*>[Ii]omarca<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<S>(?:[Dd][eo]n|[Ss]an?|[Ff]aoin|[\x{d3}\x{f3}]n)<\/S> <E[^>]*>(?:<N[^>]*>[Ii]omarca<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Ii]onsar<\/S> <T>an<\/T> (?:<N[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]onsar<\/S> (?:<P[^>]*>[Mm]\x{e9}<\/P>))(?![<>])/<E msg="BACHOIR{ionsorm}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]onsar<\/S> (?:<P[^>]*>[Tt]h?\x{fa}<\/P>))(?![<>])/<E msg="BACHOIR{ionsort}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]onsar<\/S> (?:<P[^>]*>[\x{c9}\x{e9}]<\/P>))(?![<>])/<E msg="BACHOIR{ionsair}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]onsar<\/S> (?:<P[^>]*>[\x{cd}\x{ed}]<\/P>))(?![<>])/<E msg="BACHOIR{ionsuirthi}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]onsar<\/S> (?:<P[^>]*>(?:[Mm]uid|[Ss]inn)<\/P>))(?![<>])/<E msg="BACHOIR{ionsorainn}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]onsar<\/S> (?:<P[^>]*>[Ss]ibh<\/P>))(?![<>])/<E msg="BACHOIR{ionsoraibh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ii]onsar<\/S> (?:<P[^>]*>[Ii]ad<\/P>))(?![<>])/<E msg="BACHOIR{ionsorthu}">$1<\/E>/g;
	if (s/(?<![<>])(<V cop="y">[Ii]s<\/V> (?:<[AN][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[AN]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><V cop="y">[Ii]s<\/V> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Ll]e<\/S> (?:<[^\/Y][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[^Y]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ll]e<\/S> <[A-DF-Z][^>]*>(?:bheith|bhur|chomh|dh\x{e1}|thart|th\x{fa})<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Ll]e<\/S> <T>an<\/T>)(?![<>])/<E msg="BACHOIR{leis an}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]e<\/S> <T>na<\/T>)(?![<>])/<E msg="BACHOIR{leis na}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]e<\/S> <[A-DF-Z][^>]*>a<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{lena}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]e<\/S> <[A-DF-Z][^>]*>ar<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{lenar}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]e<\/S> <[A-DF-Z][^>]*>\x{e1}r<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{len\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]e<\/S> (?:<[ANPY][^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[ANPY]>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]e<\/S> <V cop="y">(?:is|ar|arb)<\/V>)(?![<>])/<E msg="BACHOIR{lenar, lenarb}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]e<\/S> <V cop="y">(?:ba|ab|arbh)<\/V>)(?![<>])/<E msg="BACHOIR{lenar, lenarbh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]e<\/S> <[A-DF-Z][^>]*>b'[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{lenarbh}">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Ll]e<\/S> (?:<P[^>]*>[Mm]\x{e9}<\/P>))(?![<>])/<E msg="BACHOIR{liom}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ll]e<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ll]e<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Ll]e<\/S> (?:<P[^>]*>[Tt]h?\x{fa}<\/P>))(?![<>])/<E msg="BACHOIR{leat}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ll]e<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ll]e<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Ll]e<\/S> <P h="y">h[\x{c9}\x{e9}]<\/P>)(?![<>])/<E msg="BACHOIR{leis}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ll]e<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ll]e<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ll]e<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Ll]e<\/S> <P h="y">h[\x{cd}\x{ed}]<\/P>)(?![<>])/<E msg="BACHOIR{l\x{e9}i}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ll]e<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ll]e<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ll]e<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Ll]e<\/S> (?:<P[^>]*>(?:[Mm]uid|[Ss]inn)<\/P>))(?![<>])/<E msg="BACHOIR{linn}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ll]e<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ll]e<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Ll]e<\/S> (?:<P[^>]*>[Ss]ibh<\/P>))(?![<>])/<E msg="BACHOIR{libh}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ll]e<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ll]e<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Ll]e<\/S> <P h="y">h[Ii]ad<\/P>)(?![<>])/<E msg="BACHOIR{leo}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ll]e<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ll]e<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ll]e<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Ll]eis<\/S> <T>an<\/T> (?:<N[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]eis<\/S> <T>an<\/T> <N pl="n" gnt="n" gnd="m">t(?:[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/N>)(?![<>])/<E msg="NITEE">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]ena<\/S> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Ll]ena<\/S> (?:<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{lenar}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ll]ena<\/S> (?:<V[^>]*t="caite"[^>]*>(?:nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Ll]enar<\/S> (?:<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{lena}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]enar<\/S> (?:<V[^>]*t="caite"[^>]*>(?:(?:d\x{fa}i?r|rai?bh|fuair|fhac|dheach|dhearna)[^<]*|fuarthas)<\/V>))(?![<>])/<E msg="BACHOIR{lena}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ll]enar<\/S> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ll]enar<\/V> <[A-DF-Z][^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{lenarb, lenarbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ll]enar<\/V> <[A-DF-Z][^>]*>[Ff][Hh][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{lenarbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ll]enarb<\/V> <[A-DF-Z][^>]*>[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{lenar}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ll]enarbh<\/V> <[A-DF-Z][^>]*>(?:[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}fF]|[Ff]h?[lr])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{lenar}">$1<\/E>/g;
	s/(?<![<>])(<D>[Ll]en\x{e1}r<\/D> <A pl="n" gnt="n">dh\x{e1}<\/A> (?:<N[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<D>[Ll]en\x{e1}r<\/D> <[A-DF-Z][^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<C>[Mm]\x{e1}<\/C> (?:<V[^>]*t="coinn"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{d\x{e1}}">$1<\/E>/g;
	if (s/(?<![<>])(<C>[Mm]\x{e1}<\/C> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><C>[Mm]\x{e1}<\/C> (?:<V[^>]*t="[flo][^o][^>]*>[Dd](?:eir|\x{e9}ar)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><C>[Mm]\x{e1}<\/C> (?:<V[^>]*>[Tt]\x{e1}(?:i[dm]|imid|thar)?<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><C>[Mm]\x{e1}<\/C> (?:<V[^>]*>[Ff]ua(?:ir(?:ea[md]ar)?|rthas)<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<C>[Mm]\x{e1}<\/C> <V cop="y">(?:is|ar|arb)<\/V>)(?![<>])/<E msg="BACHOIR{m\x{e1}s}">$1<\/E>/g;
	s/(?<![<>])(<S>[Mm]ar<\/S> (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Mm]ar<\/S> <T>[Aa]n<\/T> <N pl="n" gnt="n" gnd="m">[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Mm]ar<\/S> <T>[Aa]n<\/T> <A pl="n" gnt="n">(?:[Aa]on\x{fa}?|[Oo]cht(?:[\x{f3}\x{fa}]|\x{f3}d\x{fa})?)<\/A>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Mm]ar<\/S> <T>an<\/T> <N pl="n" gnt="n" gnd="f">(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<V cop="y">[Mm]\x{e1}s<\/V> (?:<[AN][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[AN]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><V cop="y">[Mm]\x{e1}s<\/V> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Mm]h?\x{e9}ad<\/N>)(?![<>])/<E msg="CAIGHDEAN{m\x{e9}id, mh\x{e9}id}">$1<\/E>/g;
	if (s/(?<![<>])((?:<A[^>]*>measartha<\/A>) (?:<A[^>]*>[^<]+<\/A>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*>(?:<A[^>]*>measartha<\/A>) <A pl="n" gnt="n">[^<]+<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<D>[Mm]o<\/D> <[A-DF-Z][^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{m+uascham\x{f3}g}">$1<\/E>/g;
	s/(?<![<>])(<D>[Mm]o<\/D> <[A-DF-Z][^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Mm]h?\x{f3}rsheisear<\/N> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*><N pl="n" gnt="n" gnd="m">[Mm]h?\x{f3}rsheisear<\/N> <N pl="y" gnt="y" gnd="f">ban<\/N><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Mm]h?\x{f3}rsheisear<\/N> <N pl="n" gnt="n" gnd="f">m?bh?ean<\/N>)(?![<>])/<E msg="BACHOIR{ban}">$1<\/E>/g;
	if (s/(?<![<>])(<C>[Mm]ura<\/C> (?:<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{murar}">$1<\/E>/g) {
	s/(<E[^>]*><C>[Mm]ura<\/C> (?:<V[^>]*t="caite"[^>]*>(?:nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<C>[Mm]ura<\/C> <V cop="y">(?:is|ar|arb)<\/V>)(?![<>])/<E msg="BACHOIR{mura, murab}">$1<\/E>/g;
	s/(?<![<>])(<C>[Mm]ura<\/C> <V cop="y">(?:ba|ab|arbh)<\/V>)(?![<>])/<E msg="BACHOIR{murar, murarbh}">$1<\/E>/g;
	s/(?<![<>])(<C>[Mm]ura<\/C> <[A-DF-Z][^>]*>b'[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{murarbh}">$1<\/E>/g;
	s/(?<![<>])(<C>[Mm]ura<\/C> (?:<V[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Mm]urar?<\/V> <[A-DF-Z][^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{murab, murarbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Mm]urar<\/V> <[A-DF-Z][^>]*>[Ff][Hh][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{murarbh}">$1<\/E>/g;
	if (s/(?<![<>])(<V cop="y">[Mm]ura<\/V> (?:<[AN][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[AN]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><V cop="y">[Mm]ura<\/V> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<V cop="y">[Mm]urab<\/V> <[A-DF-Z][^>]*>[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{mura}">$1<\/E>/g;
	if (s/(?<![<>])(<C>[Mm]urach<\/C> (?:<[^\/Y][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[^Y]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><C>[Mm]urach<\/C> <[A-DF-Z][^>]*>(?:bheith|chomh|th\x{fa})<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Mm]urach<\/S> <T>[Aa]n<\/T> <N pl="n" gnt="n" gnd="m">[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Mm]urach<\/S> <T>[Aa]n<\/T> <A pl="n" gnt="n">(?:[Aa]on\x{fa}?|[Oo]cht(?:[\x{f3}\x{fa}]|\x{f3}d\x{fa})?)<\/A>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Mm]urach<\/S> <T>an<\/T> <N pl="n" gnt="n" gnd="f">(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<C>[Mm]urar<\/C> (?:<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{mura}">$1<\/E>/g;
	s/(?<![<>])(<C>[Mm]urar<\/C> (?:<V[^>]*t="caite"[^>]*>(?:(?:d\x{fa}i?r|rai?bh|fuair|fhac|dheach|dhearna)[^<]*|fuarthas)<\/V>))(?![<>])/<E msg="BACHOIR{mura}">$1<\/E>/g;
	s/(?<![<>])(<C>[Mm]urar<\/C> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Mm]urarbh<\/V> <[A-DF-Z][^>]*>(?:[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}fF]|[Ff]h?[lr])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{murar}">$1<\/E>/g;
	s/(?<![<>])(<T>[Nn]a<\/T> (?:<N[^>]*pl="y" gnt="y"[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<T>[Nn]a<\/T> <N pl="n" gnt="y" gnd="f">[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>)(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<T>[Nn]a<\/T> (?:<N[^>]*pl="n" gnt="y" gnd="m"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="NOGENITIVE">$1<\/E>/g;
	s/(?<![<>])(<T>[Nn]a<\/T> (?:<N[^>]*pl="y" gnt="n"[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<T>[Nn]a<\/T> <Y>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/Y>)(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	if (s/(?<![<>])(<T>[Nn]a<\/T> (?:<[^\/Y][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[^Y]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><T>[Nn]a<\/T> <[A-DF-Z][^>]*>[Cc]h\x{e9}ad<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<T>[Nn]a<\/T> (?:<N[^>]*pl="y" gnt="n"[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>))(?![<>])/<E msg="GENITIVE">$1<\/E>/g;
	if (s/(?<![<>])(<T>[Nn]a<\/T> (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="BACHOIR{an}">$1<\/E>/g) {
	s/(<E[^>]*><T>na<\/T> <N pl="n" gnt="n" gnd="m">Slua<\/N><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><T>na<\/T> <N pl="n" gnt="n" gnd="m">bhF\x{e1}l<\/N><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<T>[Nn]a<\/T> <[A-DF-Z][^>]*>aon<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{an}">$1<\/E>/g;
	s/(?<![<>])(<T>[Nn]a<\/T> <[A-DF-Z][^>]*>[Dd]h?\x{e1}<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{an d\x{e1}}">$1<\/E>/g;
	s/(?<![<>])(<T>[Nn]a<\/T> <[A-DF-Z][^>]*>(?:fiche|tr\x{ed}ocha|daichead|caoga|seasca|seacht\x{f3}|ocht\x{f3}|n\x{f3}cha)<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{an}">$1<\/E>/g;
	s/(?<![<>])(<T>[Nn]a<\/T> <A pl="n" gnt="n">(?:m\x{ed}le|milli\x{fa}n)<\/A>)(?![<>])/<E msg="BACHOIR{an}">$1<\/E>/g;
	s/(?<![<>])(<T>[Nn]a<\/T> <A pl="n" gnt="n">(?:tr\x{ed}|ceithre|c\x{fa}ig|s\x{e9}|seacht|ocht|naoi|deich)<\/A> <[A-DF-Z][^>]*>(?:g?ch?\x{e9}ad|mh?\x{ed}le|mh?illi\x{fa}n)<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{an}">$1<\/E>/g;
	s/(?<![<>])(<T>[Nn]a<\/T> <A pl="n" gnt="n" h="y">hocht<\/A> <[A-DF-Z][^>]*>(?:g?ch?\x{e9}ad|mh?\x{ed}le|mh?illi\x{fa}n)<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{an}">$1<\/E>/g;
	if (s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{e1}<\/[A-DF-Z]> (?:<V[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/V>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g) {
	s/(<E[^>]*><[A-DF-Z][^>]*>[Nn]\x{e1}<\/[A-DF-Z]> <[A-DF-Z][^>]*>is<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><[A-DF-Z][^>]*>[Nn]\x{e1}<\/[A-DF-Z]> <[A-DF-Z][^>]*>at\x{e1}(?:i[dm]|imid|thar)?<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{e1}<\/[A-DF-Z]> (?:<[ANV][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[ANV]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><[A-DF-Z][^>]*>[Nn]\x{e1}<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="f">bheith<\/N><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><[A-DF-Z][^>]*>[Nn]\x{e1}<\/[A-DF-Z]> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Nn]\x{e1}<\/S> <T>[Aa]n<\/T> <N pl="n" gnt="n" gnd="m">[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Nn]\x{e1}<\/S> <T>[Aa]n<\/T> <A pl="n" gnt="n">(?:[Aa]on\x{fa}?|[Oo]cht(?:[\x{f3}\x{fa}]|\x{f3}d\x{fa})?)<\/A>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Nn]\x{e1}<\/S> <T>an<\/T> <N pl="n" gnt="n" gnd="f">(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]ach<\/[A-DF-Z]> (?:<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{n\x{e1}r}">$1<\/E>/g) {
	s/(<E[^>]*><[A-DF-Z][^>]*>[Nn]ach<\/[A-DF-Z]> (?:<V[^>]*t="caite"[^>]*>(?:nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]ach<\/[A-DF-Z]> (?:<V[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	if (s/(?<![<>])(<V cop="y">[Nn]ach<\/V> (?:<[AN][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[AN]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><V cop="y">[Nn]ach<\/V> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])((?:<[^\/Y][^>]*>[Nn]aoi<\/[^Y]>) (?:<N[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])((?:<[^\/Y][^>]*>[Nn]aoi<\/[^Y]>) <N pl="n" gnt="n" gnd="f">m[Bb]liain<\/N>)(?![<>])/<E msg="BACHOIR{mbliana}">$1<\/E>/g;
	s/(?<![<>])((?:<[^\/Y][^>]*>[Nn]aoi<\/[^Y]>) <N pl="n" gnt="n" gnd="m">g[Cc]eann<\/N>)(?![<>])/<E msg="BACHOIR{gcinn}">$1<\/E>/g;
	s/(?<![<>])((?:<[^\/Y][^>]*>[Nn]aoi<\/[^Y]>) <N pl="n" gnt="n" gnd="m">g[Cc]loigeann<\/N>)(?![<>])/<E msg="BACHOIR{gcloigne}">$1<\/E>/g;
	s/(?<![<>])((?:<[^\/Y][^>]*>[Nn]aoi<\/[^Y]>) <N pl="n" gnt="n" gnd="f">g[Cc]uairt<\/N>)(?![<>])/<E msg="BACHOIR{gcuarta}">$1<\/E>/g;
	s/(?<![<>])((?:<[^\/Y][^>]*>[Nn]aoi<\/[^Y]>) <N pl="n" gnt="n" gnd="m">bh[Ff]iche<\/N>)(?![<>])/<E msg="BACHOIR{bhfichid}">$1<\/E>/g;
	s/(?<![<>])((?:<[^\/Y][^>]*>[Nn]aoi<\/[^Y]>) <N pl="n" gnt="n" gnd="f">[Ss]eachtain<\/N>)(?![<>])/<E msg="BACHOIR{seachtaine}">$1<\/E>/g;
	if (s/(?<![<>])((?:<[^\/Y][^>]*>[Nn]aoi<\/[^Y]>) (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*>(?:<[^\/Y][^>]*>[Nn]aoi<\/[^Y]>) (?:<N[^>]*pl="y"[^>]*>(?:mbliana|gcinn|gcloigne|bhfichid|n-uaire)<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])((?:<N[^>]*>Naomh<\/N>) <[A-DF-Z][^>]*>[BCDFGMPST][Hh][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Nn]aon\x{fa}r<\/N> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*><N pl="n" gnt="n" gnd="m">[Nn]aon\x{fa}r<\/N> <N pl="y" gnt="y" gnd="f">ban<\/N><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Nn]aon\x{fa}r<\/N> <N pl="n" gnt="n" gnd="f">m?bh?ean<\/N>)(?![<>])/<E msg="BACHOIR{ban}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{e1}r<\/[A-DF-Z]> (?:<V[^>]*t=".[^a][^s][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{nach}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{e1}r<\/[A-DF-Z]> (?:<V[^>]*t="caite"[^>]*>(?:(?:d\x{fa}i?r|rai?bh|fuair|fhac|dheach|dhearna)[^<]*|fuarthas)<\/V>))(?![<>])/<E msg="BACHOIR{nach}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{e1}r<\/[A-DF-Z]> (?:<[AN][^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/[AN]>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Nn]\x{e1}r<\/V> <[A-DF-Z][^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{n\x{e1}rbh}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{e1}r<\/[A-DF-Z]> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Nn]\x{e1}rbh<\/V> <[A-DF-Z][^>]*>[Ff][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<U>[Nn]\x{ed}<\/U> (?:<V[^>]*t="caite"[^>]*>[Ff]ua(?:ir(?:ea[md]ar)?|rthas)<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	if (s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{ed}<\/[A-DF-Z]> (?:<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{n\x{ed}or}">$1<\/E>/g) {
	s/(<E[^>]*><[A-DF-Z][^>]*>[Nn]\x{ed}<\/[A-DF-Z]> (?:<V[^>]*t="caite"[^>]*>(?:bhfuai?r|d\x{fa}i?r|rai?bh|fhac|dheach|dhearna)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<U>[Nn]\x{ed}<\/U> (?:<V[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><U>[Nn]\x{ed}<\/U> (?:<V[^>]*>bhfaigh[^<]+<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><U>[Nn]\x{ed}<\/U> <V cop="y">ba<\/V><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><U>[Nn]\x{ed}<\/U> (?:<V[^>]*>[Tt]\x{e1}(?:i[dm]|imid|thar)?<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><U>[Nn]\x{ed}<\/U> (?:<V[^>]*t="caite"[^>]*>(?:bhfuai?r|d\x{fa}i?r|rai?bh|fhac|dheach|dhearna)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><U>[Nn]\x{ed}<\/U> (?:<V[^>]*t="[flo][^o][^>]*>[Dd](?:eir|\x{e9}ar)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<V cop="y">[Nn]\x{ed}<\/V> (?:<P[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/P>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	if (s/(?<![<>])(<V cop="y">[Nn]\x{ed}<\/V> (?:<[AN][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[AN]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><V cop="y">[Nn]\x{ed}<\/V> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<R>[Nn]\x{ed}(?: ?ba|b)<\/R>)(?![<>])/<E msg="BREISCHEIM">$1<\/E>/g) {
	s/(<E[^>]*><R>[Nn]\x{ed}(?: ?ba|b)<\/R><\/E> <A pl="n" gnt="y" gnd="f">[^<]+<\/A>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<R>[Nn]\x{ed}ba<\/R> <A pl="n" gnt="y" gnd="f">(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/A>)(?![<>])/<E msg="BACHOIR{n\x{ed}b}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}ba<\/R> <A pl="n" gnt="y" gnd="f">(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/A>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{ed}or<\/[A-DF-Z]> (?:<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{n\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{ed}or<\/[A-DF-Z]> (?:<V[^>]*t="caite"[^>]*>(?:(?:d\x{fa}i?r|rai?bh|fuair|fhac|dheach|dhearna)[^<]*|fuarthas)<\/V>))(?![<>])/<E msg="BACHOIR{n\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{ed}or<\/[A-DF-Z]> (?:<[AN][^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/[AN]>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Nn]\x{ed}or<\/V> <[A-DF-Z][^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{n\x{ed}orbh}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Nn]\x{ed}or<\/[A-DF-Z]> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Nn]\x{ed}orbh<\/V> <[A-DF-Z][^>]*>[Ff][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<R>[Nn]\x{ed}os<\/R>)(?![<>])/<E msg="BREISCHEIM">$1<\/E>/g) {
	s/(<E[^>]*><R>[Nn]\x{ed}os<\/R><\/E> <A pl="n" gnt="y" gnd="f">[^<]+<\/A>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<R>[Nn]\x{ed}os<\/R> <A pl="n" gnt="y" gnd="f">(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/A>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<Y>\x{d3}<\/Y> <Y>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/Y>)(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	if (s/(?<![<>])(<C>[\x{d3}\x{f3}]<\/C> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><C>[\x{d3}\x{f3}]<\/C> (?:<V[^>]*>[Tt]\x{e1}(?:i[dm]|imid|thar)?<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><C>[\x{d3}\x{f3}]<\/C> (?:<V[^>]*>[Ff]ua(?:ir(?:ea[md]ar)?|rthas)<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[\x{d3}\x{f3}]<\/S> (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[\x{d3}\x{f3}]<\/S> <T>an<\/T>)(?![<>])/<E msg="BACHOIR{\x{f3}n}">$1<\/E>/g;
	s/(?<![<>])((?:<[CS][^>]*>[\x{d3}\x{f3}]<\/[CS]>) <V cop="y">is<\/V>)(?![<>])/<E msg="BACHOIR{\x{f3}s}">$1<\/E>/g;
	if (s/(?<![<>])(<S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[Mm]\x{e9}<\/P>))(?![<>])/<E msg="BACHOIR{uaim}">$1<\/E>/g) {
	s/(<E[^>]*><S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[Tt]h?\x{fa}<\/P>))(?![<>])/<E msg="BACHOIR{uait}">$1<\/E>/g) {
	s/(<E[^>]*><S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[\x{c9}\x{e9}]<\/P>))(?![<>])/<E msg="BACHOIR{uaidh}">$1<\/E>/g) {
	s/(<E[^>]*><S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[\x{cd}\x{ed}]<\/P>))(?![<>])/<E msg="BACHOIR{uaithi}">$1<\/E>/g) {
	s/(<E[^>]*><S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>(?:[Mm]uid|[Ss]inn)<\/P>))(?![<>])/<E msg="BACHOIR{uainn}">$1<\/E>/g) {
	s/(<E[^>]*><S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[Ss]ibh<\/P>))(?![<>])/<E msg="BACHOIR{uaibh}">$1<\/E>/g) {
	s/(<E[^>]*><S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[Ii]ad<\/P>))(?![<>])/<E msg="BACHOIR{uathu}">$1<\/E>/g) {
	s/(<E[^>]*><S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[\x{d3}\x{f3}]<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	s/(?<![<>])(<[A-DF-Z][^>]*>h?[Oo]cht<\/[A-DF-Z]> (?:<N[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>h?[Oo]ocht<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="f">m[Bb]liain<\/N>)(?![<>])/<E msg="BACHOIR{mbliana}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>h?[Oo]ocht<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="m">g[Cc]eann<\/N>)(?![<>])/<E msg="BACHOIR{gcinn}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>h?[Oo]ocht<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="m">g[Cc]loigeann<\/N>)(?![<>])/<E msg="BACHOIR{gcloigne}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>h?[Oo]ocht<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="f">g[Cc]uairt<\/N>)(?![<>])/<E msg="BACHOIR{gcuarta}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>h?[Oo]ocht<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="m">bh[Ff]iche<\/N>)(?![<>])/<E msg="BACHOIR{bhfichid}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>h?[Oo]ocht<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="f">[Ss]eachtain<\/N>)(?![<>])/<E msg="BACHOIR{seachtaine}">$1<\/E>/g;
	if (s/(?<![<>])(<[A-DF-Z][^>]*>h?[Oo]cht<\/[A-DF-Z]> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*><[A-DF-Z][^>]*>h?[Oo]cht<\/[A-DF-Z]> (?:<N[^>]*pl="y"[^>]*>(?:mbliana|gcinn|gcloigne|bhfichid|n-uaire)<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Oo]chtar<\/N> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*><N pl="n" gnt="n" gnd="m">[Oo]chtar<\/N> <N pl="y" gnt="y" gnd="f">ban<\/N><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Oo]chtar<\/N> <N pl="n" gnt="n" gnd="f">m?bh?ean<\/N>)(?![<>])/<E msg="BACHOIR{ban}">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*>[Oo]\x{ed}che<\/N>) <N pl="n" gnt="n">D\x{e9} [^<]+<\/N>)(?![<>])/<E msg="NIGA{D\x{e9}}">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*>[Oo]\x{ed}che<\/N>) (?:<N[^>]*>Dh\x{e9}ardaoin<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[\x{d3}\x{f3}]n<\/S> (?:<N[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[\x{d3}\x{f3}]n<\/S> (?:<N[^>]*>(?:n[Dd]|d[Tt]|[DdSsTt][Hh])[^<]+<\/N>))(?![<>])/<E msg="NICLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[\x{d3}\x{f3}]n<\/S> <N pl="n" gnt="n" gnd="f">[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}h][^<]+<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[\x{d3}\x{f3}]n?<\/S> <[A-DF-Z][^>]*>a<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{\x{f3}na}">$1<\/E>/g;
	s/(?<![<>])(<S>[\x{d3}\x{f3}]n?<\/S> <[A-DF-Z][^>]*>ar<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{\x{f3}nar}">$1<\/E>/g;
	s/(?<![<>])(<S>[\x{d3}\x{f3}]n?<\/S> <[A-DF-Z][^>]*>\x{e1}r<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{\x{f3}n\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<S>[\x{d3}\x{f3}]na<\/S> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	if (s/(?<![<>])(<S>[\x{d3}\x{f3}]na<\/S> (?:<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{\x{f3}nar}">$1<\/E>/g) {
	s/(<E[^>]*><S>[\x{d3}\x{f3}]na<\/S> (?:<V[^>]*t="caite"[^>]*>(?:nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[\x{d3}\x{f3}]nar<\/S> (?:<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{\x{f3}na}">$1<\/E>/g;
	s/(?<![<>])(<S>[\x{d3}\x{f3}]nar<\/S> (?:<V[^>]*t="caite"[^>]*>(?:(?:d\x{fa}i?r|rai?bh|fuair|fhac|dheach|dhearna)[^<]*|fuarthas)<\/V>))(?![<>])/<E msg="BACHOIR{\x{f3}na}">$1<\/E>/g;
	s/(?<![<>])(<S>[\x{d3}\x{f3}]nar<\/S> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[\x{d3}\x{f3}]nar<\/V> <[A-DF-Z][^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{\x{f3}narb, \x{f3}narbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[\x{d3}\x{f3}]nar<\/V> <[A-DF-Z][^>]*>[Ff][Hh][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{\x{f3}narbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[\x{d3}\x{f3}]narb<\/V> <[A-DF-Z][^>]*>[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{\x{f3}nar}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[\x{d3}\x{f3}]narbh<\/V> <[A-DF-Z][^>]*>(?:[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}fF]|[Ff]h?[lr])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{\x{f3}nar}">$1<\/E>/g;
	s/(?<![<>])(<D>[\x{d3}\x{f3}]n\x{e1}r<\/D> <A pl="n" gnt="n">dh\x{e1}<\/A> (?:<N[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<D>[\x{d3}\x{f3}]n\x{e1}r<\/D> <[A-DF-Z][^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	if (s/(?<![<>])(<[A-DF-Z][^>]*>[Oo]s<\/[A-DF-Z]> (?:<[^\/Y][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[^Y]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><[A-DF-Z][^>]*>[Oo]s<\/[A-DF-Z]> <[A-DF-Z][^>]*>bhur<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<V cop="y">[\x{d3}\x{f3}]s<\/V> (?:<[AN][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[AN]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><V cop="y">[\x{d3}\x{f3}]s<\/V> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])((?:<P[^>]*>[Pp]\x{e9}<\/P>) (?:<P[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/P>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Pp]h?\x{e9}ire<\/[A-DF-Z]> (?:<N[^>]*gnt="n"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="GENITIVE">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Pp]h?\x{e9}ire<\/[A-DF-Z]> (?:<N[^>]*pl="n"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="IOLRA">$1<\/E>/g;
	if (s/(?<![<>])((?:<A[^>]*>r\x{e9}as\x{fa}nta<\/A>) (?:<A[^>]*>[^<]+<\/A>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*>(?:<A[^>]*>r\x{e9}as\x{fa}nta<\/A>) <A pl="n" gnt="n">[^<]+<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Rr]oimh<\/S> <T>an<\/T> (?:<N[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Rr]oimh<\/S> (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Rr]oimh<\/S> <T>an<\/T> <N pl="n" gnt="n" gnd="m">t(?:[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/N>)(?![<>])/<E msg="NITEE">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Rr]oimh<\/S> (?:<P[^>]*>[Mm]\x{e9}<\/P>))(?![<>])/<E msg="BACHOIR{romham}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Rr]oimh<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Rr]oimh<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Rr]oimh<\/S> (?:<P[^>]*>[Tt]h?\x{fa}<\/P>))(?![<>])/<E msg="BACHOIR{romhat}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Rr]oimh<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Rr]oimh<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Rr]oimh<\/S> (?:<P[^>]*>[\x{c9}\x{e9}]<\/P>))(?![<>])/<E msg="BACHOIR{roimhe}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Rr]oimh<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Rr]oimh<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Rr]oimh<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Rr]oimh<\/S> (?:<P[^>]*>[\x{cd}\x{ed}]<\/P>))(?![<>])/<E msg="BACHOIR{roimpi}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Rr]oimh<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Rr]oimh<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Rr]oimh<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Rr]oimh<\/S> (?:<P[^>]*>(?:[Mm]uid|[Ss]inn)<\/P>))(?![<>])/<E msg="BACHOIR{romhainn}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Rr]oimh<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Rr]oimh<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Rr]oimh<\/S> (?:<P[^>]*>[Ss]ibh<\/P>))(?![<>])/<E msg="BACHOIR{romhaibh}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Rr]oimh<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Rr]oimh<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Rr]oimh<\/S> (?:<P[^>]*>[Ii]ad<\/P>))(?![<>])/<E msg="BACHOIR{rompu}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Rr]oimh<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Rr]oimh<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Rr]oimh<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Ss]a<\/S> <[A-DF-Z][^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{san}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]a<\/S> <[A-DF-Z][^>]*>n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{san}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]a<\/S> <[A-DF-Z][^>]*>(?:80|[0-9]?[18]|1?8[0-9][0-9][0-9]*)\x{fa}<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{san}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]a<\/S> <[A-DF-Z][^>]*>(?:[BbCcFfGgMmPp][^Hh']|bh[fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]a<\/S> (?:<N[^>]*>(?:n[Dd]|d[Tt]|[DdSsTt][Hh])[^<]+<\/N>))(?![<>])/<E msg="NICLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]a<\/S> <N pl="n" gnt="n" gnd="f">[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}h][^<]+<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]a<\/S> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="BACHOIR{sna}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]a<\/S> <A pl="n" gnt="n">(?:thr\x{ed}|cheithre|ch\x{fa}ig|sh\x{e9}|sheacht|naoi|dheich)<\/A>)(?![<>])/<E msg="BACHOIR{sna}">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Ss]a<\/S> <A pl="n" gnt="n" h="y">hocht<\/A>)(?![<>])/<E msg="BACHOIR{sna}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ss]a<\/S> (?:<A[^>]*>[^<]+<\/A>)<\/E> <[A-DF-Z][^>]*>(?:g?ch?\x{e9}ad|mh?\x{ed}le|mh?illi\x{fa}n)<\/[A-DF-Z]>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n">San<\/N> <[A-DF-Z][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]an<\/S> <[A-DF-Z][^>]*>[Ff][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Ss]an<\/S> <[A-DF-Z][^>]*>(?:[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}fF]|[Ff]h?[lr])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{sa}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ss]an<\/S> <[A-DF-Z][^>]*>(?:80|[0-9]?[18]|1?8[0-9][0-9][0-9]*)\x{fa}<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<A pl="n" gnt="n">[Ss]\x{e9}<\/A> <[A-DF-Z][^>]*>uaire?<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{huaire}">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">[Ss]h?\x{e9}<\/A> (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><A pl="n" gnt="n">[Ss]h?\x{e9}<\/A> (?:<N[^>]*>(?:[Bb]liana|[Cc]inn|[Cc]loigne|[Cc]uarta|[Ff]ichid|[Ss]eachtaine)<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<A pl="n" gnt="n">[Ss]h?\x{e9}<\/A> <N pl="n" gnt="n" gnd="f">[Bb]hliain<\/N>)(?![<>])/<E msg="BACHOIR{bliana}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Ss]h?\x{e9}<\/A> <N pl="n" gnt="n" gnd="m">[Cc]heann<\/N>)(?![<>])/<E msg="BACHOIR{cinn}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Ss]h?\x{e9}<\/A> <N pl="n" gnt="n" gnd="m">[Cc]hloigeann<\/N>)(?![<>])/<E msg="BACHOIR{cloigne}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Ss]h?\x{e9}<\/A> <N pl="n" gnt="n" gnd="f">[Cc]huairt<\/N>)(?![<>])/<E msg="BACHOIR{cuarta}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Ss]h?\x{e9}<\/A> <N pl="n" gnt="n" gnd="m">[Ff]hiche<\/N>)(?![<>])/<E msg="BACHOIR{fichid}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Ss]h?\x{e9}<\/A> <N pl="n" gnt="n" gnd="f">[Ss]heachtain<\/N>)(?![<>])/<E msg="BACHOIR{seachtaine}">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">[Ss]h?\x{e9}<\/A> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*><A pl="n" gnt="n">[Ss]h?\x{e9}<\/A> (?:<N[^>]*pl="y"[^>]*>(?:bliana|cinn|cloigne|fichid|huaire)<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Ss]eachas<\/S> (?:<[ANV][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[ANV]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ss]eachas<\/S> <N pl="n" gnt="n" gnd="f">bheith<\/N><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Ss]eachas<\/S> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Ss]eachas<\/S> <T>[Aa]n<\/T> <N pl="n" gnt="n" gnd="m">[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]eachas<\/S> <T>[Aa]n<\/T> <A pl="n" gnt="n">(?:[Aa]on\x{fa}?|[Oo]cht(?:[\x{f3}\x{fa}]|\x{f3}d\x{fa})?)<\/A>)(?![<>])/<E msg="PREFIXT">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]eachas<\/S> <T>an<\/T> <N pl="n" gnt="n" gnd="f">(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>)(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Ss]h?eacht<\/[A-DF-Z]> (?:<N[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Ss]h?eacht<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="f">m[Bb]liain<\/N>)(?![<>])/<E msg="BACHOIR{mbliana}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Ss]h?eacht<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="m">g[Cc]eann<\/N>)(?![<>])/<E msg="BACHOIR{gcinn}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Ss]h?eacht<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="m">g[Cc]loigeann<\/N>)(?![<>])/<E msg="BACHOIR{gcloigne}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Ss]h?eacht<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="f">g[Cc]uairt<\/N>)(?![<>])/<E msg="BACHOIR{gcuarta}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Ss]h?eacht<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="m">bh[Ff]iche<\/N>)(?![<>])/<E msg="BACHOIR{bhfichid}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Ss]h?eacht<\/[A-DF-Z]> <N pl="n" gnt="n" gnd="f">[Ss]eachtain<\/N>)(?![<>])/<E msg="BACHOIR{seachtaine}">$1<\/E>/g;
	if (s/(?<![<>])(<[A-DF-Z][^>]*>[Ss]h?eacht<\/[A-DF-Z]> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*><[A-DF-Z][^>]*>[Ss]h?eacht<\/[A-DF-Z]> (?:<N[^>]*pl="y"[^>]*>(?:mbliana|gcinn|gcloigne|bhfichid|n-uaire)<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Ss]h?eachtar<\/N> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*><N pl="n" gnt="n" gnd="m">[Ss]h?eachtar<\/N> <N pl="y" gnt="y" gnd="f">ban<\/N><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Ss]h?eachtar<\/N> <N pl="n" gnt="n" gnd="f">m?bh?ean<\/N>)(?![<>])/<E msg="BACHOIR{ban}">$1<\/E>/g;
	if (s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Ss]h?eisear<\/N> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*><N pl="n" gnt="n" gnd="m">[Ss]h?eisear<\/N> <N pl="y" gnt="y" gnd="f">ban<\/N><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Ss]h?eisear<\/N> <N pl="n" gnt="n" gnd="f">m?bh?ean<\/N>)(?![<>])/<E msg="BACHOIR{ban}">$1<\/E>/g;
	if (s/(?<![<>])((?:<N[^>]*>[^<]+<\/N>) <A pl="n" gnt="n">(?:[Ss]eo|[Ss]in|[\x{da}\x{fa}]d)<\/A>)(?![<>])/<E msg="NEEDART">$1<\/E>/g) {
	s/(<E[^>]*>(?:<N[^>]*>n?dh?iaidh<\/N>) <A pl="n" gnt="n">(?:[Ss]eo|[Ss]in|[\x{da}\x{fa}]d)<\/A><\/E>)/strip_errors($1);/eg;
	s/((?:<[ADN][^>]*>[^<]+<\/[ADN]>) <E[^>]*>(?:<N[^>]*>[^<]+<\/N>) <A pl="n" gnt="n">(?:[Ss]eo|[Ss]in|[\x{da}\x{fa}]d)<\/A><\/E>)/strip_errors($1);/eg;
	s/(<T>[^<]+<\/T> <E[^>]*>(?:<N[^>]*>[^<]+<\/N>) <A pl="n" gnt="n">(?:[Ss]eo|[Ss]in|[\x{da}\x{fa}]d)<\/A><\/E>)/strip_errors($1);/eg;
	s/(<S>(?:[Dd][eo]n|[Ss]an?|[Ff]aoin|[\x{d3}\x{f3}]n)<\/S> <E[^>]*>(?:<N[^>]*>[^<]+<\/N>) <A pl="n" gnt="n">(?:[Ss]eo|[Ss]in|[\x{da}\x{fa}]d)<\/A><\/E>)/strip_errors($1);/eg;
	s/(<S>[Ss]na<\/S> <E[^>]*>(?:<N[^>]*>[^<]+<\/N>) <A pl="n" gnt="n">(?:[Ss]eo|[Ss]in|[\x{da}\x{fa}]d)<\/A><\/E>)/strip_errors($1);/eg;
	s/(<Q>[Cc]\x{e9}n<\/Q> <E[^>]*>(?:<N[^>]*>[^<]+<\/N>) <A pl="n" gnt="n">(?:[Ss]eo|[Ss]in|[\x{da}\x{fa}]d)<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<N[^>]*>[^<]+<\/N>) (?:<A[^>]*>[^<]+<\/A>) <A pl="n" gnt="n">(?:[Ss]eo|[Ss]in|[\x{da}\x{fa}]d)<\/A>)(?![<>])/<E msg="NEEDART">$1<\/E>/g) {
	s/((?:<[ADN][^>]*>[^<]+<\/[ADN]>) <E[^>]*>(?:<N[^>]*>[^<]+<\/N>) (?:<A[^>]*>[^<]+<\/A>) <A pl="n" gnt="n">(?:[Ss]eo|[Ss]in|[\x{da}\x{fa}]d)<\/A><\/E>)/strip_errors($1);/eg;
	s/(<T>[^<]+<\/T> <E[^>]*>(?:<N[^>]*>[^<]+<\/N>) (?:<A[^>]*>[^<]+<\/A>) <A pl="n" gnt="n">(?:[Ss]eo|[Ss]in|[\x{da}\x{fa}]d)<\/A><\/E>)/strip_errors($1);/eg;
	s/(<S>(?:[Dd][eo]n|[Ss]an?|[Ff]aoin|[\x{d3}\x{f3}]n)<\/S> <E[^>]*>(?:<N[^>]*>[^<]+<\/N>) (?:<A[^>]*>[^<]+<\/A>) <A pl="n" gnt="n">(?:[Ss]eo|[Ss]in|[\x{da}\x{fa}]d)<\/A><\/E>)/strip_errors($1);/eg;
	s/(<S>[Ss]na<\/S> <E[^>]*>(?:<N[^>]*>[^<]+<\/N>) (?:<A[^>]*>[^<]+<\/A>) <A pl="n" gnt="n">(?:[Ss]eo|[Ss]in|[\x{da}\x{fa}]d)<\/A><\/E>)/strip_errors($1);/eg;
	s/(<Q>[Cc]\x{e9}n<\/Q> <E[^>]*>(?:<N[^>]*>[^<]+<\/N>) (?:<A[^>]*>[^<]+<\/A>) <A pl="n" gnt="n">(?:[Ss]eo|[Ss]in|[\x{da}\x{fa}]d)<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])((?:<[^\/V][^>]*>[^<]+<\/[^V]>) (?:<P[^>]*>[Ss]\x{e9}<\/P>))(?![<>])/<E msg="BACHOIR{\x{e9}}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[^<]+<\/V> (?:<P[^>]*>[Ss]\x{e9}<\/P>))(?![<>])/<E msg="BACHOIR{\x{e9}}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*p="n"[^>]*>[^<]+<\/V>) (?:<P[^>]*>[Ss]\x{e9}<\/P>))(?![<>])/<E msg="BACHOIR{\x{e9}}">$1<\/E>/g;
	s/(?<![<>])((?:<[^\/V][^>]*>[^<]+<\/[^V]>) (?:<P[^>]*>[Ss]eisean<\/P>))(?![<>])/<E msg="BACHOIR{eisean}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[^<]+<\/V> (?:<P[^>]*>[Ss]eisean<\/P>))(?![<>])/<E msg="BACHOIR{eisean}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*p="n"[^>]*>[^<]+<\/V>) (?:<P[^>]*>[Ss]eisean<\/P>))(?![<>])/<E msg="BACHOIR{eisean}">$1<\/E>/g;
	s/(?<![<>])((?:<[^\/V][^>]*>[^<]+<\/[^V]>) (?:<P[^>]*>[Ss]\x{ed}<\/P>))(?![<>])/<E msg="BACHOIR{\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[^<]+<\/V> (?:<P[^>]*>[Ss]\x{ed}<\/P>))(?![<>])/<E msg="BACHOIR{\x{ed}}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*p="n"[^>]*>[^<]+<\/V>) (?:<P[^>]*>[Ss]\x{ed}<\/P>))(?![<>])/<E msg="BACHOIR{\x{ed}}">$1<\/E>/g;
	s/(?<![<>])((?:<[^\/V][^>]*>[^<]+<\/[^V]>) (?:<P[^>]*>[Ss]ise<\/P>))(?![<>])/<E msg="BACHOIR{ise}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[^<]+<\/V> (?:<P[^>]*>[Ss]ise<\/P>))(?![<>])/<E msg="BACHOIR{ise}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*p="n"[^>]*>[^<]+<\/V>) (?:<P[^>]*>[Ss]ise<\/P>))(?![<>])/<E msg="BACHOIR{ise}">$1<\/E>/g;
	s/(?<![<>])((?:<[^\/V][^>]*>[^<]+<\/[^V]>) (?:<P[^>]*>[Ss]iad<\/P>))(?![<>])/<E msg="BACHOIR{iad}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[^<]+<\/V> (?:<P[^>]*>[Ss]iad<\/P>))(?![<>])/<E msg="BACHOIR{iad}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*p="n"[^>]*>[^<]+<\/V>) (?:<P[^>]*>[Ss]iad<\/P>))(?![<>])/<E msg="BACHOIR{iad}">$1<\/E>/g;
	s/(?<![<>])((?:<[^\/V][^>]*>[^<]+<\/[^V]>) (?:<P[^>]*>[Ss]iadsan<\/P>))(?![<>])/<E msg="BACHOIR{iadsan}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[^<]+<\/V> (?:<P[^>]*>[Ss]iadsan<\/P>))(?![<>])/<E msg="BACHOIR{iadsan}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*p="n"[^>]*>[^<]+<\/V>) (?:<P[^>]*>[Ss]iadsan<\/P>))(?![<>])/<E msg="BACHOIR{iadsan}">$1<\/E>/g;
	if (s/(?<![<>])((?:<N[^>]*>Sile<\/N>))(?![<>])/<E msg="IONADAI{S\x{ed}le}">$1<\/E>/g) {
	s/(<T>na<\/T> <E[^>]*>(?:<N[^>]*>Sile<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Ss]na<\/S> (?:<N[^>]*pl="y" gnt="n"[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/N>))(?![<>])/<E msg="PREFIXH">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]na<\/S> (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="BACHOIR{sa, san}">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Ss]na<\/S> (?:<[^\/Y][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[^Y]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><S>[Ss]na<\/S> <[A-DF-Z][^>]*>[Cc]h\x{e9}ad<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Ss]na<\/S> <[A-DF-Z][^>]*>h?aon<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{san aon}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]na<\/S> <[A-DF-Z][^>]*>[Dd]h?\x{e1}<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{sa d\x{e1}}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]na<\/S> <[A-DF-Z][^>]*>(?:fh?iche|h?ocht\x{f3})<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{san}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]na<\/S> <[A-DF-Z][^>]*>(?:tr\x{ed}ocha|daichead|caoga|seasca|seacht\x{f3}|n\x{f3}cha)<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{sa}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]na<\/S> <A pl="n" gnt="n">(?:m\x{ed}le|milli\x{fa}n)<\/A>)(?![<>])/<E msg="BACHOIR{sa}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]na<\/S> <A pl="n" gnt="n">(?:tr\x{ed}|ceithre|c\x{fa}ig|s\x{e9}|seacht|ocht|naoi|deich)<\/A> <[A-DF-Z][^>]*>(?:g?ch?\x{e9}ad|mh?\x{ed}le|mh?illi\x{fa}n)<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{sa}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]na<\/S> <A pl="n" gnt="n" h="y">hocht<\/A> <[A-DF-Z][^>]*>(?:g?ch?\x{e9}ad|mh?\x{ed}le|mh?illi\x{fa}n)<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{sa}">$1<\/E>/g;
	if (s/(?<![<>])(<C>[Ss]ula<\/C> (?:<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{sular}">$1<\/E>/g) {
	s/(<E[^>]*><C>[Ss]ula<\/C> (?:<V[^>]*t="caite"[^>]*>(?:nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<C>[Ss]ula<\/C> <V cop="y">(?:is|ar|arb)<\/V>)(?![<>])/<E msg="BACHOIR{sular, sularb}">$1<\/E>/g;
	s/(?<![<>])(<C>[Ss]ula<\/C> <V cop="y">(?:ba|ab|arbh)<\/V>)(?![<>])/<E msg="BACHOIR{sular, sularbh}">$1<\/E>/g;
	s/(?<![<>])(<C>[Ss]ula<\/C> <[A-DF-Z][^>]*>b'[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{sularbh}">$1<\/E>/g;
	s/(?<![<>])(<C>[Ss]ula<\/C> <[A-DF-Z][^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<C>[Ss]ular<\/C> (?:<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{sula}">$1<\/E>/g;
	s/(?<![<>])(<C>[Ss]ular<\/C> (?:<V[^>]*t="caite"[^>]*>(?:(?:d\x{fa}i?r|rai?bh|fuair|fhac|dheach|dhearna)[^<]*|fuarthas)<\/V>))(?![<>])/<E msg="BACHOIR{sula}">$1<\/E>/g;
	s/(?<![<>])(<C>[Ss]ular<\/C> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ss]ular<\/V> <[A-DF-Z][^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{sularb, sularbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ss]ular<\/V> <[A-DF-Z][^>]*>[Ff][Hh][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{sularbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ss]ularb<\/V> <[A-DF-Z][^>]*>[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{sular}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ss]ularbh<\/V> <[A-DF-Z][^>]*>(?:[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}fF]|[Ff]h?[lr])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{sular}">$1<\/E>/g;
	if (s/(?<![<>])((?:<P[^>]*>[Tt]\x{e9}<\/P>))(?![<>])/<E msg="NEEDART">$1<\/E>/g) {
	s/(<T>[Aa]n<\/T> <E[^>]*>(?:<P[^>]*>[Tt]\x{e9}<\/P>)<\/E>)/strip_errors($1);/eg;
	s/(<S>(?:[Dd][eo]n|[Ss]an?|[Ff]aoin|[\x{d3}\x{f3}]n)<\/S> <E[^>]*>(?:<P[^>]*>[Tt]\x{e9}<\/P>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<[A-DF-Z][^>]*>[Tt]har<\/[A-DF-Z]> <T>an<\/T> (?:<N[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> <T>an<\/T> <N pl="n" gnt="n" gnd="m">t(?:[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/N>)(?![<>])/<E msg="NITEE">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> <[A-DF-Z][^>]*>[Mm]h?aoi?l<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{thar maoil}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="WEAKSEIMHIU{thar}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> (?:<P[^>]*>[Mm]\x{e9}<\/P>))(?![<>])/<E msg="BACHOIR{tharam}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> (?:<P[^>]*>[Tt]h?\x{fa}<\/P>))(?![<>])/<E msg="BACHOIR{tharat}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> (?:<P[^>]*>[\x{c9}\x{e9}]<\/P>))(?![<>])/<E msg="BACHOIR{thairis}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> (?:<P[^>]*>[\x{cd}\x{ed}]<\/P>))(?![<>])/<E msg="BACHOIR{thairsti}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> (?:<P[^>]*>(?:[Mm]uid|[Ss]inn)<\/P>))(?![<>])/<E msg="BACHOIR{tharainn}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> (?:<P[^>]*>[Ss]ibh<\/P>))(?![<>])/<E msg="BACHOIR{tharaibh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> (?:<P[^>]*>[Ii]ad<\/P>))(?![<>])/<E msg="BACHOIR{tharstu}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Tt]r\x{ed}<\/[A-DF-Z]> <[A-DF-Z][^>]*>uaire?<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{huaire}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> <[A-DF-Z][^>]*>a<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{tr\x{ed}na}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> <[A-DF-Z][^>]*>ar<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{tr\x{ed}nar}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> <T>an<\/T>)(?![<>])/<E msg="BACHOIR{tr\x{ed}d an}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> <D>\x{e1}r<\/D>)(?![<>])/<E msg="BACHOIR{tr\x{ed}n\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> <V cop="y">(?:is|ar|arb)<\/V>)(?![<>])/<E msg="BACHOIR{tr\x{ed}nar, tr\x{ed}narb}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> <V cop="y">(?:ba|ab|arbh)<\/V>)(?![<>])/<E msg="BACHOIR{tr\x{ed}nar, tr\x{ed}narbh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> <[A-DF-Z][^>]*>b'[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{tr\x{ed}narbh}">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[Mm]\x{e9}<\/P>))(?![<>])/<E msg="BACHOIR{tr\x{ed}om}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[Tt]h?\x{fa}<\/P>))(?![<>])/<E msg="BACHOIR{tr\x{ed}ot}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[\x{c9}\x{e9}]<\/P>))(?![<>])/<E msg="BACHOIR{tr\x{ed}d}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[\x{cd}\x{ed}]<\/P>))(?![<>])/<E msg="BACHOIR{tr\x{ed}thi}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>(?:[Mm]uid|[Ss]inn)<\/P>))(?![<>])/<E msg="BACHOIR{tr\x{ed}nn}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[Ss]ibh<\/P>))(?![<>])/<E msg="BACHOIR{tr\x{ed}bh}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[Ii]ad<\/P>))(?![<>])/<E msg="BACHOIR{tr\x{ed}othu}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <R>[Ff]\x{e9}in<\/R> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	s/(<E[^>]*><S>[Tt]r\x{ed}<\/S> (?:<P[^>]*>[^<]+<\/P>)<\/E> <[A-DF-Z][^>]*>(?:seo|sin|si\x{fa}d)<\/[A-DF-Z]> (?:<[DS][^>]*>[Aa]<\/[DS]>) (?:<N[^>]*pl="n" gnt="n"[^>]*>[^<]+<\/N>))/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<[A-DF-Z][^>]*>d?[Tt]h?r\x{ed}<\/[A-DF-Z]> (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*><[A-DF-Z][^>]*>d?[Tt]h?r\x{ed}<\/[A-DF-Z]> (?:<N[^>]*>(?:[Bb]liana|[Cc]inn|[Cc]loigne|[Cc]uarta|[Ff]ichid|[Ss]eachtaine)<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Tt]r\x{ed}d<\/S> <T>an<\/T> (?:<N[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}d<\/S> <T>na<\/T>)(?![<>])/<E msg="BACHOIR{tr\x{ed} na}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}d<\/S> <T>an<\/T> <N pl="n" gnt="n" gnd="m">t(?:[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/N>)(?![<>])/<E msg="NITEE">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}na<\/S> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/V>))(?![<>])/<E msg="URU">$1<\/E>/g;
	if (s/(?<![<>])(<S>[Tt]r\x{ed}na<\/S> (?:<V[^>]*t="caite"[^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{tr\x{ed}nar}">$1<\/E>/g) {
	s/(<E[^>]*><S>[Tt]r\x{ed}na<\/S> (?:<V[^>]*t="caite"[^>]*>(?:nd\x{fa}i?r|rai?bh|bhfuai?r|bhfac|ndeach|ndearna)[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Tt]r\x{ed}nar<\/S> (?:<V[^>]*t=".[^a][^>]*>[^<]+<\/V>))(?![<>])/<E msg="BACHOIR{tr\x{ed}na}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}nar<\/S> (?:<V[^>]*t="caite"[^>]*>(?:(?:d\x{fa}i?r|rai?bh|fuair|fhac|dheach|dhearna)[^<]*|fuarthas)<\/V>))(?![<>])/<E msg="BACHOIR{tr\x{ed}na}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]r\x{ed}nar<\/S> (?:<V[^>]*(?: p=.y|t=..[^a])[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/V>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Tt]r\x{ed}nar<\/V> <[A-DF-Z][^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{tr\x{ed}narb, tr\x{ed}narbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Tt]r\x{ed}nar<\/V> <[A-DF-Z][^>]*>[Ff][Hh][aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}][^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{tr\x{ed}narbh}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Tt]r\x{ed}narb<\/V> <[A-DF-Z][^>]*>[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{tr\x{ed}nar}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Tt]r\x{ed}narbh<\/V> <[A-DF-Z][^>]*>(?:[^aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}fF]|[Ff]h?[lr])[^<]+<\/[A-DF-Z]>)(?![<>])/<E msg="BACHOIR{tr\x{ed}nar}">$1<\/E>/g;
	s/(?<![<>])(<D>[Tt]r\x{ed}n\x{e1}r<\/D> <A pl="n" gnt="n">dh\x{e1}<\/A> (?:<N[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/N>))(?![<>])/<E msg="URU">$1<\/E>/g;
	s/(?<![<>])(<D>[Tt]r\x{ed}n\x{e1}r<\/D> <[A-DF-Z][^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}cfptCFPT]|[Dd][^Tt']|[Gg][^Cc]|[Bb][^Pph]|[Bb]h[^fF])[^<]*<\/[A-DF-Z]>)(?![<>])/<E msg="URU">$1<\/E>/g;
	if (s/(?<![<>])(<N pl="n" gnt="n" gnd="m">d?[Tt]h?ri\x{fa}r<\/N> (?:<N[^>]*pl="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<E[^>]*><N pl="n" gnt="n" gnd="m">d?[Tt]h?ri\x{fa}r<\/N> <N pl="y" gnt="y" gnd="f">ban<\/N><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">d?[Tt]h?ri\x{fa}r<\/N> <N pl="n" gnt="n" gnd="f">m?bh?ean<\/N>)(?![<>])/<E msg="BACHOIR{ban}">$1<\/E>/g;
	s/(?<![<>])(<T>[Aa]n<\/T> <A pl="n" gnt="n">[Uu]ile<\/A> (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Gg]ach<\/A> <A pl="n" gnt="n">[Uu]ile<\/A> (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>(?:[Dd][eo]n|[Ss]an?|[Ff]aoin|[\x{d3}\x{f3}]n)<\/S> <A pl="n" gnt="n">[Uu]ile<\/A> (?:<N[^>]*>(?:[BbCcDdFfGgMmPpTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">[Uu]ile<\/A>)(?![<>])/<E msg="NEEDART">$1<\/E>/g) {
	s/(<T>[Aa]n<\/T> <E[^>]*><A pl="n" gnt="n">[Uu]ile<\/A><\/E>)/strip_errors($1);/eg;
	s/(<S>(?:[Dd][eo]n|[Ss]an?|[Ff]aoin|[\x{d3}\x{f3}]n)<\/S> <E[^>]*><A pl="n" gnt="n">[Uu]ile<\/A><\/E>)/strip_errors($1);/eg;
	s/(<S>i ngach<\/S> <E[^>]*><A pl="n" gnt="n">[Uu]ile<\/A><\/E>)/strip_errors($1);/eg;
	s/((?:<[AN][^>]*>[^<]+<\/[AN]>) <E[^>]*><A pl="n" gnt="n">[Uu]ile<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Uu]m<\/S> (?:<N[^>]*>(?:[CcDdFfGgTt][^Hh']|[Ss][lnraeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|bh[Ff])[^<]*<\/N>))(?![<>])/<E msg="SEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Uu]m<\/S> (?:<N[^>]*>(?:[MmPp][Hh]|[Bb][Hh][^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g;
	s/(?<![<>])(<S>[Uu]m<\/S> <T>an<\/T> (?:<N[^>]*>[BbCcFfGgPp][^hcCpP'][^<]*<\/N>))(?![<>])/<E msg="CLAOCHLU">$1<\/E>/g;
	s/(?<![<>])(<S>[Uu]m<\/S> <T>an<\/T> <N pl="n" gnt="n" gnd="m">t(?:[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/N>)(?![<>])/<E msg="NITEE">$1<\/E>/g;
	s/(?<![<>])(<S>[Uu]m<\/S> (?:<P[^>]*>[Mm]\x{e9}<\/P>))(?![<>])/<E msg="BACHOIR{umam}">$1<\/E>/g;
	s/(?<![<>])(<S>[Uu]m<\/S> (?:<P[^>]*>[Tt]h?\x{fa}<\/P>))(?![<>])/<E msg="BACHOIR{umat}">$1<\/E>/g;
	s/(?<![<>])(<S>[Uu]m<\/S> (?:<P[^>]*>[\x{c9}\x{e9}]<\/P>))(?![<>])/<E msg="BACHOIR{uime}">$1<\/E>/g;
	s/(?<![<>])(<S>[Uu]m<\/S> (?:<P[^>]*>[\x{cd}\x{ed}]<\/P>))(?![<>])/<E msg="BACHOIR{uimpi}">$1<\/E>/g;
	s/(?<![<>])(<S>[Uu]m<\/S> (?:<P[^>]*>(?:[Mm]uid|[Ss]inn)<\/P>))(?![<>])/<E msg="BACHOIR{umainn}">$1<\/E>/g;
	s/(?<![<>])(<S>[Uu]m<\/S> (?:<P[^>]*>[Ss]ibh<\/P>))(?![<>])/<E msg="BACHOIR{umaibh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Uu]m<\/S> (?:<P[^>]*>[Ii]ad<\/P>))(?![<>])/<E msg="BACHOIR{umpu}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+[^e]ann<\/V>) (?:<P[^>]*>m\x{e9}<\/P>))(?![<>])/<E msg="SYNTHETIC{-aim}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+eann<\/V>) (?:<P[^>]*>m\x{e9}<\/P>))(?![<>])/<E msg="SYNTHETIC{-im}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+a\x{ed}onn<\/V>) (?:<P[^>]*>m\x{e9}<\/P>))(?![<>])/<E msg="SYNTHETIC{-a\x{ed}m}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+[^a]\x{ed}onn<\/V>) (?:<P[^>]*>m\x{e9}<\/P>))(?![<>])/<E msg="SYNTHETIC{-\x{ed}m}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+[^e]ann<\/V>) (?:<P[^>]*>sinn<\/P>))(?![<>])/<E msg="SYNTHETIC{-aimid}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+eann<\/V>) (?:<P[^>]*>sinn<\/P>))(?![<>])/<E msg="SYNTHETIC{-imid}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+a\x{ed}onn<\/V>) (?:<P[^>]*>sinn<\/P>))(?![<>])/<E msg="SYNTHETIC{-a\x{ed}mid}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+[^a]\x{ed}onn<\/V>) (?:<P[^>]*>sinn<\/P>))(?![<>])/<E msg="SYNTHETIC{-\x{ed}mid}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+faidh<\/V>) (?:<P[^>]*>sinn<\/P>))(?![<>])/<E msg="SYNTHETIC{-faimid}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+fidh<\/V>) (?:<P[^>]*>sinn<\/P>))(?![<>])/<E msg="SYNTHETIC{-fimid}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+\x{f3}idh<\/V>) (?:<P[^>]*>sinn<\/P>))(?![<>])/<E msg="SYNTHETIC{-\x{f3}imid}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+eoidh<\/V>) (?:<P[^>]*>sinn<\/P>))(?![<>])/<E msg="SYNTHETIC{-eoimid}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+fadh<\/V>) (?:<P[^>]*>m\x{e9}<\/P>))(?![<>])/<E msg="SYNTHETIC{-fainn}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+feadh<\/V>) (?:<P[^>]*>m\x{e9}<\/P>))(?![<>])/<E msg="SYNTHETIC{-finn}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+\x{f3}dh<\/V>) (?:<P[^>]*>m\x{e9}<\/P>))(?![<>])/<E msg="SYNTHETIC{-\x{f3}inn}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+eodh<\/V>) (?:<P[^>]*>m\x{e9}<\/P>))(?![<>])/<E msg="SYNTHETIC{-eoinn}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+fadh<\/V>) (?:<P[^>]*>t\x{fa}<\/P>))(?![<>])/<E msg="SYNTHETIC{-f\x{e1}}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+feadh<\/V>) (?:<P[^>]*>t\x{fa}<\/P>))(?![<>])/<E msg="SYNTHETIC{-fe\x{e1}}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+\x{f3}dh<\/V>) (?:<P[^>]*>t\x{fa}<\/P>))(?![<>])/<E msg="SYNTHETIC{-\x{f3}f\x{e1}}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+eodh<\/V>) (?:<P[^>]*>t\x{fa}<\/P>))(?![<>])/<E msg="SYNTHETIC{-eof\x{e1}}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+fadh<\/V>) (?:<P[^>]*>sinn<\/P>))(?![<>])/<E msg="SYNTHETIC{-faimis}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+feadh<\/V>) (?:<P[^>]*>sinn<\/P>))(?![<>])/<E msg="SYNTHETIC{-fimis}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+\x{f3}dh<\/V>) (?:<P[^>]*>sinn<\/P>))(?![<>])/<E msg="SYNTHETIC{-\x{f3}imis}">$1<\/E>/g;
	s/(?<![<>])((?:<V[^>]*>[^<]+eodh<\/V>) (?:<P[^>]*>sinn<\/P>))(?![<>])/<E msg="SYNTHETIC{-eoimis}">$1<\/E>/g;
	s/(?<![<>])(<N pl="y" gnt="d">g?[Cc]h?ianaibh<\/N>)(?![<>])/<E msg="INPHRASE{\x{f3} chianaibh}">$1<\/E>/g;
	s/(?<![<>])(<N pl="y" gnt="d">[Uu]airibh<\/N>)(?![<>])/<E msg="INPHRASE{ar uairibh}">$1<\/E>/g;
	if (s/(?<![<>])((?:<N[^>]*gnt="d"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="NODATIVE">$1<\/E>/g) {
	s/(<E[^>]*>(?:<N[^>]*gnt="d"[^>]*>(?:[Cc]h?ois|[Ll]\x{e1}imh)<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<N[^>]*gnt="d"[^>]*>[Cc]ionn<\/N>)<\/E> <V cop="y">is<\/V>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<N[^>]*gnt="d"[^>]*>d'[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<S>(?:[Dd][eo]n|[Ss]an?|[Ff]aoin|[\x{d3}\x{f3}]n)<\/S> <E[^>]*>(?:<N[^>]*gnt="d"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<S>(?:[Aa][grs]|[Cc]huig|[Dd][eo]|[Ff]aoi|[Gg]an|[Gg]o|[Ll]e|[\x{d3}\x{f3}]|[Ii]n?|[Rr]oimh|[Tt]har|[Tt]r\x{ed}d?|[Uu]m)<\/S> <E[^>]*>(?:<N[^>]*gnt="d"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<S>(?:[Aa][grs]|[Cc]huig|[Dd][eo]|[Ff]aoi|[Gg]an|[Gg]o|[Ll]e|[\x{d3}\x{f3}]|[Ii]n?|[Rr]oimh|[Tt]har|[Tt]r\x{ed}d?|[Uu]m)<\/S> <D>[^<]+<\/D> <E[^>]*>(?:<N[^>]*gnt="d"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<S>(?:[Aa][rs]|[Ll]eis)<\/S> <T>[^<]+<\/T> <E[^>]*>(?:<N[^>]*gnt="d"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<D>(?:[Dd]\x{e1}r?|(?:[Ff]aoi|[Ii]|[Ll]e|[Tt]r\x{ed})n(?:a|\x{e1}r))<\/D> <E[^>]*>(?:<N[^>]*gnt="d"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<A pl="n" gnt="n">[Dd]h\x{e1}<\/A> <E[^>]*>(?:<N[^>]*gnt="d"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<T>[Aa]n<\/T> <[A-DF-Z][^>]*>[Dd]\x{e1}<\/[A-DF-Z]> <E[^>]*>(?:<N[^>]*gnt="d"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<[^\/ACDNRTY][^>]*>[^<]+<\/[^ACDNRTY]>) (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="NOGENITIVE">$1<\/E>/g) {
	s/(<E[^>]*><V cop="y">is<\/V> (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><S>[^< ]+ [^<]+<\/S> (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><S>(?:[Cc]hun|[Cc]ois|[Dd]\x{e1}la|[Ff]earacht|[Tt]impeall|[Tt]rasna)<\/S> (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<P[^>]*>p\x{e9}<\/P>) (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<S>[^< ]+<\/S> <T>[^<]+<\/T> (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="NOGENITIVE">$1<\/E>/g) {
	s/(<E[^>]*><S>(?:[Cc]hun|[Cc]ois|[Dd]\x{e1}la|[Ff]earacht|[Tt]impeall|[Tt]rasna)<\/S> <T>[^<]+<\/T> (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<[^\/ACNRSY][^>]*>[^<]+<\/[^ACNRSY]>) <T>[^<]+<\/T> (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="NOGENITIVE">$1<\/E>/g) {
	s/(<E[^>]*><V cop="y">is<\/V> <T>[^<]+<\/T> (?:<N[^>]*gnt="y"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])((?:<N[^>]*>nd\x{f3}ighe?<\/N>))(?![<>])/<E msg="INPHRASE{ar nd\x{f3}igh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> <N pl="n" gnt="n" gnd="f">n-ais<\/N>)(?![<>])/<E msg="CAIGHDEAN{ar ais}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">d'\x{e1}r<\/N>)(?![<>])/<E msg="CAIGHDEAN{d\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])(<C>[Mm]ar<\/C> <[A-DF-Z][^>]*>[Aa]<\/[A-DF-Z]> (?:<N[^>]*>gc\x{e9}anna<\/N>))(?![<>])/<E msg="CAIGHDEAN{mar an gc\x{e9}anna}">$1<\/E>/g;
	if (s/(?<![<>])((?:<N[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>))(?![<>])/<E msg="NIURU">$1<\/E>/g) {
	s/(<E[^>]*>(?:<N[^>]*>mb'[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<S>(?:[Aa][grs]|[Cc]huig|[Dd][eo]|[Ff]aoi|[Gg]an|[Gg]o|[Ll]e|[\x{d3}\x{f3}]|[Ii]n?|[Rr]oimh|[Tt]har|[Tt]r\x{ed}d?|[Uu]m)<\/S> <T>[Aa]n<\/T> <E[^>]*>(?:<N[^>]*pl="n" gnt="[nd]"[^>]*>(?:g[Cc]|b[Pp]|m[Bb]|n[Gg]|bh[fF])[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<S>[Ll]eis<\/S> <T>[Aa]n<\/T> <E[^>]*>(?:<N[^>]*pl="n" gnt="[nd]"[^>]*>(?:g[Cc]|b[Pp]|m[Bb]|n[Gg]|bh[fF])[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<S>(?:[Dd][eo]n|[Ss]an?|[Ff]aoin|[\x{d3}\x{f3}]n)<\/S> <E[^>]*>(?:<N[^>]*pl="n" gnt="[nd]"[^>]*>(?:g[Cc]|b[Pp]|m[Bb]|n[Gg]|bh[fF])[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<T>[Nn]a<\/T> <E[^>]*>(?:<N[^>]*pl="y" gnt="y"[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<T>na<\/T> <E[^>]*><N pl="n" gnt="n" gnd="m">bhF\x{e1}l<\/N><\/E>)/strip_errors($1);/eg;
	s/(<S>[Ii]<\/S> <E[^>]*>(?:<N[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>(?:[Cc]\x{e1}|[Gg]o)<\/[A-DF-Z]> <E[^>]*><N pl="n" gnt="n" gnd="m">bh[Ff]ios<\/N><\/E>)/strip_errors($1);/eg;
	s/(<D>(?:[Aa]|[\x{c1}\x{e1}]r|[Bb]hur)<\/D> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A> <E[^>]*>(?:<N[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>(?:n?[Dd]h?eich|[Nn]aoi|(?:h|[mbd]')?[Oo]cht|[Ss]h?eacht|[0-9]*[789]|[0-9]*10)<\/[A-DF-Z]> <E[^>]*>(?:<N[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<A pl="n" gnt="n">[Aa] [Ss]eacht<\/A> <E[^>]*>(?:<N[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<A pl="n" gnt="n">[Aa] h[Oo]cht<\/A> <E[^>]*>(?:<N[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<A pl="n" gnt="n">[Aa] [Nn]aoi<\/A> <E[^>]*>(?:<N[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<D>(?:(?:[Ff]aoin|[Ii]n|[Ll]en|[\x{d3}\x{f3}]n|[Tt]r\x{ed}n)?(?:[Aa]|\x{e1}r)|[Dd]?[\x{c1}\x{e1}]r?|[Bb]hur|[Aa]rna)<\/D> <E[^>]*>(?:<N[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<S>[Uu]m<\/S> <T>an<\/T> <E[^>]*>(?:<N[^>]*>dtaca<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>[Mm]ar<\/[A-DF-Z]> <T>an<\/T> <E[^>]*>(?:<N[^>]*>gc\x{e9}anna<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<V[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/V>))(?![<>])/<E msg="NIURU">$1<\/E>/g) {
	s/(<U>[Cc]ha<\/U> <E[^>]*>(?:<V[^>]*>(?:d[Tt]|n[Dd])[^<]+<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<U>(?:[Aa]|[Nn]ach)<\/U> <E[^>]*>(?:<V[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<H>[Aa]<\/H> <E[^>]*>(?:<V[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<Q>(?:[Aa]n|[Cc]\x{e1})<\/Q> <E[^>]*>(?:<V[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<C>(?:[Dd]\x{e1}|[Gg]o|[Mm]ura|[Ss]ula)<\/C> <E[^>]*>(?:<V[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<S>(?:faoi|i|le|\x{f3}|tr\x{ed})na<\/S> <E[^>]*>(?:<V[^>]*>(?:n(?:-[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}]|[AEIOU\x{c1}\x{c9}\x{cd}\x{d3}\x{da}])|d[Tt]|g[Cc]|b[Pp]|m[Bb]|n[DdGg]|bh[fF])[^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<U>[Nn]\x{ed}<\/U> <E[^>]*>(?:<V[^>]*>bh[Ff]ua(?:ir(?:ea[md]ar)?|rthas)<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<U>[Nn]\x{ed}<\/U> <E[^>]*>(?:<V[^>]*>bhfaigh[^<]+<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<A pl="n" gnt="n" h="y">[^<]+<\/A>)(?![<>])/<E msg="NIAITCH">$1<\/E>/g) {
	s/(<T>[Nn]a<\/T> <E[^>]*><A pl="n" gnt="n" h="y">(?:haon|hocht)<\/A><\/E>)/strip_errors($1);/eg;
	s/(<S>(?:[Ll]e|[Ss]na)<\/S> <E[^>]*><A pl="n" gnt="n" h="y">(?:haon|hocht)<\/A><\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>[Aa]<\/[A-DF-Z]> <E[^>]*><A pl="n" gnt="n" h="y">(?:h[Aa]on|h[Oo]cht)<\/A><\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>[Cc]homh<\/[A-DF-Z]> <E[^>]*><A pl="n" gnt="n" h="y">[^<]+<\/A><\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> <E[^>]*><A pl="n" gnt="n" h="y">[^<]+<\/A><\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>[Nn]\x{ed}<\/[A-DF-Z]> <E[^>]*><A pl="n" gnt="n" h="y">hionann<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<P[^>]*h="y"[^>]*>[^<]+<\/P>))(?![<>])/<E msg="NIAITCH">$1<\/E>/g) {
	s/(<[A-DF-Z][^>]*>(?:[Cc]\x{e9}|[Nn]\x{ed}|[Ll]e|[Pp]\x{e9})<\/[A-DF-Z]> <E[^>]*>(?:<P[^>]*h="y"[^>]*>[^<]+<\/P>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<N[^>]*h="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="NIAITCH">$1<\/E>/g) {
	s/(<D>[^<]*[A\x{c1}a\x{e1}]<\/D> <E[^>]*>(?:<N[^>]*h="y"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<V cop="y">[Cc]\x{e1}<\/V> <E[^>]*>(?:<N[^>]*h="y"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>g?[Cc]h?eithre<\/[A-DF-Z]> <E[^>]*>(?:<N[^>]*h="y"[^>]*>hairde<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>[Dd]ara<\/[A-DF-Z]> <E[^>]*>(?:<N[^>]*h="y"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/((?:<A[^>]*>(?:[^<][^<]*[^m]|[0-9]+)\x{fa}<\/A>) <E[^>]*>(?:<N[^>]*h="y"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>a<\/[A-DF-Z]> <A pl="n" gnt="n">[Dd]h\x{e1}<\/A> <E[^>]*>(?:<N[^>]*h="y"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> <E[^>]*>(?:<N[^>]*h="y"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<S>[Ss]na<\/S> <E[^>]*>(?:<N[^>]*pl="y" .+ h="y"[^>]*>[^<]+<\/N>|<B><Z>(?:<N[^>]*pl="y" .+ h="y"[^>]*>)+<\/Z>[^<]+<\/B>)<\/E>)/strip_errors($1);/eg;
	s/(<S>[Ll]e<\/S> <E[^>]*>(?:<N[^>]*h="y"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<T>[Nn]a<\/T> <E[^>]*>(?:<N[^>]*h="y"[^>]*>[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>(?:d?[tT]h?r\x{ed}|g?[Cc]h?eithre|[Ss]h?\x{e9})<\/[A-DF-Z]> <E[^>]*>(?:<N[^>]*h="y"[^>]*>huaire<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<V[^>]*t="[flo][^o][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/V>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<[A-DF-Z][^>]*>(?:[Mm]\x{e1}|[Nn]\x{ed}|[\x{d3}\x{f3}])<\/[A-DF-Z]> <E[^>]*>(?:<V[^>]*t="[flo][^o][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>[Aa]<\/[A-DF-Z]> <E[^>]*>(?:<V[^>]*t="[flo][^o][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<U>[Cc]ha<\/U> <E[^>]*>(?:<V[^>]*t="[flo][^o][^>]*>(?:[CcFfGgMmPpSs][Hh]|[Bb]h[^fF])[^<]+<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<C>[\x{d3}\x{f3}]<\/C> <E[^>]*>(?:<V[^>]*t="[flo][^o][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<V[^>]*t="[flo][^o][^>]*>[Gg]heo[^<]+<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<C>(?:[Gg]ur|[Mm]urar|[Ss]ular)<\/C> (?:<V[^>]*t="caite"[^>]*>(?:rinne[^<]*|chonai?c[^<]*|chua(?:igh|[md]ar|thas)|bh\x{ed}(?:o[md]ar|othas)?)<\/V>))(?![<>])/<E msg="RELATIVE">$1<\/E>/g;
	s/(?<![<>])(<S>(?:d\x{e1}r|(?:faoi|i|le|\x{f3}|tr\x{ed})nar)<\/S> (?:<V[^>]*t="caite"[^>]*>(?:rinne[^<]*|chonai?c[^<]*|chua(?:igh|[md]ar|thas)|bh\x{ed}(?:o[md]ar|othas)?)<\/V>))(?![<>])/<E msg="RELATIVE">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>(?:[Aa]r|[Cc]\x{e1}r|[Nn]\x{e1}r|[Nn]\x{ed}or)<\/[A-DF-Z]> (?:<V[^>]*t="caite"[^>]*>(?:rinne[^<]*|chonai?c[^<]*|chua(?:igh|[md]ar|thas)|bh\x{ed}(?:o[md]ar|othas)?)<\/V>))(?![<>])/<E msg="RELATIVE">$1<\/E>/g;
	s/(?<![<>])(<C>(?:[Gg]o|[Mm]ura|[Ss]ula)<\/C> (?:<V[^>]*>(?:n?gh?eo[bf][^<]+|d'\x{ed}osf[^<]+|t\x{e1}(?:im|imid|thar)?)<\/V>))(?![<>])/<E msg="RELATIVE">$1<\/E>/g;
	s/(?<![<>])(<S>(?:faoi|i|le|\x{f3}|tr\x{ed})na<\/S> (?:<V[^>]*>(?:n?gh?eo[bf][^<]+|d'\x{ed}osf[^<]+|t\x{e1}(?:im|imid|thar)?)<\/V>))(?![<>])/<E msg="RELATIVE">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>(?:[Aa]n|[Cc]\x{e1}|[Dd]\x{e1}|[Nn]ach|[Nn]\x{ed})<\/[A-DF-Z]> (?:<V[^>]*>(?:n?gh?eo[bf][^<]+|d'\x{ed}osf[^<]+|t\x{e1}(?:im|imid|thar)?)<\/V>))(?![<>])/<E msg="RELATIVE">$1<\/E>/g;
	if (s/(?<![<>])((?:<V[^>]*>(?:rai?bh(?:a[md]ar|thas)?|bhfuil(?:im|imid|tear)?|n?dh?each(?:aigh|a[md]ar|thas)|\x{ed}osf[a\x{e1}][^<]+|(?:bhf|fh)ac(?:a|a[dm]ar|thas)|(?:bhf|fh)aigh(?:idh|fear|inn|fe\x{e1}|eadh|imis|id\x{ed}s|f\x{ed})|n?dh?earn[^<]+)<\/V>))(?![<>])/<E msg="ABSOLUTE">$1<\/E>/g) {
	s/(<C>(?:[Gg]o|[Mm]ura|[Ss]ula)<\/C> <E[^>]*>(?:<V[^>]*>(?:rai?bh(?:a[md]ar|thas)?|bhfuil(?:im|imid|tear)?|n?dh?each(?:aigh|a[md]ar|thas)|\x{ed}osf[a\x{e1}][^<]+|(?:bhf|fh)ac(?:a|a[dm]ar|thas)|(?:bhf|fh)aigh(?:idh|fear|inn|fe\x{e1}|eadh|imis|id\x{ed}s|f\x{ed})|n?dh?earn[^<]+)<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<S>(?:faoi|i|le|\x{f3}|tr\x{ed})na<\/S> <E[^>]*>(?:<V[^>]*>(?:rai?bh(?:a[md]ar|thas)?|bhfuil(?:im|imid|tear)?|n?dh?each(?:aigh|a[md]ar|thas)|\x{ed}osf[a\x{e1}][^<]+|(?:bhf|fh)ac(?:a|a[dm]ar|thas)|(?:bhf|fh)aigh(?:idh|fear|inn|fe\x{e1}|eadh|imis|id\x{ed}s|f\x{ed})|n?dh?earn[^<]+)<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>(?:[Aa]|[Aa]n|[Cc]\x{e1}|[Cc]ha|[Cc]han|[Dd]\x{e1}|[Nn]ach|[Nn]\x{ed})<\/[A-DF-Z]> <E[^>]*>(?:<V[^>]*>(?:rai?bh(?:a[md]ar|thas)?|bhfuil(?:im|imid|tear)?|n?dh?each(?:aigh|a[md]ar|thas)|\x{ed}osf[a\x{e1}][^<]+|(?:bhf|fh)ac(?:a|a[dm]ar|thas)|(?:bhf|fh)aigh(?:idh|fear|inn|fe\x{e1}|eadh|imis|id\x{ed}s|f\x{ed})|n?dh?earn[^<]+)<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<V[^>]*t="(?:caite|gn\x{e1}th|coinn)"[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/V>))(?![<>])/<E msg="PREFIXD">$1<\/E>/g) {
	s/(<E[^>]*><V p="n" t="caite">(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/V><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<V[^>]*t="caite"[^>]*>[Aa]rsa<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*>(?:<V[^>]*t="caite"[^>]*>[Ff]ua(?:ir(?:ea[md]ar)?|rthas)<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<C>(?:[Gg]ur|[Mm]urar|[Ss]ular)<\/C> <E[^>]*>(?:<V[^>]*t="(?:caite|gn\x{e1}th|coinn)"[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<S>(?:d\x{e1}r|(?:faoi|i|le|\x{f3}|tr\x{ed})nar)<\/S> <E[^>]*>(?:<V[^>]*t="(?:caite|gn\x{e1}th|coinn)"[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>(?:[Aa]r|[Cc]\x{e1}r|[Cc]har|[Nn]\x{e1}r|[Nn]\x{ed}or)<\/[A-DF-Z]> <E[^>]*>(?:<V[^>]*t="(?:caite|gn\x{e1}th|coinn)"[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>[Aa]n<\/[A-DF-Z]> <E[^>]*>(?:<V[^>]*t="(?:caite|gn\x{e1}th|coinn)"[^>]*>[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}][^<]*<\/V>)<\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>[Nn]\x{ed}<\/[A-DF-Z]> <E[^>]*>(?:<V[^>]*t="(?:caite|gn\x{e1}th|coinn)"[^>]*>(?:[aeiouAEIOU\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{c1}\x{c9}\x{cd}\x{d3}\x{da}]|[Ff]h?[aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}])[^<]+<\/V>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<C>(?:[Gg]ur|[Mm]urar|[Ss]ular)<\/C> (?:<V[^>]*t="(?:caite|gn\x{e1}th|coinn)"[^>]*>d'[^<]+<\/V>))(?![<>])/<E msg="NIDEE">$1<\/E>/g;
	s/(?<![<>])(<S>(?:d\x{e1}r|(?:faoi|i|le|\x{f3}|tr\x{ed})nar)<\/S> (?:<V[^>]*t="(?:caite|gn\x{e1}th|coinn)"[^>]*>d'[^<]+<\/V>))(?![<>])/<E msg="NIDEE">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>(?:[Aa]r|[Cc]\x{e1}r|[Cc]har|[Nn]\x{e1}r|[Nn]\x{ed}or)<\/[A-DF-Z]> (?:<V[^>]*t="(?:caite|gn\x{e1}th|coinn)"[^>]*>d'[^<]+<\/V>))(?![<>])/<E msg="NIDEE">$1<\/E>/g;
	s/(?<![<>])(<C>(?:[Gg]o|[Mm]ura|[Ss]ula)<\/C> (?:<V[^>]*t="(?:caite|gn\x{e1}th|coinn)"[^>]*>INTIALDAPOST<\/V>))(?![<>])/<E msg="NIDEE">$1<\/E>/g;
	s/(?<![<>])(<S>(?:faoi|i|le|\x{f3}|tr\x{ed})na<\/S> (?:<V[^>]*t="(?:caite|gn\x{e1}th|coinn)"[^>]*>INTIALDAPOST<\/V>))(?![<>])/<E msg="NIDEE">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>(?:[Aa]n|[Cc]\x{e1}|[Dd]\x{e1}|[Nn]ach|[Nn]\x{ed})<\/[A-DF-Z]> (?:<V[^>]*t="(?:caite|gn\x{e1}th|coinn)"[^>]*>INTIALDAPOST<\/V>))(?![<>])/<E msg="NIDEE">$1<\/E>/g;
	if (s/(?<![<>])(<T>[Aa]n<\/T> (?:<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/N>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<S>(?:[Aa][grs]|[Cc]huig|[Ll]eis|[Rr]oimh|[Tt]har|[Tt]r\x{ed}d|[Uu]m)<\/S> <E[^>]*><T>[Aa]n<\/T> (?:<N[^>]*pl="n" gnt="n" gnd="m"[^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/N>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])((?:<[GH][^>]*>[Aa]<\/[GH]>) (?:<[^\/V][^>]*>[^<]+<\/[^V]>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<T>[^<]+<\/T> <A pl="n" gnt="y" gnd="f">[^<]+<\/A>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<T>[^<]+<\/T> <A pl="y" gnt="n">[^<]+<\/A>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	if (s/(?<![<>])(<T>[^<]+<\/T> (?:<[^\/AFNXY][^>]*>[^<]+<\/[^AFNXY]>))(?![<>])/<E msg="CUPLA">$1<\/E>/g) {
	s/(<E[^>]*><T>[Nn]a<\/T> <T>NA<\/T><\/E>)/strip_errors($1);/eg;
	s/(<E[^>]*><T>[Aa]n<\/T> (?:<P[^>]*>[Tt]\x{e9}<\/P>)<\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<R>[^<]+<\/R> <A pl="y" gnt="n">[^<]+<\/A>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<Q>[^<]+<\/Q> <A pl="n" gnt="y" gnd="f">[^<]+<\/A>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<Q>[^<]+<\/Q> <A pl="y" gnt="n">[^<]+<\/A>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<Q>[^<]+<\/Q> <Q>[^<]+<\/Q>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<Q>[^<]+<\/Q> (?:<N[^>]*pl="n" gnt="y"[^>]*>[^<]+<\/N>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])((?:<P[^>]*>[^<]+<\/P>) <A pl="y" gnt="n">[^<]+<\/A>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])((?:<P[^>]*>[^<]+<\/P>) <A pl="n" gnt="y" gnd="f">(?:[^b]|b[^'])[^<]+<\/A>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])((?:<O[^>]*>[^<]+<\/O>) <A pl="y" gnt="n">[^<]+<\/A>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])((?:<O[^>]*>[^<]+<\/O>) <A pl="n" gnt="y" gnd="f">[^<]+<\/A>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*pl="n" gnt="y" gnd="m"[^>]*>[^<]+<\/N>) <A pl="n" gnt="y" gnd="f">[^<]+<\/A>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*pl="n" gnt="y" gnd="f"[^>]*>[^<]+<\/N>) <A pl="n" gnt="y" gnd="m">[^<]+<\/A>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	if (s/(?<![<>])((?:<N[^>]*pl="y" gnt="y"[^>]*>[^<]*[a\x{e1}o\x{f3}u\x{fa}][^aeiou\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}<]+<\/N>) <A pl="y" gnt="n">[^<]+<\/A>)(?![<>])/<E msg="UATHA">$1<\/E>/g) {
	s/(<N pl="n" gnt="n" gnd="f">m?[Bb]h?eirt<\/N> <E[^>]*><N pl="y" gnt="y" gnd="f">[Bb]han<\/N> <A pl="y" gnt="n">[^<]+<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<D>[^<]+<\/D> <A pl="y" gnt="n">[^<]+<\/A>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<D>[^<]+<\/D> <C>[^<]+<\/C>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<D>[^<]+<\/D> <D>[^<]+<\/D>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<D>[^<]+<\/D> (?:<O[^>]*>[^<]+<\/O>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<D>[^<]+<\/D> (?:<P[^>]*>[^<]+<\/P>))(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<D>[^<]+<\/D> <Q>[^<]+<\/Q>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<D>[^<]+<\/D> <T>[^<]+<\/T>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<A pl="y" gnt="n">[^<]+<\/A> <A pl="n" gnt="y" gnd="f">(?:[^b]|b[^'])[^<]+<\/A>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="y" gnd="f">[^<]+<\/A> <A pl="y" gnt="n">[^<]+<\/A>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[^<]+<\/A> <A pl="n" gnt="y" gnd="f">[^<]+<\/A>)(?![<>])/<E msg="CUPLA">$1<\/E>/g;
	if (s/(?<![<>])((?:<V[^>]* p="."[^>]*>[^<]+<\/V>) (?:<[AN][^>]*>(?:[CcDdFfGgMmPpSsTt][Hh]|[Bb]h[^fF])[^<]+<\/[AN]>))(?![<>])/<E msg="NISEIMHIU">$1<\/E>/g) {
	s/(<E[^>]*>(?:<V[^>]* p="."[^>]*>[^<]+<\/V>) <[A-DF-Z][^>]*>(?:[Dd]h\x{e1}|[Ff]hios)<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<R>[Nn]\x{ed}os<\/R> <A pl="n" gnt="y" gnd="f">bh?ige<\/A>)(?![<>])/<E msg="BACHOIR{l\x{fa}}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> <A pl="n" gnt="y" gnd="f">bh?ige<\/A>)(?![<>])/<E msg="BACHOIR{l\x{fa}}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ii]s<\/V> <A pl="n" gnt="y" gnd="f">bh?ige<\/A>)(?![<>])/<E msg="BACHOIR{l\x{fa}}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}os<\/R> <A pl="n" gnt="y" gnd="f">dh?\x{f3}cha<\/A>)(?![<>])/<E msg="BACHOIR{d\x{f3}ich\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> <A pl="n" gnt="y" gnd="f">dh?\x{f3}cha<\/A>)(?![<>])/<E msg="BACHOIR{d\x{f3}ich\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}os<\/R> <A pl="n" gnt="y" gnd="f">fh?ada<\/A>)(?![<>])/<E msg="BACHOIR{faide}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> <A pl="n" gnt="y" gnd="f">fh?ada<\/A>)(?![<>])/<E msg="BACHOIR{faide}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}os<\/R> <A pl="n" gnt="y" gnd="f">fh?urasta<\/A>)(?![<>])/<E msg="BACHOIR{fusa}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> <A pl="n" gnt="y" gnd="f">fh?urasta<\/A>)(?![<>])/<E msg="BACHOIR{fusa}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}os<\/R> <A pl="n" gnt="y" gnd="f">ioma\x{ed}<\/A>)(?![<>])/<E msg="BACHOIR{lia}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> <A pl="n" gnt="y" gnd="f">ioma\x{ed}<\/A>)(?![<>])/<E msg="BACHOIR{lia}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}os<\/R> <A pl="n" gnt="y" gnd="f">mh?aithe<\/A>)(?![<>])/<E msg="BACHOIR{fearr}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> <A pl="n" gnt="y" gnd="f">mh?aithe<\/A>)(?![<>])/<E msg="BACHOIR{fearr}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ii]s<\/V> <A pl="n" gnt="y" gnd="f">mh?aithe<\/A>)(?![<>])/<E msg="BACHOIR{fearr}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}os<\/R> <A pl="n" gnt="y" gnd="f">mh?\x{f3}ire<\/A>)(?![<>])/<E msg="BACHOIR{m\x{f3}}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> <A pl="n" gnt="y" gnd="f">mh?\x{f3}ire<\/A>)(?![<>])/<E msg="BACHOIR{m\x{f3}}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ii]s<\/V> <A pl="n" gnt="y" gnd="f">mh?\x{f3}ire<\/A>)(?![<>])/<E msg="BACHOIR{m\x{f3}}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}os<\/R> <A pl="n" gnt="y" gnd="f">oilce<\/A>)(?![<>])/<E msg="BACHOIR{measa}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> <A pl="n" gnt="y" gnd="f">oilce<\/A>)(?![<>])/<E msg="BACHOIR{measa}">$1<\/E>/g;
	s/(?<![<>])(<V cop="y">[Ii]s<\/V> <A pl="n" gnt="y" gnd="f">oilce<\/A>)(?![<>])/<E msg="BACHOIR{measa}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}os<\/R> <A pl="n" gnt="y" gnd="f">th?e<\/A>)(?![<>])/<E msg="BACHOIR{teo}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> <A pl="n" gnt="y" gnd="f">th?e<\/A>)(?![<>])/<E msg="BACHOIR{teo}">$1<\/E>/g;
	if (s/(?<![<>])(<N pl="n" gnt="n">[\x{c1}\x{e1}]il<\/N>)(?![<>])/<E msg="INPHRASE{is \x{e1}il}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><N pl="n" gnt="n">[\x{c1}\x{e1}]il<\/N><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<N pl="n" gnt="n" gnd="f">[Aa]ithnid<\/N>)(?![<>])/<E msg="INPHRASE{is aithnid}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><N pl="n" gnt="n" gnd="f">[Aa]ithnid<\/N><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<N pl="n" gnt="n">[Cc]h?uimhin<\/N>)(?![<>])/<E msg="INPHRASE{is cuimhin}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><N pl="n" gnt="n">[Cc]h?uimhin<\/N><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]h?\x{e9}ana\x{ed}<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{is d\x{e9}ana\x{ed}, le d\x{e9}ana\x{ed}}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><[A-DF-Z][^>]*>[Dd]h?\x{e9}ana\x{ed}<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<A[^>]*>[Dd]h?\x{f3}cha<\/A>))(?![<>])/<E msg="INPHRASE{is d\x{f3}cha}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*>(?:<A[^>]*>[Dd]h?\x{f3}cha<\/A>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<[A-DF-Z][^>]*>[Dd]h?ual<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{is dual}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><[A-DF-Z][^>]*>[Dd]h?ual<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<P[^>]*>h?ea<\/P>))(?![<>])/<E msg="INPHRASE{is ea, n\x{ed} hea}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*>(?:<P[^>]*>h?ea<\/P>)<\/E>)/strip_errors($1);/eg;
	s/(<Q>[Cc]\x{e9}<\/Q> <E[^>]*>(?:<P[^>]*>ea<\/P>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<A pl="n" gnt="n">[Ee]agal<\/A>)(?![<>])/<E msg="INPHRASE{is eagal}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><A pl="n" gnt="n">[Ee]agal<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<P[^>]*>\x{e9}ard<\/P>))(?![<>])/<E msg="INPHRASE{is \x{e9}ard}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*>(?:<P[^>]*>\x{e9}ard<\/P>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<N pl="n" gnt="n">[Ee]ol<\/N>)(?![<>])/<E msg="INPHRASE{is eol}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><N pl="n" gnt="n">[Ee]ol<\/N><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<N pl="n" gnt="n">[Ff]h?\x{e9}idir<\/N>)(?![<>])/<E msg="INPHRASE{is f\x{e9}idir}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><N pl="n" gnt="n">[Ff]h?\x{e9}idir<\/N><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<A pl="n" gnt="n">[Ff]h?ol\x{e1}ir<\/A>)(?![<>])/<E msg="INPHRASE{n\x{ed} fol\x{e1}ir}">$1<\/E>/g) {
	s/(<V cop="y">[Nn][^<]+<\/V> <E[^>]*><A pl="n" gnt="n">[Ff]h?ol\x{e1}ir<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<A[^>]*>[Ii]oma\x{ed}<\/A>))(?![<>])/<E msg="INPHRASE{is ioma\x{ed}}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*>(?:<A[^>]*>[Ii]oma\x{ed}<\/A>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<A pl="n" gnt="n">[Ii]onann<\/A>)(?![<>])/<E msg="INPHRASE{is ionann}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><A pl="n" gnt="n">[Ii]onann<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<A[^>]*>[Ll]\x{e9}ir<\/A>))(?![<>])/<E msg="INPHRASE{is l\x{e9}ir}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*>(?:<A[^>]*>[Ll]\x{e9}ir<\/A>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<A pl="n" gnt="n">[Ll]eor<\/A>)(?![<>])/<E msg="INPHRASE{is leor, go leor}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><A pl="n" gnt="n">[Ll]eor<\/A><\/E>)/strip_errors($1);/eg;
	s/(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> <E[^>]*><A pl="n" gnt="n">leor<\/A><\/E>)/strip_errors($1);/eg;
	s/(<A pl="n" gnt="n">[Ll]eor<\/A> <E[^>]*><A pl="n" gnt="n">leor<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<A pl="n" gnt="n">[Mm]h?iste<\/A>)(?![<>])/<E msg="INPHRASE{is miste, n\x{ed} miste}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><A pl="n" gnt="n">[Mm]h?iste<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<[A-DF-Z][^>]*>[Mm]h?ithid<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{is mithid}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><[A-DF-Z][^>]*>[Mm]h?ithid<\/[A-DF-Z]><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])((?:<A[^>]*>[Nn]\x{e1}ir<\/A>))(?![<>])/<E msg="INPHRASE{is n\x{e1}ir}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*>(?:<A[^>]*>[Nn]\x{e1}ir<\/A>)<\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<N pl="n" gnt="n">[Oo]th<\/N>)(?![<>])/<E msg="INPHRASE{is oth}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><N pl="n" gnt="n">[Oo]th<\/N><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<A pl="n" gnt="y" gnd="f">[Aa]nsa<\/A>)(?![<>])/<E msg="INPHRASE{n\x{ed}os ansa, is ansa}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><A pl="n" gnt="y" gnd="f">[Aa]nsa<\/A><\/E>)/strip_errors($1);/eg;
	s/(<R>[Nn]\x{ed}os<\/R> <E[^>]*><A pl="n" gnt="y" gnd="f">[Aa]nsa<\/A><\/E>)/strip_errors($1);/eg;
	s/(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> <E[^>]*><A pl="n" gnt="y" gnd="f">[Aa]nsa<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<A pl="n" gnt="y" gnd="f">[Dd]h?\x{f3}ich\x{ed}<\/A>)(?![<>])/<E msg="INPHRASE{n\x{ed}os d\x{f3}ich\x{ed}, is d\x{f3}ich\x{ed}}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><A pl="n" gnt="y" gnd="f">[Dd]h?\x{f3}ich\x{ed}<\/A><\/E>)/strip_errors($1);/eg;
	s/(<R>[Nn]\x{ed}os<\/R> <E[^>]*><A pl="n" gnt="y" gnd="f">[Dd]h?\x{f3}ich\x{ed}<\/A><\/E>)/strip_errors($1);/eg;
	s/(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> <E[^>]*><A pl="n" gnt="y" gnd="f">[Dd]h?\x{f3}ich\x{ed}<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<A pl="n" gnt="y" gnd="f">[Ff]h?aide<\/A>)(?![<>])/<E msg="INPHRASE{n\x{ed}os faide, is faide}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><A pl="n" gnt="y" gnd="f">[Ff]h?aide<\/A><\/E>)/strip_errors($1);/eg;
	s/(<R>[Nn]\x{ed}os<\/R> <E[^>]*><A pl="n" gnt="y" gnd="f">[Ff]h?aide<\/A><\/E>)/strip_errors($1);/eg;
	s/(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> <E[^>]*><A pl="n" gnt="y" gnd="f">[Ff]h?aide<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<A pl="n" gnt="y" gnd="f">[Ff]h?earr<\/A>)(?![<>])/<E msg="INPHRASE{n\x{ed}os fearr, is fearr}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><A pl="n" gnt="y" gnd="f">[Ff]h?earr<\/A><\/E>)/strip_errors($1);/eg;
	s/(<R>[Nn]\x{ed}os<\/R> <E[^>]*><A pl="n" gnt="y" gnd="f">[Ff]h?earr<\/A><\/E>)/strip_errors($1);/eg;
	s/(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> <E[^>]*><A pl="n" gnt="y" gnd="f">[Ff]h?earr<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<A pl="n" gnt="y" gnd="f">[Ff]h?usa<\/A>)(?![<>])/<E msg="INPHRASE{n\x{ed}os fusa, is fusa}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><A pl="n" gnt="y" gnd="f">[Ff]h?usa<\/A><\/E>)/strip_errors($1);/eg;
	s/(<R>[Nn]\x{ed}os<\/R> <E[^>]*><A pl="n" gnt="y" gnd="f">[Ff]h?usa<\/A><\/E>)/strip_errors($1);/eg;
	s/(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> <E[^>]*><A pl="n" gnt="y" gnd="f">[Ff]h?usa<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<A pl="n" gnt="y" gnd="f">[Ll]\x{fa}<\/A>)(?![<>])/<E msg="INPHRASE{n\x{ed}os l\x{fa}, is l\x{fa}}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><A pl="n" gnt="y" gnd="f">[Ll]\x{fa}<\/A><\/E>)/strip_errors($1);/eg;
	s/(<R>[Nn]\x{ed}os<\/R> <E[^>]*><A pl="n" gnt="y" gnd="f">[Ll]\x{fa}<\/A><\/E>)/strip_errors($1);/eg;
	s/(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> <E[^>]*><A pl="n" gnt="y" gnd="f">[Ll]\x{fa}<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<A pl="n" gnt="y" gnd="f">[Mm]h?\x{f3}<\/A>)(?![<>])/<E msg="INPHRASE{n\x{ed}os m\x{f3}, is m\x{f3}}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><A pl="n" gnt="y" gnd="f">[Mm]h?\x{f3}<\/A><\/E>)/strip_errors($1);/eg;
	s/(<R>[Nn]\x{ed}os<\/R> <E[^>]*><A pl="n" gnt="y" gnd="f">[Mm]h?\x{f3}<\/A><\/E>)/strip_errors($1);/eg;
	s/(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> <E[^>]*><A pl="n" gnt="y" gnd="f">[Mm]h?\x{f3}<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<A pl="n" gnt="y" gnd="f">[Tt]h?\x{fa}isce<\/A>)(?![<>])/<E msg="INPHRASE{n\x{ed}os t\x{fa}isce, is t\x{fa}isce}">$1<\/E>/g) {
	s/(<V cop="y">[^<]+<\/V> <E[^>]*><A pl="n" gnt="y" gnd="f">[Tt]h?\x{fa}isce<\/A><\/E>)/strip_errors($1);/eg;
	s/(<R>[Nn]\x{ed}os<\/R> <E[^>]*><A pl="n" gnt="y" gnd="f">[Tt]h?\x{fa}isce<\/A><\/E>)/strip_errors($1);/eg;
	s/(<R>[Nn]\x{ed}(?: ?ba|b)<\/R> <E[^>]*><A pl="n" gnt="y" gnd="f">[Tt]h?\x{fa}isce<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Bb]hallchrith<\/N>)(?![<>])/<E msg="INPHRASE{ar ballchrith}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">[Bb]h\x{ed}s<\/N>)(?![<>])/<E msg="INPHRASE{ar b\x{ed}s}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">[Bb]huile<\/N>)(?![<>])/<E msg="INPHRASE{ar buile}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Cc]heal<\/N>)(?![<>])/<E msg="INPHRASE{ar ceal}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Cc]h\x{e9}alacan<\/N>)(?![<>])/<E msg="INPHRASE{ar c\x{e9}alacan}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Cc]heant<\/N>)(?![<>])/<E msg="INPHRASE{ar ceant}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="d">[Cc]heathr\x{fa}in<\/N>)(?![<>])/<E msg="INPHRASE{ar ceathr\x{fa}in}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Cc]h\x{ed}os<\/N>)(?![<>])/<E msg="INPHRASE{ar c\x{ed}os}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="y" gnt="n" gnd="m">[Cc]hip\x{ed}n\x{ed}<\/N>)(?![<>])/<E msg="INPHRASE{ar cip\x{ed}n\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">[Cc]h\x{f3}imh\x{e9}id<\/N>)(?![<>])/<E msg="INPHRASE{ar c\x{f3}imh\x{e9}id}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">[Cc]homhbhr\x{ed}<\/N>)(?![<>])/<E msg="INPHRASE{ar comhbhr\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Cc]homhfhad<\/N>)(?![<>])/<E msg="INPHRASE{ar comhfhad}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Cc]homhsc\x{f3}r<\/N>)(?![<>])/<E msg="INPHRASE{ar comhsc\x{f3}r}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Cc]hrith<\/N>)(?![<>])/<E msg="INPHRASE{ar crith}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Cc]hrochadh<\/N>)(?![<>])/<E msg="INPHRASE{ar crochadh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">[Dd]h\x{e1}ir<\/N>)(?![<>])/<E msg="INPHRASE{ar d\x{e1}ir}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">[Dd]heic<\/N>)(?![<>])/<E msg="INPHRASE{ar deic}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">[Dd]heil<\/N>)(?![<>])/<E msg="INPHRASE{ar deil}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Dd]heiseal<\/N>)(?![<>])/<E msg="INPHRASE{ar deiseal}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">[Dd]heora\x{ed}ocht<\/N>)(?![<>])/<E msg="INPHRASE{ar deora\x{ed}ocht}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Dd]hi\x{fa}it\x{e9}<\/N>)(?![<>])/<E msg="INPHRASE{ar di\x{fa}it\x{e9}}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">[Ff]h\x{e1}il<\/N>)(?![<>])/<E msg="INPHRASE{ar f\x{e1}il}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Ff]h\x{e1}n<\/N>)(?![<>])/<E msg="INPHRASE{ar f\x{e1}n}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">[Ff]haonoscailt<\/N>)(?![<>])/<E msg="INPHRASE{ar faonoscailt}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Ff]headh<\/N>)(?![<>])/<E msg="INPHRASE{ar feadh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Ff]h\x{e9}arach<\/N>)(?![<>])/<E msg="INPHRASE{ar f\x{e9}arach}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Ff]heitheamh<\/N>)(?![<>])/<E msg="INPHRASE{ar feitheamh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Ff]hiannas<\/N>)(?![<>])/<E msg="INPHRASE{ar fiannas}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Ff]hiar<\/N>)(?![<>])/<E msg="INPHRASE{ar fiar}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">[Ff]hionra\x{ed}<\/N>)(?![<>])/<E msg="INPHRASE{ar fionra\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Ff]hiuchadh<\/N>)(?![<>])/<E msg="INPHRASE{ar fiuchadh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Ff]h\x{f3}namh<\/N>)(?![<>])/<E msg="INPHRASE{ar f\x{f3}namh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Ff]horbh\x{e1}s<\/N>)(?![<>])/<E msg="INPHRASE{ar forbh\x{e1}s}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Ff]hoscadh<\/N>)(?![<>])/<E msg="INPHRASE{ar foscadh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Ff]host\x{fa}<\/N>)(?![<>])/<E msg="INPHRASE{ar fost\x{fa}}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Ff]hruili\x{fa}<\/N>)(?![<>])/<E msg="INPHRASE{ar fruili\x{fa}}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Gg]hor<\/N>)(?![<>])/<E msg="INPHRASE{ar gor}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">[Mm]haidin<\/N>)(?![<>])/<E msg="INPHRASE{ar maidin}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Mm]haos<\/N>)(?![<>])/<E msg="INPHRASE{ar maos}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">[Mm]heara\x{ed}<\/N>)(?![<>])/<E msg="INPHRASE{ar meara\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Mm]hearbhall<\/N>)(?![<>])/<E msg="INPHRASE{ar mearbhall}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Mm]hear\x{fa}<\/N>)(?![<>])/<E msg="INPHRASE{ar mear\x{fa}}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">[Mm]heisce<\/N>)(?![<>])/<E msg="INPHRASE{ar meisce}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">[Mm]hire<\/N>)(?![<>])/<E msg="INPHRASE{ar mire}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">[Mm]huir<\/N>)(?![<>])/<E msg="INPHRASE{ar muir}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Pp]hromhadh<\/N>)(?![<>])/<E msg="INPHRASE{ar promhadh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Ss]heachr\x{e1}n<\/N>)(?![<>])/<E msg="INPHRASE{ar seachr\x{e1}n}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Ss]hileadh<\/N>)(?![<>])/<E msg="INPHRASE{ar sileadh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Ss]hn\x{e1}mh<\/N>)(?![<>])/<E msg="INPHRASE{ar sn\x{e1}mh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Ss]hodar<\/N>)(?![<>])/<E msg="INPHRASE{ar sodar}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="f">[Tt]haispe\x{e1}int<\/N>)(?![<>])/<E msg="INPHRASE{ar taispe\x{e1}int}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Tt]heaghr\x{e1}n<\/N>)(?![<>])/<E msg="INPHRASE{ar teaghr\x{e1}n}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Tt]h\x{ed}<\/N>)(?![<>])/<E msg="INPHRASE{ar t\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Tt]hogradh<\/N>)(?![<>])/<E msg="INPHRASE{ar togradh}">$1<\/E>/g;
	s/(?<![<>])(<S>[Aa]r<\/S> <N pl="n" gnt="n" gnd="m">[Tt]huathal<\/N>)(?![<>])/<E msg="INPHRASE{ar tuathal}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> <N pl="n" gnt="n" gnd="m">bhord<\/N>)(?![<>])/<E msg="INPHRASE{thar bord}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> <N pl="n" gnt="n" gnd="f">bhr\x{e1}id<\/N>)(?![<>])/<E msg="INPHRASE{thar br\x{e1}id}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> <N pl="n" gnt="n" gnd="f">chailc<\/N>)(?![<>])/<E msg="INPHRASE{thar cailc}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> <N pl="n" gnt="n" gnd="m">cheal<\/N>)(?![<>])/<E msg="INPHRASE{thar ceal}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> <N pl="n" gnt="d">chionn<\/N>)(?![<>])/<E msg="INPHRASE{thar cionn}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> <N pl="n" gnt="n" gnd="f">chuimse<\/N>)(?![<>])/<E msg="INPHRASE{thar cuimse}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> <N pl="n" gnt="n" gnd="f">fharraige<\/N>)(?![<>])/<E msg="INPHRASE{thar farraige}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> <N pl="n" gnt="n" gnd="f">fh\x{f3}ir<\/N>)(?![<>])/<E msg="INPHRASE{thar f\x{f3}ir}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> <N pl="n" gnt="n" gnd="m">mhe\x{e1}n<\/N>)(?![<>])/<E msg="INPHRASE{thar me\x{e1}n}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> <N pl="n" gnt="n" gnd="f">mhuir<\/N>)(?![<>])/<E msg="INPHRASE{thar muir}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> <N pl="n" gnt="n" gnd="m">sh\x{e1}ile<\/N>)(?![<>])/<E msg="INPHRASE{thar s\x{e1}ile}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> <N pl="n" gnt="n" gnd="m">th\x{e9}arma<\/N>)(?![<>])/<E msg="INPHRASE{thar t\x{e9}arma}">$1<\/E>/g;
	s/(?<![<>])(<S>[Tt]har<\/S> <N pl="n" gnt="n" gnd="f">th\x{ed}r<\/N>)(?![<>])/<E msg="INPHRASE{thar t\x{ed}r}">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*>[Aa]ice<\/N>))(?![<>])/<E msg="INPHRASE{in aice}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="f">[Aa]icearracht<\/N>)(?![<>])/<E msg="INPHRASE{in aicearracht}">$1<\/E>/g;
	if (s/(?<![<>])(<N pl="n" gnt="n">[Aa]ithle<\/N>)(?![<>])/<E msg="INPHRASE{as a aithle sin}">$1<\/E>/g) {
	s/(<[A-DF-Z][^>]*>[Aa]s<\/[A-DF-Z]> <[A-DF-Z][^>]*>a<\/[A-DF-Z]> <E[^>]*><N pl="n" gnt="n">aithle<\/N><\/E> <[A-DF-Z][^>]*>sin<\/[A-DF-Z]>)/strip_errors($1);/eg;
	}
	s/(?<![<>])((?:<A[^>]*>h?[Aa]raile<\/A>))(?![<>])/<E msg="INPHRASE{agus araile}">$1<\/E>/g;
	s/(?<![<>])(<R>[Aa]r\x{fa}<\/R>)(?![<>])/<E msg="INPHRASE{ar\x{fa} am\x{e1}rach,anuraidh,ar\x{e9}ir,inn\x{e9}}">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*>h?[Aa]thl\x{e1}imh<\/N>))(?![<>])/<E msg="INPHRASE{ar athl\x{e1}imh}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Aa]tr\x{e1}th<\/N>)(?![<>])/<E msg="INPHRASE{ar atr\x{e1}th}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">[Bb]h?eathach<\/A>)(?![<>])/<E msg="INPHRASE{beo beathach}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">m?[Bb]h?ith<\/N>)(?![<>])/<E msg="INPHRASE{ar bith, c\x{e1}r bith}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Bb]h?\x{ed}thin<\/N>)(?![<>])/<E msg="INPHRASE{tr\x{ed} bh\x{ed}thin, de bh\x{ed}thin}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">m?[Bb]h?\x{f3}il\x{e9}agar<\/N>)(?![<>])/<E msg="INPHRASE{ar b\x{f3}il\x{e9}agar}">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*>m?[Bb]h?\x{f3}\x{ed}n<\/N>))(?![<>])/<E msg="INPHRASE{b\x{f3}\x{ed}n D\x{e9}}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Bb]r\x{e1}ch<\/N>)(?![<>])/<E msg="INPHRASE{go br\x{e1}ch}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">m?[Bb]h?r\x{ed}n<\/N>)(?![<>])/<E msg="INPHRASE{br\x{ed}n \x{f3}g}">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*>m?[Bb]h?uaileam<\/N>))(?![<>])/<E msg="INPHRASE{buaileam sciath}">$1<\/E>/g;
	if (s/(?<![<>])(<Q>[Cc]\x{e1}rb<\/Q>)(?![<>])/<E msg="INPHRASE{c\x{e1}rb as}">$1<\/E>/g) {
	s/(<E[^>]*><Q>[Cc]\x{e1}rb<\/Q><\/E> <[A-DF-Z][^>]*>[Aa]s<\/[A-DF-Z]>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">g[Cc]eartl\x{e1}r<\/N>)(?![<>])/<E msg="INPHRASE{i gceartl\x{e1}r}">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*>g[Cc]oitinne<\/N>))(?![<>])/<E msg="INPHRASE{i gcoitinne}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="f">g?[Cc]h?iolar<\/N>)(?![<>])/<E msg="INPHRASE{ciolar chiot}">$1<\/E>/g;
	s/(?<![<>])(<U>[Cc]hiot<\/U>)(?![<>])/<E msg="INPHRASE{ciolar chiot}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">g?[Cc]h?olgsheasamh<\/N>)(?![<>])/<E msg="INPHRASE{ina cholgsheasamh}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">g?[Cc]h?omhchlos<\/N>)(?![<>])/<E msg="INPHRASE{i gcomhchlos}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">g?[Cc]h?omhthr\x{e1}th<\/N>)(?![<>])/<E msg="INPHRASE{i gcomhthr\x{e1}th}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">n?[Dd]h?allach<\/N>)(?![<>])/<E msg="INPHRASE{dallach dubh}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Dd]hea<\/N>)(?![<>])/<E msg="INPHRASE{mar dhea}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">n?[Dd]h?earglasadh<\/N>)(?![<>])/<E msg="INPHRASE{ar dearglasadh}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">n?[Dd]h?eargmheisce<\/N>)(?![<>])/<E msg="INPHRASE{ar deargmheisce}">$1<\/E>/g;
	if (s/(?<![<>])(<N pl="n" gnt="n">[Dd]eo<\/N>)(?![<>])/<E msg="INPHRASE{go deo}">$1<\/E>/g) {
	s/(<[A-DF-Z][^>]*>[Gg]o<\/[A-DF-Z]> <E[^>]*><N pl="n" gnt="n">[Dd]eo<\/N><\/E>)/strip_errors($1);/eg;
	s/(<N pl="n" gnt="n">[Dd]eo<\/N> <E[^>]*><N pl="n" gnt="n">[Dd]eo<\/N><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n">[Dd]heoidh<\/N>)(?![<>])/<E msg="INPHRASE{faoi dheoidh}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[\x{c9}\x{e9}]atar<\/N>)(?![<>])/<E msg="INPHRASE{li\x{fa}tar \x{e9}atar}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[\x{c9}\x{e9}]ind\x{ed}<\/N>)(?![<>])/<E msg="INPHRASE{in \x{e9}ind\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[\x{c9}\x{e9}]ineacht<\/N>)(?![<>])/<E msg="INPHRASE{in \x{e9}ineacht}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[\x{c9}\x{e9}]is<\/N>)(?![<>])/<E msg="INPHRASE{tar \x{e9}is, d\x{e1} \x{e9}is}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n">bh[Ff]\x{e1}ch<\/A>)(?![<>])/<E msg="INPHRASE{i bhf\x{e1}ch}">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">F\x{e1}ileach<\/A>)(?![<>])/<E msg="INPHRASE{Fianna F\x{e1}ileach}">$1<\/E>/g) {
	s/(<[A-DF-Z][^>]*>(?:bh)?[Ff]h?ianna<\/[A-DF-Z]> <E[^>]*><A pl="n" gnt="n">F\x{e1}ileach<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">(?:bh)?[Ff]h?aopach<\/N>)(?![<>])/<E msg="INPHRASE{san fhaopach}">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">bhfearr<\/A>)(?![<>])/<E msg="INPHRASE{gura seacht bhfearr}">$1<\/E>/g) {
	s/(<V cop="y">(?:mba|gura)<\/V> <[A-DF-Z][^>]*>sh?eacht<\/[A-DF-Z]> <E[^>]*><A pl="n" gnt="n">bhfearr<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<A pl="n" gnt="n">F\x{e9}ineach<\/A>)(?![<>])/<E msg="INPHRASE{Sinn F\x{e9}ineach}">$1<\/E>/g) {
	s/(<[A-DF-Z][^>]*>Sh?inn<\/[A-DF-Z]> <E[^>]*><A pl="n" gnt="n">F\x{e9}ineach<\/A><\/E>)/strip_errors($1);/eg;
	}
	if (s/(?<![<>])(<A pl="n" gnt="n">Feirsteach<\/A>)(?![<>])/<E msg="INPHRASE{B\x{e9}al Feirsteach}">$1<\/E>/g) {
	s/(<[A-DF-Z][^>]*>m?Bh?\x{e9}al<\/[A-DF-Z]> <E[^>]*><A pl="n" gnt="n">Feirsteach<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">(?:bh)?[Ff]h?uaidreamh<\/N>)(?![<>])/<E msg="INPHRASE{ag fuaidreamh, ar fuaidreamh}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="f">(?:bh)?[Ff]h?oluain<\/N>)(?![<>])/<E msg="INPHRASE{ag foluain, ar foluain}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">bh[Ff]ud<\/N>)(?![<>])/<E msg="INPHRASE{ar fud na bhfud}">$1<\/E>/g;
	s/(?<![<>])(<R>[Ff]eillbhinn<\/R>)(?![<>])/<E msg="INPHRASE{go feillbhinn}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Ff]\x{ed}orchaoin<\/N>)(?![<>])/<E msg="INPHRASE{f\x{ed}orchaoin f\x{e1}ilte}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">(?:bh)?[Ff]h?ogas<\/N>)(?![<>])/<E msg="INPHRASE{i bhfogas}">$1<\/E>/g;
	s/(?<![<>])((?:<A[^>]*>[Ff]\x{f3}ill<\/A>))(?![<>])/<E msg="INPHRASE{go f\x{f3}ill}">$1<\/E>/g;
	s/(?<![<>])((?:<[AN][^>]*>[Ff]ras<\/[AN]>))(?![<>])/<E msg="INPHRASE{go fras}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Ff][ua]ta<\/N>)(?![<>])/<E msg="INPHRASE{futa fata}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Ff]ud<\/N>)(?![<>])/<E msg="INPHRASE{ar fud, fud fad}">$1<\/E>/g;
	if (s/(?<![<>])(<A pl="n" gnt="n">bhfusa<\/A>)(?![<>])/<E msg="INPHRASE{gura seacht bhfusa}">$1<\/E>/g) {
	s/(<V cop="y">(?:mba|gura)<\/V> <[A-DF-Z][^>]*>sh?eacht<\/[A-DF-Z]> <E[^>]*><A pl="n" gnt="n">bhfusa<\/A><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<R>[Gg]aidhte<\/R>)(?![<>])/<E msg="INPHRASE{lu\x{ed} gaidhte}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="y" gnd="f">n?[Gg]h?arman<\/N>)(?![<>])/<E msg="INPHRASE{Loch Garman}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">n?[Gg]h?lanmheabhair<\/N>)(?![<>])/<E msg="INPHRASE{de ghlanmheabhair}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Gg]leag<\/N>)(?![<>])/<E msg="INPHRASE{gliog gleag}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Gg]rif\x{ed}n<\/N>)(?![<>])/<E msg="INPHRASE{codladh grif\x{ed}n}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>h\x{e1}irithe<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{go h\x{e1}irithe}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="n" h="y">hamh\x{e1}in<\/A>)(?![<>])/<E msg="INPHRASE{n\x{ed} hamh\x{e1}in}">$1<\/E>/g;
	s/(?<![<>])((?:<[AR][^>]*>hamhlaidh<\/[AR]>))(?![<>])/<E msg="INPHRASE{n\x{ed} hamhlaidh}">$1<\/E>/g;
	s/(?<![<>])(<A pl="n" gnt="y" gnd="f">hansa<\/A>)(?![<>])/<E msg="INPHRASE{n\x{ed} hansa}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[HC]ong<\/N>)(?![<>])/<E msg="INPHRASE{Hong Cong}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Hh]\x{fa}ta<\/N>)(?![<>])/<E msg="INPHRASE{raiple h\x{fa}ta}">$1<\/E>/g;
	if (s/(?<![<>])(<N pl="n" gnt="n">[Ii]nn<\/N>)(?![<>])/<E msg="INPHRASE{ar inn ar ea, ar inn ar \x{e9}igean}">$1<\/E>/g) {
	s/(<S>[Aa]r<\/S> <E[^>]*><N pl="n" gnt="n">[Ii]nn<\/N><\/E> <[A-DF-Z][^>]*>ar<\/[A-DF-Z]> <[A-DF-Z][^>]*>(?:ea|\x{e9}igean)<\/[A-DF-Z]>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Ll]\x{e1}nseol<\/N>)(?![<>])/<E msg="INPHRASE{faoi l\x{e1}nseol}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="f">[Ll]\x{e9}ig<\/N>)(?![<>])/<E msg="INPHRASE{i l\x{e9}ig}">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*>[Ll]eith<\/N>))(?![<>])/<E msg="INPHRASE{ar leith, faoi leith, i leith}">$1<\/E>/g;
	s/(?<![<>])(<[A-DF-Z][^>]*>[Ll]eithligh<\/[A-DF-Z]>)(?![<>])/<E msg="INPHRASE{ar leithligh}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Ll]iobarna<\/N>)(?![<>])/<E msg="INPHRASE{ar liobarna}">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*>li\x{fa}tar<\/N>))(?![<>])/<E msg="INPHRASE{li\x{fa}tar \x{e9}atar}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Ll]uthairt<\/N>)(?![<>])/<E msg="INPHRASE{luthairt lathairt}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Mm]aos<\/N>)(?![<>])/<E msg="INPHRASE{ar maos}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="f">[Mm]h?arthain<\/N>)(?![<>])/<E msg="INPHRASE{ar marthain}">$1<\/E>/g;
	s/(?<![<>])(<U>[Mm]oite<\/U>)(?![<>])/<E msg="INPHRASE{c\x{e9} is moite}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Mm]ugadh<\/N>)(?![<>])/<E msg="INPHRASE{mugadh magadh}">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*>nd\x{e1}ir\x{ed}re<\/N>))(?![<>])/<E msg="INPHRASE{i nd\x{e1}ir\x{ed}re}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Nn]eamhchead<\/N>)(?![<>])/<E msg="INPHRASE{ar neamhchead}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">n[gG]ach<\/N>)(?![<>])/<E msg="INPHRASE{i ngach}">$1<\/E>/g;
	s/(?<![<>])(<S>n[gG]an<\/S>)(?![<>])/<E msg="INPHRASE{i ngan fhios}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">ngearr<\/N>)(?![<>])/<E msg="INPHRASE{i bhfad agus i ngearr}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Nn][ie][\x{e1}\x{fa}]dar<\/N>)(?![<>])/<E msg="INPHRASE{ni\x{fa}dar ne\x{e1}dar}">$1<\/E>/g;
	s/(?<![<>])(<R>[Nn]uige<\/R>)(?![<>])/<E msg="INPHRASE{go nuige}">$1<\/E>/g;
	s/(?<![<>])(<R>[Pp]l(?:ea)?inc<\/R>)(?![<>])/<E msg="INPHRASE{plinc pleainc}">$1<\/E>/g;
	s/(?<![<>])(<U>[Rr]agaim<\/U>)(?![<>])/<E msg="INPHRASE{meacan ragaim}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Rr]aiple<\/N>)(?![<>])/<E msg="INPHRASE{raiple h\x{fa}ta}">$1<\/E>/g;
	s/(?<![<>])(<U>[Rr]e<\/U>)(?![<>])/<E msg="INPHRASE{gach re}">$1<\/E>/g;
	s/(?<![<>])(<U>[Rr]\x{f3}ib\x{e9}is<\/U>)(?![<>])/<E msg="INPHRASE{ribe r\x{f3}ib\x{e9}is}">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*>[RrBb]uaille<\/N>))(?![<>])/<E msg="INPHRASE{ruaille buaille}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="f">[Ss]\x{e1}inn<\/N>)(?![<>])/<E msg="INPHRASE{i s\x{e1}inn}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">[Ss]aochan<\/N>)(?![<>])/<E msg="INPHRASE{saochan c\x{e9}ille}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="f">t?sh?l\x{e1}nchruinne<\/N>)(?![<>])/<E msg="INPHRASE{sa tsl\x{e1}nchruinne}">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*>[Ss]ciot\x{e1}n<\/N>))(?![<>])/<E msg="INPHRASE{de sciot\x{e1}n}">$1<\/E>/g;
	s/(?<![<>])(<R>[Ss]c[ua]n<\/R>)(?![<>])/<E msg="INPHRASE{scun scan}">$1<\/E>/g;
	s/(?<![<>])(<S>[Ss]each<\/S>)(?![<>])/<E msg="INPHRASE{faoi seach}">$1<\/E>/g;
	s/(?<![<>])((?:<A[^>]*>[Ss]hin<\/A>))(?![<>])/<E msg="INPHRASE{\x{f3} shin}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Ss]inc\x{ed}n<\/N>)(?![<>])/<E msg="INPHRASE{si\x{fa}n sinc\x{ed}n}">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*>[Ss]iobh\x{e1}i?n<\/N>))(?![<>])/<E msg="INPHRASE{mac siobh\x{e1}in}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Ss]i\x{fa}n<\/N>)(?![<>])/<E msg="INPHRASE{si\x{fa}n sinc\x{ed}n}">$1<\/E>/g;
	if (s/(?<![<>])(<N pl="n" gnt="n">[Ss]h?on<\/N>)(?![<>])/<E msg="INPHRASE{ar son}">$1<\/E>/g) {
	s/(<S>[Aa]r<\/S> <D>(?:mo|do|a)<\/D> <E[^>]*><N pl="n" gnt="n">[Ss]hon<\/N><\/E>)/strip_errors($1);/eg;
	s/(<S>[Aa]r<\/S> <D>(?:\x{e1}r|bhur|a)<\/D> <E[^>]*><N pl="n" gnt="n">[Ss]on<\/N><\/E>)/strip_errors($1);/eg;
	}
	s/(?<![<>])(<N pl="n" gnt="n">[Ss]p[ie][oa]r<\/N>)(?![<>])/<E msg="INPHRASE{spior spear}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Ss]teig<\/N>)(?![<>])/<E msg="INPHRASE{steig meig}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Ss]teillbheatha<\/N>)(?![<>])/<E msg="INPHRASE{ina steillbheatha}">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*>[Ss]trae<\/N>))(?![<>])/<E msg="INPHRASE{ar strae}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Ss][\x{fa}\x{e1}]m<\/N>)(?![<>])/<E msg="INPHRASE{s\x{fa}m s\x{e1}m}">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*>d[Tt]aisce<\/N>))(?![<>])/<E msg="INPHRASE{i dtaisce}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="m">d?[Tt]h?eachtadh<\/N>)(?![<>])/<E msg="INPHRASE{ar teachtadh}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="f">d[Tt]eagmh\x{e1}il<\/N>)(?![<>])/<E msg="INPHRASE{i dteagmh\x{e1}il}">$1<\/E>/g;
	s/(?<![<>])(<S>d[Tt]\x{ed}<\/S>)(?![<>])/<E msg="INPHRASE{go dt\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">d[Tt]\x{f3}lamh<\/N>)(?![<>])/<E msg="INPHRASE{i dt\x{f3}lamh}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="y" gnd="m">d[Tt]r\x{e1}tha<\/N>)(?![<>])/<E msg="INPHRASE{i dtr\x{e1}tha}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="f">d[Tt]reis<\/N>)(?![<>])/<E msg="INPHRASE{i dtreis}">$1<\/E>/g;
	s/(?<![<>])((?:<N[^>]*>d[Tt]uilleama\x{ed}<\/N>))(?![<>])/<E msg="INPHRASE{i dtuilleama\x{ed}}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Tt]h?amhach<\/N>)(?![<>])/<E msg="INPHRASE{tamhach t\x{e1}isc}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Tt]hiarcais<\/N>)(?![<>])/<E msg="INPHRASE{a thiarcais}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n">[Tt]inneall<\/N>)(?![<>])/<E msg="INPHRASE{ar tinneall}">$1<\/E>/g;
	s/(?<![<>])(<N pl="n" gnt="n" gnd="f">[Tt]reis<\/N>)(?![<>])/<E msg="INPHRASE{go treis, sa treis}">$1<\/E>/g;
	}
}

sub unigram
{
	for ($_[0]) {
	s/<B><Z>(?:<[^>]*>)*<S.>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<S>$1<\/S>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="n" gnt="n" gnd="m".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="n" gnt="n" gnd="m">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="n" gnt="n" gnd="f".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="n" gnt="n" gnd="f">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<T.>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<T>$1<\/T>/g;
	s/<B><Z>(?:<[^>]*>)*<A pl="n" gnt="n".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<A pl="n" gnt="n">$1<\/A>/g;
	s/<B><Z>(?:<[^>]*>)*<C.>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<C>$1<\/C>/g;
	s/<B><Z>(?:<[^>]*>)*<R.>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<R>$1<\/R>/g;
	s/<B><Z>(?:<[^>]*>)*<V p="y" t="l\x{e1}ith".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<V p="y" t="l\x{e1}ith">$1<\/V>/g;
	s/<B><Z>(?:<[^>]*>)*<P.>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<P>$1<\/P>/g;
	s/<B><Z>(?:<[^>]*>)*<V p="y" t="caite".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<V p="y" t="caite">$1<\/V>/g;
	s/<B><Z>(?:<[^>]*>)*<O.>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<O>$1<\/O>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="y" gnt="n" gnd="m".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="y" gnt="n" gnd="m">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="n" gnt="y" gnd="m".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="n" gnt="y" gnd="m">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="n" gnt="y" gnd="f".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="n" gnt="y" gnd="f">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<D.>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<D>$1<\/D>/g;
	s/<B><Z>(?:<[^>]*>)*<V cop="y".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<V cop="y">$1<\/V>/g;
	s/<B><Z>(?:<[^>]*>)*<U.>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<U>$1<\/U>/g;
	s/<B><Z>(?:<[^>]*>)*<G.>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<G>$1<\/G>/g;
	s/<B><Z>(?:<[^>]*>)*<A.>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<A>$1<\/A>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="y" gnt="n" gnd="f".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="y" gnt="n" gnd="f">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<A pl="y" gnt="n".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<A pl="y" gnt="n">$1<\/A>/g;
	s/<B><Z>(?:<[^>]*>)*<V p="y" t="coinn".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<V p="y" t="coinn">$1<\/V>/g;
	s/<B><Z>(?:<[^>]*>)*<V p="y" t="f\x{e1}ist".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<V p="y" t="f\x{e1}ist">$1<\/V>/g;
	s/<B><Z>(?:<[^>]*>)*<Q.>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<Q>$1<\/Q>/g;
	s/<B><Z>(?:<[^>]*>)*<A pl="n" gnt="y" gnd="f".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<A pl="n" gnt="y" gnd="f">$1<\/A>/g;
	s/<B><Z>(?:<[^>]*>)*<V p="n" t="caite".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<V p="n" t="caite">$1<\/V>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="n" gnt="n".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="n" gnt="n">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="y" gnt="y" gnd="m".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="y" gnt="y" gnd="m">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="n" gnt="y" gnd="f" h="y".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="n" gnt="y" gnd="f" h="y">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<H.>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<H>$1<\/H>/g;
	s/<B><Z>(?:<[^>]*>)*<V p="n" t="l\x{e1}ith".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<V p="n" t="l\x{e1}ith">$1<\/V>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="y" gnt="n" gnd="m" h="y".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="y" gnt="n" gnd="m" h="y">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<F.>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<F>$1<\/F>/g;
	s/<B><Z>(?:<[^>]*>)*<V p="y" t="ord".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<V p="y" t="ord">$1<\/V>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="n" gnt="d".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="n" gnt="d">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="y" gnt="y" gnd="f".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="y" gnt="y" gnd="f">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<A pl="n" gnt="n" h="y".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<A pl="n" gnt="n" h="y">$1<\/A>/g;
	s/<B><Z>(?:<[^>]*>)*<O em="y".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<O em="y">$1<\/O>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="n" gnt="n" gnd="f" h="y".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="n" gnt="n" gnd="f" h="y">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="n" gnt="n" gnd="m" h="y".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="n" gnt="n" gnd="m" h="y">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<V p="n" t="f\x{e1}ist".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<V p="n" t="f\x{e1}ist">$1<\/V>/g;
	s/<B><Z>(?:<[^>]*>)*<V p="n" t="coinn".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<V p="n" t="coinn">$1<\/V>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="y" gnt="n" gnd="f" h="y".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="y" gnt="n" gnd="f" h="y">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<V p="y" t="gn\x{e1}th".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<V p="y" t="gn\x{e1}th">$1<\/V>/g;
	s/<B><Z>(?:<[^>]*>)*<A pl="n" gnt="y" gnd="m".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<A pl="n" gnt="y" gnd="m">$1<\/A>/g;
	s/<B><Z>(?:<[^>]*>)*<P h="y".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<P h="y">$1<\/P>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="y" gnt="n".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="y" gnt="n">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="n" gnt="d" h="y".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="n" gnt="d" h="y">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<I.>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<I>$1<\/I>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="y" gnt="y".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="y" gnt="y">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<V p="y" t="foshuit".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<V p="y" t="foshuit">$1<\/V>/g;
	s/<B><Z>(?:<[^>]*>)*<V p="n" t="gn\x{e1}th".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<V p="n" t="gn\x{e1}th">$1<\/V>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="y" gnt="n" h="y".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="y" gnt="n" h="y">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="n" gnt="y" gnd="m" h="y".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="n" gnt="y" gnd="m" h="y">$1<\/N>/g;
	s/<B><Z>(?:<[^>]*>)*<N pl="n" gnt="n" h="y".>(?:<[^>]*>)*<\/Z>([^<]+)<\/B>/<N pl="n" gnt="n" h="y">$1<\/N>/g;
	}
}

# recursive helper function for "tag_one_word".  
#
#  Arguments: "original" word to be tagged; the "current"
#  decomposed version for lookup (and possible further decomp)
#  a "level" which determines whether, if a match is found,
#  whether it should be untagged (-1), tagged as OK but noting decomp (0),
#  tagged as non-standard (1), or tagged as a misspelling (2),
#  a reference "rootpos" to an array of regexps that must match if
#  the current is found in the lexicon,
#  and the maximum allowed recursion depth (decremented on each recursion)
#
#   Returns the word tagged appropriately if a match is found, returns
#   false ("") if the recursion bottoms out with no matches
sub tag_recurse
{
	my ( $self, $original, $current, $level, $rootpos, $maxdepth ) = @_;

	my $ans = $self->lookup( $original, $current, $level, $rootpos );
	return "" if ($ans eq "STOP" or $maxdepth == 0);
	return $ans if $ans;
	my $newcurrent;
	foreach my $rule (@MORPH) {
		my $p = $rule->{'compiled'};
		if ( $current =~ m/$p/ ) {
			my $r = $rule->{'repl'};
			my $pos = $rule->{'poscompiled'};
			$newcurrent = $current;
			$newcurrent =~ s/$p/$r/eeg;
			push @$rootpos, $pos if $pos;
			$ans = $self->tag_recurse($original, $newcurrent, ($level > $rule->{'level'}) ? $level : $rule->{'level'}, $rootpos, $maxdepth - 1);
			pop @$rootpos if $pos;
			return $ans if $ans;
		}
	}
	return "";
}



1;

__END__

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
correctly. See L<http://borel.slu.edu/gramadoir/bugs.html> for a
detailed discussion and specific examples.

=head1 AUTHOR

Kevin P. Scannell, E<lt>scannell@slu.eduE<gt>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 Kevin P. Scannell
                   

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
