package LIFinder::TokenHash;

use strict;
use Digest::MD5 qw(md5_hex);
# use Digest::SHA1 qw(sha1 sha1_hex);
use LIFinder::Tokenizor::CCFinderX;
use File::Spec::Functions 'catfile';

my $ccfx_default_cmd = 'ccfx';
sub new {
    my ($class, %args) = @_;

    my $self = bless({}, $class);

    die "parameter 'dbm' is mandatory" unless exists $args{dbm};
    die "parameter 'file_types' is mandatory" unless exists $args{file_types};
    die "parameter 'output_dir' is mandatory" unless exists $args{output_dir};

    $self->{dbm} = $args{dbm};
    $self->{file_types} = $args{file_types};
    $self->{output_dir} = $args{output_dir};

    return $self;
}

sub execute {
    my ($self) = @_;

    my $dbm = $self->{dbm};
    my @types = split /,/, $self->{file_types};
    my @exts = map { '.' . $_ } @types;

    my $token_info_id = 0;
    foreach my $ext (@exts) {
        # @file_list looks like this:
        # @file_list = (
        #     { id => '1', path => 'path', hash = > 'deadbeef', },
        #     { ... },
        #     );
        my @file_list;

        my $sth = $dbm->execute('s_file', $ext);

        while (my @row = $sth->fetchrow_array()) {
            my ($f_id, $dir, $path) = @row;
            my $full_path = join('', $dir, $path, $ext);

            # print "$full_path\n";
            my %file_item = (
                id => $f_id,
                path => $full_path,
                );
            push @file_list, \%file_item;
        }

        # remove leading dot, convert to lowercase
        my $normalized_ext = substr($ext, 1) if (substr($ext, 0, 1) eq '.');
        $normalized_ext = lc $normalized_ext;

        LIFinder::Tokenizor::CCFinderX::get_token_hash(\@file_list, 
            $normalized_ext, \&_digester);

        foreach my $file_item_ref (@file_list) {
            my %item = %{$file_item_ref};
            $dbm->execute('i_token', $item{hash}, $item{length});
            $dbm->execute('u_token', $item{hash});
            $dbm->execute('u_file', $item{hash}, $item{id});
        }

    }

    $dbm->commit();
}

sub _digester {
    my $str = ${+shift}; # dereference
    return md5_hex($str);
    # return sha1_hex($str);
}


1;

__END__