package Mail::Google::Procmailrc;
use 5.018002;
use strict;
use warnings;
use XML::Fast;
use Data::Dumper;
use Carp;
require Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw(  ) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw( );
our $VERSION = '0.02';
=head1 NAME

Mail::Google::Procmailrc - Perl module that allows easy conversion from Gmail mail filters to Procmail rules

=head1 SYNOPSIS

  use Mail::Google::Procmailrc;
  my $o = Mail::Google::Procmailrc->new(<path-to-mail-folders>);
  $o->convert(<google-mail-filter-path>, <procmail-rules-output-path>);

or, you can use it with the helper script

  ./bin/google-to-procmailrc ./mailFilters.xml test-procmail.rc $HOME/somemail

=head1 DESCRIPTION

You may want at some point, for some reason to export all your gmail mail rules as
procmail filters. 

If you use a mail setup involving OfflineIMAP fetching multiple folders(labels) from
Google, you'll notice that there is a certain overhead involved.

That's because OfflineIMAP needs to tell the IMAP server, which messages it has, in
order to retrieve only the ones that it doesn't, and then for each new message fetched
it also needs to update the SQLite local dbs with the statuses of the new messages.
And it has to do that for every folder(label). That highly depends on which labels you
fetch with OfflineIMAP.

If you want to make the sync faster, you can consider only fetching the "[Gmail]/All Mail"
folder or the "INBOX" folder, but then you still have to solve mail triage.

Procmail is quite good for mail triage, but the mailFilters.xml file that you can
export from Gmail is not suited for use with Procmail AFAIK.

This module aims to solve that problem by converting mailFilters.xml to a set of
procmail rules (effectively a procmailrc file).

Normally, you'd use the script that comes with this module to migrate your Gmail rules
to procmail and then you can just maintain the procmail rules. At least that's how I(plan to) use it.

=cut

our $tmplt1= qq{:0:
* ^From:.*%s.*
%s

};

our $tmplt2 = qq{:0:
* ^To: .*%s.*
%s

};

our $tmplt3 = qq{:0: B
* %s
%s
};

sub new {
    my ($class_name,$folders_path,$archive_dir,$trash_dir) = @_;
    my $o = bless {},$class_name;
    # TODO check for folders_path
    $o->{folders_path} = $folders_path;
    $o->{archive_dir}  = $archive_dir // 'archive';
    $o->{trash_dir}    = $trash_dir   // 'trash';
    $o->{labels_found} = {};
    return $o;
};

sub generate_create_dirs_script {
    my ($self) = @_;
    my $create_script = "create.sh";
    open my $fh,">$create_script";
    print $fh "#!/bin/bash\n";
    my $p = $self->{folders_path};
    my @labels;
    push @labels, (keys %{ $self->{labels_found} } );
    push @labels, $self->{archive_dir};
    push @labels, $self->{trash_dir};
    for my $l ( @labels ) {
        print $fh qq{mkdir -p "$p/$l"\n};
    };
    close $fh;
    `chmod +x $create_script`;
};

sub convert {
    my ($self,$i,$o) = @_;
    my $google_filters_xml = undef;
    {
        local $/ = undef;
        open my $fh,"<$i";
        $google_filters_xml = <$fh>;
        close $fh;
    };
    my $xml_nested = xml2hash($google_filters_xml);
    my ($buf_regular,$buf_archive,$buf_trash) = $self->adapt($xml_nested);
    open my $fh,">$o";
    print $fh "########################################\n";
    print $fh "############## Regular rules ###########\n";
    print $fh "########################################\n";
    print $fh $buf_regular;
    print $fh "########################################\n";
    print $fh "############## Archive rules ###########\n";
    print $fh "########################################\n";
    print $fh $buf_archive;
    print $fh "########################################\n";
    print $fh "############## Trash   rules ###########\n";
    print $fh "########################################\n";
    print $fh $buf_trash  ;
    close $fh;
    $self->generate_create_dirs_script;
};

