use strict;
use warnings;
use feature 'say';

use File::Copy qw(copy);
use File::Path qw(make_path);
use Time::Piece;

my $home_dir     = $ENV{HOME} or die "HOME is not set\n";
my $dotfiles_dir = $ENV{DOTFILES} // "$home_dir/dotfiles";
my $config_dir   = "$dotfiles_dir/config";
my $backup_dir   = "$dotfiles_dir/back-up/" . localtime->strftime('%Y%m%d_%H%M%S');

my %os_map = (
    darwin => 'mac',
    linux  => 'linux',
);

my $os_key = lc($^O // '');
my $os     = $os_map{$os_key}
  or die "Unsupported OS '$os_key'. Supported: darwin, linux\n";

my @targets = qw(.zshrc .zprofile .bashrc .bash_profile .profile .gitconfig);

say "[INFO] OS           = $os ($os_key)";
say "[INFO] DOTFILES_DIR = $dotfiles_dir";
say "[INFO] CONFIG_DIR   = $config_dir";
say "[INFO] BACKUP_DIR   = $backup_dir";

make_path($backup_dir);

for my $f (@targets) {
    my $home_file = "$home_dir/$f";

    my @candidates = (
        "$config_dir/$os/$f",
        "$config_dir/$f",
    );

    my ($config_file) = grep { -e $_ } @candidates;

    if (!$config_file) {
        say "[SKIP] $f has no config file for OS '$os'";
        next;
    }

    say "------------------------------";
    say "[TARGET] $home_file";
    say "[SOURCE] $config_file";

    if (-l $home_file) {
        my $current = readlink($home_file) // '';
        if ($current eq $config_file) {
            say "[SKIP] $home_file already links to $config_file";
            next;
        }
        unlink $home_file
          or die "Failed to remove old symlink $home_file: $!\n";
        say "[INFO] Replaced old symlink: $home_file";
    } elsif (-e $home_file) {
        my $backup_file = "$backup_dir/$f";
        copy($home_file, $backup_file)
          or die "Failed to backup $home_file -> $backup_file: $!\n";
        unlink $home_file
          or die "Failed to remove $home_file: $!\n";
        say "[INFO] Backup   : $home_file -> $backup_file";
    } else {
        say "[INFO] $home_file does not exist";
    }

    symlink $config_file, $home_file
      or die "Failed to create symlink $home_file -> $config_file: $!\n";
    say "[LINK] $home_file -> $config_file";
}

say "------------------------------";
say "[DONE] dotfiles setup finished";
