use strict;
use warnings;
use feature 'say';
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Copy qw(move);
use File::Path qw(make_path);
use Time::Piece;

if ($^O ne 'darwin' || `uname -m` !~ /^arm64\s*$/) {
    say '[SKIP] cmux is configured only on Apple Silicon macOS';
    exit 0;
}
my $home_dir = $ENV{HOME} or die "HOME is not set\n";
my $script_dir = dirname(abs_path(__FILE__));
my $dotfiles_dir = abs_path($ENV{DOTFILES} // "$script_dir/..")
  or die "Failed to resolve dotfiles directory\n";
my $backup_dir = "$dotfiles_dir/back-up/" . localtime->strftime('%Y%m%d_%H%M%S') . '/cmux';

sub link_file {
    my ($source, $target, $backup_name) = @_;
    make_path(dirname($target));
    if (-l $target && (readlink($target) // '') eq $source) {
        say "[SKIP] $target already links to $source";
        return;
    }
    if (-e $target || -l $target) {
        make_path($backup_dir);
        my $backup = "$backup_dir/$backup_name";
        die "Backup already exists: $backup\n" if -e $backup || -l $backup;
        move($target, $backup) or die "Failed to backup $target: $!\n";
        say "[BACKUP] $target -> $backup";
    }
    symlink($source, $target) or die "Failed to link $target: $!\n";
    say "[LINK] $target -> $source";
}

my $config = abs_path("$dotfiles_dir/.config/cmux/cmux.json")
  or die "cmux config not found\n";
link_file($config, "$home_dir/.config/cmux/cmux.json", 'cmux.json');
my $app = "$home_dir/.nix-profile/Applications/cmux.app";
if (-d $app) {
    link_file($app, "$home_dir/Applications/cmux.app", 'cmux.app');
} else {
    say '[INFO] Install dotfiles-tools with Nix, then run make cmux again to link the app.';
}