sub adapt {
    my ($self,$x) = @_;
    my $buf_regular = "";
    my $buf_archive = "";
    my $buf_trash   = "";
    #print join(",",keys %$x)."\n";
    for my $o (@{ $x->{feed}->{entry} }) {
        next if $o->{title} ne 'Mail Filter';
        next if !exists $o->{"apps:property"};
        next if ref($o->{"apps:property"}) ne "ARRAY";
        my $adapt_hash = {};
        for my $p (@{ $o->{"apps:property"} }) {
            my $key = $p->{'-name' };
            my $val = $p->{'-value'};
            $adapt_hash->{$key} = $val;
        };
        my ($rules_regular,$rules_archive,$rules_trash) = $self->adapt_rule($adapt_hash);
        $buf_regular .= $rules_regular;
        $buf_archive .= $rules_archive;
        $buf_trash   .= $rules_trash;
    };

    return ($buf_regular,$buf_archive,$buf_trash);
};

sub collect_label {
    my ($self,$l) = @_;
    $self->{labels_found}->{$l} = 1;
};

sub rule_from {
    my ($self, $h) = @_;
    my $buf = "";
    if(exists $h->{from} && exists $h->{label}) {
        my $dir = $self->{folders_path}.'/'.$h->{label}.'/';
        $buf    = sprintf($tmplt1,$h->{from},$dir);
    };
    return $buf;
};

sub rule_to {
    my ($self, $h) = @_;
    my $buf = "";
    if(exists $h->{to}   && exists $h->{label}) {
        my $dir = $self->{folders_path}.'/'.$h->{label}.'/';
        $buf    = sprintf($tmplt1,$h->{to},$dir);
    };
    return $buf;
};

sub rule_body {
    my ($self, $h) = @_;
    # TODO
};

sub rule_archive {
    my ($self, $h) = @_;
    my $buf = "";
    if($h->{'shouldArchive'}) {
        $h->{label} = $self->{archive_dir};
        $buf .= $self->rule_from($h);
        $buf .= $self->rule_to($h);
    };
    return $buf;
};

sub rule_trash {
    my ($self, $h) = @_;
    my $buf = "";
    if($h->{'shouldTrash'}) {
        $h->{label} = $self->{trash_dir};
        $buf .= $self->rule_from($h);
        $buf .= $self->rule_to($h);
    };
    return $buf;
};

sub adapt_rule {
    my ($self,$h) = @_;
    my $rules_regular = "";
    my $rules_archive = "";
    my $rules_trash   = "";

    $self->collect_label($h->{label})
        if($h->{label});

    $rules_regular .= $self->rule_from($h);
    $rules_regular .= $self->rule_to($h);
    $rules_archive .= $self->rule_archive($h);
    $rules_trash   .= $self->rule_trash($h);

    return ($rules_regular,$rules_archive,$rules_trash);
};


1;
__END__
=head1 NOTES

If you decide to use B<[Gmail]/All Mail> as the folder you sync and then use procmail
to run on it, you'll have to deal with the Spam (maybe spamassassin would help there).

From that point of view it's probably easier to just use B<INBOX>.

Currently this module only has functionality for converting some of the gmail rules.

=head1 SEE ALSO

=over 1

=item L<Exporting Gmail mail filters|http://webapps.stackexchange.com/a/3643>

=item L<Synchronization that OfflineIMAP does|https://github.com/OfflineIMAP/offlineimap/blob/41cb0f577f6921a644d0c4c1ac23dd391270fee7/docs/doc-src/FAQ.rst#115what-is-the-uid-validity-problem-for-folder>

=item L<spamassassin|https://spamassassin.apache.org/>

=back

=head1 BUGS

Please report bugs using the L<rt.cpan.org queue|https://rt.cpan.org/Public/Dist/Display.html?Name=Mail-Google-Procmailrc>.

=head1 PATCHES

Patches are welcome, either in the form of pull-requests on the L<github repo|https://github.com/wsdookadr/p5-Mail-Google-Procmailrc> or
in the form of patches on L<cpan's request tracker|http://rt.cpan.org>

=head1 AUTHOR

Stefan Petrea, E<lt>stefan@garage-coding.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Stefan Petrea

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
