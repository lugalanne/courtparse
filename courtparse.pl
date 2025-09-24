#!/usr/bin/perl

use strict; use warnings;
use utf8;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Cookies;
use Getopt::Long;
use Pod::Usage qw(pod2usage);
use Encode qw(decode);
use HTML::TreeBuilder;
use Text::CSV_XS;
binmode(STDOUT, ':encoding(UTF-8)');

my $q = '';
my $help = 0;
my $case_num = '';
my $person = '';
my $court_type=''; # 'ug','adm','gr'
my $stage = '';
my $noutput = "out";
my $pfulltext = 0;
@ARGV = map{decode('UTF-8',$_)} @ARGV;
GetOptions('help|?'=>\$help, 'text=s'=> \$q,'type=s'=>\$court_type,'case_num=s'=>\$case_num,'stage=s'=>\$stage,'person=s'=>\$person,'output=s'=>\$noutput,'fulltext'=>\$pfulltext);
pod2usage(1) if $help;
if(($court_type =~ /\A(?:ug|adm|gr)\z/ || $court_type eq '') && ($stage =~ /\A(?:first|appeal|cass|nadzor)\z/ || $stage eq ''))
{
print "Query: ".$q." Person: ".$person." Case type: ".$court_type." Stage of proceedings: ".$stage." ".$case_num."\n";
}
else{
die "Incorrect query";
}

my $ua = LWP::UserAgent->new(timeout=>30);
my $url_post = 'https://xn--90afdbaav0bd1afy6eub5d.xn--p1ai/simple_filter';
my $url_get = 'https://xn--90afdbaav0bd1afy6eub5d.xn--p1ai/search';

my $cookie_jar = HTTP::Cookies->new();
$ua->cookie_jar($cookie_jar);

my $request_get_cookie = GET ($url_get);
my $html = $ua->request($request_get_cookie)->decoded_content or die('Error with request');
my ($token) = $html =~/class="form-control" value="(\S*)"/ or die "CSRF _token not found";

my $request_post = POST( $url_post,'Content_Type'=>'application/x-www-form-urlencoded; charset=UTF-8',
Content=>[
  'simpleSearch[content]' => $q, 
  'simpleSearch[case_number]'              => $case_num,
  'simpleSearch[person_info][0][person]'   => $person,
  'simpleSearch[person_info][0][person_status]' => '',
  'simpleSearch[case_vid]'                 => $court_type,
  'simpleSearch[case_stage]'               => $stage,
  'simpleSearch[search]'                   => '',
  'simpleSearch[_token]'                   => $token]) or die "Error $!";


$ua->request($request_post);
my $after_post = $ua->request(GET($url_get));
my $content_get = $after_post->decoded_content or die "Cannot parse content";

my ($cases_total) = $content_get =~ /Показано документов:..b> (\d+)/g;
print 'Cases found: '.$cases_total,"\n";
my $total_pages = int($cases_total/20+0.5);
my ($outpt) = $content_get =~ /id="list">(.*)<\/table/s or die('Not found');
print "Pages to be scraped: ".$total_pages,"\n";
if ($total_pages > 1 ){
  for (my $pages = 2; $pages != $total_pages+1;$pages++){ 
    print 'Now scraping page: ',$pages,"\n";
    my $output = $ua->request(GET($url_get."?page="."$pages"))->decoded_content;
    my ($clean_nextpages) = $output =~ /id="list">(.*)<\/table/s;
    $outpt = $outpt.$clean_nextpages;
    sleep 1;
  }
}
# Now lets parse 
my $parser = HTML::TreeBuilder->new;
$parser->parse($outpt) or die "Something gone wrong while parsing"; 
$parser->eof();
print "Writing to $noutput".'.csv',"\n";
my @cases;


my $fulltxt;
if($pfulltext)
{
open $fulltxt, '>>:encoding(utf-8)',$noutput.'.txt' or die('Cannot write to file '.$!);
}
sub get_fulltext{
my $link = shift;
my $court_text = $ua->request(GET('https://xn--90afdbaav0bd1afy6eub5d.xn--p1ai'.$link));
my ($fulltext) = $court_text->decoded_content =~ m/blockquote itemprop="text">(.*)<\/blockquote/si;
if(defined $fulltext){
my $prser_2 = HTML::TreeBuilder->new;
$prser_2->parse($fulltext);
$prser_2->eof();
#print $prser_2->as_text;
print $fulltxt $prser_2->as_text."\n";
$prser_2 = $prser_2->delete;
}
print STDERR  '-';

}

for my $p ($parser->find_by_tag_name('table')){
  my @case;
  my $link = $p->look_down('_tag','a')->attr('href');
  push @case,'судебныерешения.рф'.$link;
  my $case_number = $p->look_down('_tag','b')->as_text;
  $case_number =~ s/^\s+|\s+$//g;  
  push @case, $case_number;
  my $tt =  $p->look_down('_tag','td')->as_text;  
  $tt =~ s/^\s+|\s+$//g;
  push @case,$tt; 
  my @all_p =  $p->look_down('_tag','p');
  my ($data,$sides) = ($all_p[0]->as_text,$all_p[1]->as_text);
  $data =~s/^\s+|\s+$//g;
  $sides =~ s/^\s+|\s+$//g;
  push @case,$data,$sides; 
  if($pfulltext) {
    get_fulltext($link);
  }
  push(@cases, [@case]);
}
$parser = $parser->delete;
my $csv = Text::CSV_XS->new(
  {
    binary=>1,
    eol=>"\n",
    sep_char=>";"
  });

open my $outf, '>:encoding(utf-8)',$noutput.'.csv' or die('Cannot write to file '.$!);
$csv->print($outf,['Link','Case №','Court','Data','Sides']);
for my $row (@cases)
{
  $csv->print($outf, $row);
}
close $outf;
if ($pfulltext){ close $fulltxt;}

print "\nOK\n";
__END__
=encoding UTF-8
=head1 SYNOPSIS

holden.pl --text TEXT --person TEXT --type {ug|gr|adm} --stage {first|appeal|cass|nadzor} --output FILE [options]

  holden.pl --text "компенсация морального вреда" --type gr --stage first --output kmv.csv
  holden.pl --person "Роснефть" --type adm --stage appeal --output rosneft.csv

=item B<--text> I<STRING>

Free-text query (optional).

=item B<--person> I<STRING>

Name of physical or legal person (optional).

=item B<--type> I<VALUE>

Case type: C<ug|gr|adm>.
C<ug>=criminal, C<gr>=civil, C<adm>=administrative (optional).

=item B<--stage> I<VALUE>

Procedural stage: C<first|appeal|cass|nadzor>.
C<first>=first instance, C<appeal>=appeal, C<cass>=cassation, C<nadzor>=supervisory review (optional).

=item B<--output> I<FILE>

Output CSV file path (default: C<out.csv>).

=item B<--fulltext>

Also save the full text of each court document (this may be slow).
Disabled by default.

=item B<--help>

Show this screen and exit.

