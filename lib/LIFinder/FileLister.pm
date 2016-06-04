package LIFinder::FileLister;

use strict;
use File::Find;
use File::Basename;

sub new {
    my ($class, %args) = @_;

    my $self = bless({}, $class);

    die "parameter 'input_dirs_ref' is mandatory" unless exists $args{input_dirs_ref};
    die "parameter 'db' is mandatory" unless exists $args{db};
    die "parameter 'file_types' is mandatory" unless exists $args{file_types};

    $self->{input_dirs_ref} = $args{input_dirs_ref};
    $self->{file_types} = $args{file_types};
    $self->{db} = $args{db};

    return $self;
}

sub execute {
    my ($self) = @_;

    my @types = split /,/, $self->{file_types};
    my @dirs = @{ $self->{input_dirs_ref} };
    my $db = $self->{db};

    my $insert_file = q(INSERT INTO files (id, path, ext, dir_id) 
                        VALUES (?, ?, ?, ?););
    my $insert_dir = q(INSERT INTO dirs (id, path) VALUES (?, ?););
    my $sth_file = $db->prepare($insert_file);
    my $sth_dir = $db->prepare($insert_dir);

    my $file_id = 0;
    for (my $i = 0; $i < scalar(@dirs); $i++) {

        # insert dir data into database
        $sth_dir->execute($i, $dirs[$i]) or die $DBI::errstr;

        my @files = @{ _get_files_under($dirs[$i], \@types) };
        for my $f (@files) {
            # $f =~ /\.[^.]+$/; # split path and extension
            # my $base = $`;
            # my $ext = $&;
            my ($filename, $dirs, $suffix) = fileparse($f, qr/\.[^.]*$/);

            # insert file data into database
            $sth_file->execute($file_id, $dirs . $filename, $suffix, $i) 
                or die $DBI::errstr;

            $file_id++;
        }
    }

    $sth_file->finish();
    $sth_dir->finish();
    $db->commit();
}

sub _get_files_under {
    my ($root_dir, $types_ref) = @_;
    my @types = @{$types_ref};
    my $pattern = join('|', @types) . '$'; # file extension filter

    my @files;
    find(sub {
        return unless -f;
        return unless /$pattern/i;
        my $name = $File::Find::name;
        my $file_path = substr $name, length $root_dir; # substract root part
        push @files, $file_path;
    }, $root_dir);

    return \@files;
}

1;

__END__