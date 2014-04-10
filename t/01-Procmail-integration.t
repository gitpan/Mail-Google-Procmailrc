use strict;
use warnings;
use Email::Simple;
use Test::More;


if(!-f '/usr/bin/procmail' || !-f '/usr/bin/formail') {
    plan skip_all => "/usr/bin/procmail and /usr/bin/formail required for these tests";
};


my $testdata_dir = "testdata";
my $test_email_prefix="prefix-email";
`rm testdata/$test_email_prefix*`;

sub gen_email {
    my ($h) = @_;
    my $e = Email::Simple->new("");
    $e->header_set("From"    , $h->{from}    );
    $e->header_set("To"      , $h->{to}      );
    $e->header_set("Subject" , $h->{subject} );
    $e->header_set("Date" => "Email::Simple::Creator"->_date_header);
    $e->body_set($h->{text});

    open my $fh, ">$h->{output}";
    print $fh $e->as_string;
    close $fh;
};

for(1..10) {
    gen_email({
        from=>'sender@email.com',
        to=>'receiver@email.com',
        subject=> "test$_",
        text=>"YYZJSA",
        output=>"$testdata_dir/$test_email_prefix-$_",
    });
};



# TODO: implement procmail/formail tests
ok(1,"This test will always pass");

done_testing();
