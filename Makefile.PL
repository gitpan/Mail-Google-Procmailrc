use 5.010000;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME              => 'Mail::Google::Procmailrc',
    VERSION_FROM      => 'lib/Mail/Google/Procmailrc.pm',
    PREREQ_PM         => {
        'XML::Fast'     => '0.11',
        'Getopt::Long'  => '2.42',
    },
    ($] >= 5.005 ?
      (ABSTRACT_FROM  => 'lib/Mail/Google/Procmailrc.pm', 
       AUTHOR         => 'Stefan Petrea <stefan@garage-coding.com>') : ()),
);
