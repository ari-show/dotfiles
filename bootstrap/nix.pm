use strict;
use warnings;
use feature 'say';

use File::Copy qw(move);
use File::Path qw(make_path);
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use Time::Piece;

my $home_dir = $ENV{HOME} or die "HOME is not set\n";

my $script_dir   = dirname(abs_path(__FILE__));
my $dotfiles_dir = abs_path($ENV{DOTFILES} // "$script_dir/..")
  or die "Failed to resolve dotfiles directory\n";

# ~/.config/nix は実ディレクトリとして残し、nix.conf だけを管理対象にする。
my $src_file   = abs_path("$dotfiles_dir/.config/nix/nix.conf");
my $dest_dir   = "$home_dir/.config/nix";
my $dest_file  = "$dest_dir/nix.conf";
my $backup_dir = "$dotfiles_dir/back-up/" . localtime->strftime('%Y%m%d_%H%M%S');

if (!$src_file || !-e $src_file) {
    die "[ERROR] Source file does not exist: $dotfiles_dir/.config/nix/nix.conf\n";
}

say "[INFO] DOTFILES_DIR = $dotfiles_dir";
say "[INFO] SOURCE       = $src_file";
say "[INFO] TARGET       = $dest_file";

make_path($dest_dir);

say "------------------------------";

if (-l $dest_file) {
    my $current = readlink($dest_file) // '';
    if ($current eq $src_file) {
        say "[SKIP] $dest_file already links to $src_file";
        say "------------------------------";
        say "[DONE] nix setup finished";
        exit 0;
    }
    unlink $dest_file
      or die "Failed to remove old symlink $dest_file: $!\n";
    say "[INFO] Replaced old symlink: $dest_file";
} elsif (-e $dest_file) {
    make_path($backup_dir);
    my $backup_path = "$backup_dir/nix.conf";
    move($dest_file, $backup_path)
      or die "Failed to backup $dest_file -> $backup_path: $!\n";
    say "[INFO] Backup   : $dest_file -> $backup_path";
} else {
    say "[INFO] $dest_file does not exist";
}

symlink $src_file, $dest_file
  or die "Failed to create symlink $dest_file -> $src_file: $!\n";
say "[LINK] $dest_file -> $src_file";

say "------------------------------";
say "[DONE] nix setup finished";
